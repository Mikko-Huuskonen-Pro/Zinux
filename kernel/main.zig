//! Zinux kernel — pääsisäänkäynti.
//!
//! **Vastuu**: Limine boottaa → `_start` → `kmain` → alijärjestelmät → idle loop.
//! **Riippuvuudet**: `boot/entry.zig`, `lib/log.zig`
//! **Käytetään**: linkkeri asettaa `_start` ENTRY-pisteeksi (linker.ld).

// Tuo boot-moduuli joka sisältää varhaisen alustuksen.
const boot = @import("boot/entry.zig");
// Pakota Limine request -symbolit linkkaukseen (export .limine_requests).
const requests = @import("boot/requests.zig");
// Tuo lokitusmoduuli serial/VGA-tulostusta varten.
const log = @import("lib/log.zig");
// Tuo GDT-alustus (Vaihe 2).
const gdt = @import("arch/x86_64/gdt.zig");
// Tuo IDT-alustus (Vaihe 2).
const idt = @import("arch/x86_64/idt.zig");

// `_start` on kernelin julkinen entry point — Limine hyppää tähän.
// `export` tekee symbolin näkyväksi linkkerille; `linkage` = C-linkkaus.
pub export fn _start() callconv(.c) noreturn {
    // Säilytä Limine request -symbolit linkkerissä ennen dead code eliminationia.
    requests.anchor();
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
    // Alusta GDT — segmenttirekisterit kernel-tilaan.
    gdt.init();
    log.info("GDT initialized");
    // Alusta IDT — keskeytyskäsittelijät (stub Vaihe 2).
    idt.init();
    log.info("IDT initialized");
    // TODO(#2): Alusta paging, PMM, VMM, heap (Vaihe 2 jatkuu).
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
