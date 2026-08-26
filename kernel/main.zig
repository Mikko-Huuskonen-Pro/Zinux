//! Zinux kernel — pääsisäänkäynti.
//!
//! **Vastuu**: Limine boottaa → `_start` → `kmain` → alijärjestelmät → idle loop.
//! **Riippuvuudet**: `boot/entry.zig`, `lib/log.zig`
//! **Käytetään**: linkkeri asettaa `_start` ENTRY-pisteeksi (linker.ld).

// Tuo boot-moduuli joka sisältää `_start`-symbolin ja varhaisen alustuksen.
const boot = @import("boot/entry.zig");
// Tuo lokitusmoduuli serial/VGA-tulostusta varten.
const log = @import("lib/log.zig");

// `_start` on kernelin julkinen entry point — Limine hyppää tähän.
// `export` tekee symbolin näkyväksi linkkerille; `linkage` = C-linkkaus.
pub export fn _start() callconv(.c) noreturn {
    // Kutsu varhaista boot-alustusta (stack, limine info, perusajurit).
    boot.earlyInit();
    // Siirry pääkernel-loopiin — ei palaa koskaan.
    kmain();
}

// Kernelin pääfunktio — alustaa alijärjestelmät ja jää ikuiseen idle-tilaan.
fn kmain() noreturn {
    // Tulosta boot-viesti — vahvistaa että sarjaportti/VGA toimii.
    log.info("Zinux kernel starting...");
    // Tulosta arkkitehtuuritiedot compile-time `@import("builtin")`:sta.
    log.info("Target: x86_64 freestanding");
    // TODO(#1): Alusta GDT, IDT, paging (Vaihe 2).
    // TODO(#2): Alusta PMM, VMM, heap (Vaihe 2).
    // TODO(#3): Alusta scheduler (Vaihe 3).
    // Boot onnistui — ilmoita testeille tunnistettava merkkijono.
    log.info("Zinux boot OK");
    // Jää ikuisesti CPU:n halt-tilaan — ei kuluta virtaa busy-loopissa.
    idleLoop();
}

// Idle-loop: pysäytä CPU kunnes keskeytys saapuu (timer, keyboard, jne.).
fn idleLoop() noreturn {
    // Ikuisesti toista: suorita halt-operaatio odottaen keskeytystä.
    while (true) {
        // `cli` poistaa keskeytykset; `hlt` pysäyttää CPU:n kunnes IRQ.
        asm volatile ("cli; hlt");
    }
}
