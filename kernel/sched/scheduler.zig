//! Round-robin scheduler — kaksi säiettä + PIT tick.
//!
//! **Vastuu**: Coop context switch ABAB-demo serialissa.
//! **Riippuvuudet**: context, thread, uart, log
//! **Käytetään**: `main.zig`

// Tuo kontekstinvaihto (RSP swap + callee-saved).
const context = @import("../arch/x86_64/context.zig");
// Tuo säierakenne.
const thread_mod = @import("thread.zig");
// Tuo UART merkkien tulostukseen testissä.
const uart = @import("../drivers/char/uart.zig");
// Tuo lokitus scheduler-alustusviestille.
const log = @import("../lib/log.zig");

// Montako A/B-tulostusta per säie (8 kpl → ABAB × 8 serialissa).
const PRINT_LIMIT: u32 = 8;

// Säie A:n tulostuslaskuri.
var count_a: u32 = 0;
// Säie B:n tulostuslaskuri.
var count_b: u32 = 0;
// Scheduler alustettu — yield sallittu.
var scheduler_ready: bool = false;
// Aktiivisen säikeen indeksi (0 tai 1).
var current: usize = 0;
// Boot/kmain-pinon RSP kun ensimmäinen säie ottaa CPU:n.
var boot_rsp: u64 = 0;
// Säiettaulukko — kaksi coop-säiettä.
var threads: [2]thread_mod.Thread = undefined;

// Coop yield — vaihda toiseen säieeseen tai palaa boot-pinolle kun valmis.
fn yield() void {
    // Ei yield ennen start()-alustusta.
    if (!scheduler_ready) return;
    // Edellinen säie jolta yield kutsuttiin.
    const prev = current;
    // Molemmat säikeet valmiit → log + palaa kmain-pinolle.
    if (count_a >= PRINT_LIMIT and count_b >= PRINT_LIMIT) {
        // Vahvista coop-scheduler ABAB-demo onnistui.
        log.info("Sched test OK (ABAB)");
        // Vaihda takaisin start():n boot-pinolle — ei palaa tähän yield():iin.
        context.switchContext(&threads[prev].ctx.rsp, boot_rsp);
        // switchContext ei palaa kun boot_ctx aktivoituu uudelleen.
        unreachable;
    }
    // Round-robin: seuraava säie 0↔1.
    current = (current + 1) % 2;
    // Tallenna prev RSP ja lataa seuraavan — coop context switch.
    context.switchContext(&threads[prev].ctx.rsp, threads[current].ctx.rsp);
}

// Säie A entry — tulostaa 'A' ja yieldaa.
export fn threadAEntry() callconv(.c) void {
    // Tulosta PRINT_LIMIT kertaa 'A' vuorotellen B:n kanssa.
    while (count_a < PRINT_LIMIT) {
        // Merkki serialiin.
        uart.putc('A');
        // Kasvata A-laskuria.
        count_a += 1;
        // Luovuta CPU toiselle säieelle.
        yield();
    }
    // Säie valmis — odota keskeytyksiin.
    while (true) asm volatile ("hlt");
}

// Säie B entry — tulostaa 'B' ja yieldaa.
export fn threadBEntry() callconv(.c) void {
    // Tulosta PRINT_LIMIT kertaa 'B'.
    while (count_b < PRINT_LIMIT) {
        // Merkki serialiin.
        uart.putc('B');
        // Kasvata B-laskuria.
        count_b += 1;
        // Luovuta CPU säie A:lle.
        yield();
    }
    // Säie valmis — odota keskeytyksiin.
    while (true) asm volatile ("hlt");
}

// Alusta scheduler ja hyppää ensimmäiseen säieeseen (coop switch).
pub fn start() noreturn {
    // Alusta säie-pinot entry-funktioilla.
    thread_mod.init(&threads[0], 0, threadAEntry);
    thread_mod.init(&threads[1], 1, threadBEntry);
    // Salli yield-kutsut säieistä.
    scheduler_ready = true;
    // Ilmoita schedulerin käynnistymisestä serialiin.
    log.info("Scheduler started");
    // Ensimmäinen ajettava säie on A (indeksi 0).
    current = 0;
    // Vaihda kmain-pinosta säie A:han — palaa kun molemmat säikeet valmiit.
    context.switchContext(&boot_rsp, threads[0].ctx.rsp);
    // Coop-demo valmis — odota PIT-keskeytyksiä idle-tilassa.
    while (true) {
        // STI + HLT — timer IRQ taustalla (tick-laskuri idt:ssä).
        asm volatile ("sti; hlt" ::: .{ .memory = true });
    }
}

// Palauta PIT-tickien määrä idt-moduulista.
pub fn ticks() u64 {
    // Delegoi idt.timerTicks():iin.
    return @import("../arch/x86_64/idt.zig").timerTicks();
}

// Export context switch testausta varten (host/kernel debug).
pub const ContextSwitch = context.switchContext;
