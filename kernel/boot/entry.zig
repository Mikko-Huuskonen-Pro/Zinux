//! Varhainen boot-alustus — ennen muistinhallintaa ja scheduleria.
//!
//! **Vastuu**: Aseta stack, lue Limine-tiedot, alusta perusajurit.
//! **Riippuvuudet**: `limine.zig`, `../lib/log.zig`
//! **Käytetään**: `kernel/main.zig` → `earlyInit()`

// Tuo Limine boot-tietojen luku wrapper.
const limine = @import("limine.zig");
// Tuo lokitusmoduuli varhaista debug-tulostusta varten.
const log = @import("../lib/log.zig");

// Varhaisen boot-vaiheen pino — 16 KiB riittää ennen heap-alustusta.
// `export` varmistaa että symboli on linkattavissa; `.bss` nollataan bootissa.
export var early_stack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

// Suorita kaikki varhaisen boot-vaiheen alustukset järjestyksessä.
pub fn earlyInit() void {
    // Aseta RSP-rekisteri early_stack-pinon huippuun (pino kasvaa alaspäin).
    const stack_top = @intFromPtr(&early_stack) + early_stack.len;
    // Inline asm: lataa uusi stack pointer ennen kuin kutsumme mitään funktiota.
    asm volatile ("mov %[stack], %%rsp"
        :
        : [stack] "r" (stack_top),
    );
    // Tarkista että Limine antoi meille boot-tiedot (HHDM, framebuffer, jne.).
    if (!limine.isBootValid()) {
        // Jos Limine-tiedot puuttuvat, pysäytä CPU — ei voi jatkaa boottia.
        // Vältetään @panic:ia joka vetää mukaan std debug -runtimea freestandingissä.
        asm volatile ("cli; hlt");
        // Ikuisesti jos hlt palaa (ei pitäisi tapahtua).
        while (true) {}
    }
    // Alusta lokitus (UART tai VGA — kumpi on saatavilla Limine-tiedoista).
    log.init(limine.getBootInfo());
    // Tulosta Limine-versio debug-tarkoituksiin.
    log.info("Limine boot OK");
}
