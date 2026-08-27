//! Shell-prosessin käynnistys — ELF-loader + komentoboot-testit.
//!
//! **Vastuu**: Injektoi komennot, lataa shell-ELF, hyppää ring 3:een.
//! **Riippuvuudet**: `loader/elf.zig`, `drivers/char/uart.zig`, `usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo UART — stdin-rengas boot-testin komentoinjektioon.
const uart = @import("drivers/char/uart.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu shell-ELF — build.zig kopioi userland/shell ennen kernel-käännöstä.
const shell_elf = @embedFile("loader/shell_prog.bin");

// Shell-pinon heap-slot — erillään bss-sivusta @ 0x42000 (slot 67 → 0x43000).
const SHELL_STACK_SLOT: u64 = 67;

// Käynnistä shell yhdellä injektoidulla komennolla — palaa sys_test_return:lla.
fn runCommand(input: []const u8) void {
    // Tyhjennä mahdollinen aiempi syöte ja injektoi uusi rivi.
    uart.injectInput(input);
    // Lataa shell-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(shell_elf, SHELL_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Shell ELF load failed");
        return;
    };
    // Siirry ring 3:een shellin entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
}

// Boot-testi — aja help, meminfo ja ps komennot peräkkäin.
pub fn runBootTest() void {
    // help-komento — odotettu "Available commands" serialissa.
    runCommand("help\n");
    // Vahvista help-komento.
    log.info("Shell help OK");
    // meminfo-komento — odotettu "PMM total" serialissa.
    runCommand("meminfo\n");
    // Vahvista meminfo-komento.
    log.info("Shell meminfo OK");
    // ps-komento — odotettu "PID" serialissa.
    runCommand("ps\n");
    // Vahvista ps-komento.
    log.info("Shell ps OK");
    // Kaikki Vaihe 5.5 komennot testattu.
    log.info("Shell commands test OK");
}
