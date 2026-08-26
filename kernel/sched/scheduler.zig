//! Round-robin scheduler — kaksi säiettä coop-yield + PIT tick.
//!
//! **Vastuu**: Säikeiden vuorottelu yield():llä, PIT IRQ taustalle.
//! **Riippuvuudet**: context, thread, pic, uart
//! **Käytetään**: `main.zig`, `idt.zig`

// Tuo kontekstinvaihto.
const context = @import("../arch/x86_64/context.zig");
// Tuo säierakenne.
const thread_mod = @import("thread.zig");
// Tuo UART merkkien tulostukseen testissä.
const uart = @import("../drivers/char/uart.zig");
// Tuo lokitus scheduler-alustusviestille.
const log = @import("../lib/log.zig");

// Säikeiden lukumäärä — Vaihe 3 testi: A ja B.
const THREAD_COUNT: usize = 2;
// Montako merkkiä kukin säie tulostaa ennen pysäytystä.
const PRINT_LIMIT: u32 = 8;

// Säie A:n tulostuslaskuri.
var count_a: u32 = 0;
// Säie B:n tulostuslaskuri.
var count_b: u32 = 0;
// Scheduler alustettu — estää yield ennen valmista.
var scheduler_ready: bool = false;
// Aktiivisen säikeen indeksi taulukossa.
var current: usize = 0;
// Säiettaulukko — kaksi kernel-säiettä.
var threads: [THREAD_COUNT]thread_mod.Thread = undefined;

// Säie A entry — exportattu vakaata funktios osoitetta varten.
export fn threadAEntry() callconv(.c) void {
    // Ota keskeytykset käyttöön — PIT tick taustalle.
    asm volatile ("sti");
    // Tulosta PRINT_LIMIT kertaa.
    while (count_a < PRINT_LIMIT) {
        // Merkki serialiin.
        uart.putc('A');
        // Kasvata laskuria.
        count_a += 1;
        // Luovuta vuoro toiselle säikeelle.
        yield();
    }
    // Valmis — odota loputtomiin.
    while (true) {
        asm volatile ("hlt");
    }
}

// Säie B entry — exportattu vakaata funktios osoitetta varten.
export fn threadBEntry() callconv(.c) void {
    // Ota keskeytykset käyttöön.
    asm volatile ("sti");
    // Tulosta PRINT_LIMIT kertaa.
    while (count_b < PRINT_LIMIT) {
        // Merkki serialiin.
        uart.putc('B');
        // Kasvata laskuria.
        count_b += 1;
        // Luovuta vuoro takaisin A:lle.
        yield();
    }
    // Valmis — odota loputtomiin.
    while (true) {
        asm volatile ("hlt");
    }
}

// Round-robin: vaihda seuraavaan säieeseen (cooperative).
fn yield() void {
    // Älä aikatauluta ennen alustusta.
    if (!scheduler_ready) return;
    // Muista tämänhetkinen säie.
    const prev = current;
    // Laske seuraava indeksi.
    const next = (current + 1) % THREAD_COUNT;
    // Päivitä current ennen switchiä.
    current = next;
    // Vaihda konteksti seuraavaan säieeseen.
    context.switchContext(&threads[prev].ctx.rsp, threads[next].ctx.rsp);
    // Paluu = prev jatkaa — palauta current.
    current = prev;
}

// Alusta kaksi säiettä ja hyppää ensimmäiseen.
pub fn start() noreturn {
    // Alusta säie 0 → threadAEntry omalla pinolla.
    thread_mod.init(&threads[0], 0, threadAEntry);
    // Alusta säie 1 → threadBEntry omalla pinolla.
    thread_mod.init(&threads[1], 1, threadBEntry);
    // Merkitse scheduler valmiiksi yield-kutsuja varten.
    scheduler_ready = true;
    // Tulosta aloitusviesti.
    log.info("Scheduler started");
    // Aktivoi ensimmäinen säie.
    current = 0;
    // Bootstrap-pinon RSP tallennusta varten.
    var bootstrap_rsp: u64 = undefined;
    // Hyppää säie A:n pinolle — coop-yield vuorottelee A/B.
    context.switchContext(&bootstrap_rsp, threads[0].ctx.rsp);
    // Ei saavuteta — varmistus fallback.
    while (true) {
        asm volatile ("hlt");
    }
}

// Palauta PIT-tickien määrä idt-moduulista.
pub fn ticks() u64 {
    return @import("../arch/x86_64/idt.zig").timerTicks();
}
