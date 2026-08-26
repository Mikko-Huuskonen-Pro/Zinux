//! Shell-prosessin käynnistys — ELF-loader + UART-syötteen injektio.
//!
//! **Vastuu**: Injektoi "help\n", lataa shell-ELF, hyppää ring 3:een.
//! **Riippuvuudet**: `loader/elf.zig`, `drivers/char/uart.zig`, `usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo UART — syöttörengas boot-testin "help\n" injektioon.
const uart = @import("drivers/char/uart.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu shell-ELF — build.zig kopioi userland/shell ennen kernel-käännöstä.
const shell_elf = @embedFile("loader/shell_prog.bin");

// Shell-pinon heap-slot — erillään bss-sivusta @ 0x41000 (käytä slot 66 → 0x42000).
const SHELL_STACK_SLOT: u64 = 66;

// Käynnistä shell-prosessi — injektoi komento, lataa ELF, siirry ring 3:een.
pub fn launch() void {
    // Boot-testi: simuloi käyttäjän "help\n" ennen shellin sys_read:ia.
    uart.injectInput("help\n");
    // Lataa shell-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(shell_elf, SHELL_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Shell ELF load failed");
        return;
    };
    // Siirry ring 3:een shellin entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return ret:llä — shell tulosti prompt + help serialiin.
    log.info("Shell test OK");
}
