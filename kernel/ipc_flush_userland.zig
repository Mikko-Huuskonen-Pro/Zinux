//! Userland IPC flush boot-testi — lataa ipc_flush_test-ELF, ring 3 flush-demo.
//!
//! **Vastuu**: Lataa ELF ja aja ipc.flush send/flush/pending ring 3:ssa.
//! **Riippuvuudet**: `loader/elf.zig`, `usermode.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu ipc_flush-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const ipc_flush_test_elf = @embedFile("loader/ipc_flush_test_prog.bin");

// Ipc flush -testin pinon heap-slot — erillään muista user-ELF:istä.
const IPC_FLUSH_STACK_SLOT: u64 = 109;

// Boot-testi — lataa ipc_flush_test-ELF, hyppää ring 3:een.
pub fn runBootTest() void {
    // Lataa ipc_flush_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(ipc_flush_test_elf, IPC_FLUSH_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland IPC flush ELF load failed");
        // Lopeta testi.
        return;
    };
    // Siirry ring 3:een ipcFlushMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland ipc flush OK".
    log.info("Userland IPC flush test OK");
}
