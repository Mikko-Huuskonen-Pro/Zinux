//! Varhainen boot-alustus — ennen muistinhallintaa ja scheduleria.
//!
//! **Vastuu**: Aseta stack, lue Limine-tiedot, alusta perusajurit.
//! **Riippuvuudet**: `limine.zig`, `../lib/log.zig`
//! **Käytetään**: `kernel/main.zig` → `earlyInit()`

// Tuo Limine boot-tietojen luku wrapper.
const limine = @import("limine.zig");
// Tuo lokitusmoduuli varhaista debug-tulostusta varten.
const log = @import("../lib/log.zig");

// Varhaisen boot-vaiheen pino — exportattu jotta _start voi asettaa RSP:n ennen kutsuja.
export var early_stack: [16 * 1024]u8 align(16) linksection(".bss") = undefined;

// Suorita varhaisen boot-vaiheen alustukset (pino on jo asetettu _start:ssa).
pub fn earlyInit() void {
    // Alusta UART heti — jotta saamme virheilmoituksen vaikka Limine-tiedot puuttuisivat.
    log.initEarlyUart();
    // Tarkista että Limine antoi meille boot-tiedot (HHDM, framebuffer, jne.).
    if (!limine.isBootValid()) {
        // Tulosta virhe serialiin ennen pysäytystä — helpottaa CI-debuggausta.
        log.err("Limine boot info missing");
        // Pysäytä CPU — ei voi jatkaa boottia.
        asm volatile ("cli; hlt");
        while (true) {}
    }
    // Täydennä lokitus boot-tiedoilla (VGA jne.).
    log.init(limine.getBootInfo());
    // Tulosta Limine-versio debug-tarkoituksiin.
    log.info("Limine boot OK");
}
