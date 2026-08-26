//! Init-prosessin käynnistys — ELF-loader + ring 3.
//!
//! **Vastuu**: Lataa upotettu init-ELF ja hyppää ensimmäiseen user-prosessiin.
//! **Riippuvuudet**: `loader/elf.zig`, `arch/x86_64/usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu init-ELF — build.zig kopioi userland/init ennen kernel-käännöstä.
const init_elf = @embedFile("loader/init_prog.bin");

// Init-pinon heap-slot — erillään loader-testin slot 33:sta.
const INIT_STACK_SLOT: u64 = 49;

// Käynnistä init-prosessi — lataa ELF ja siirry ring 3:een.
pub fn launch() void {
    // Lataa init-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(init_elf, INIT_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Init ELF load failed");
        return;
    };
    // Siirry ring 3:een initin entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return ret:llä — init tulosti "init\n" serialiin.
    log.info("Init process OK");
}
