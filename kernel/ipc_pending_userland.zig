//! Userland IPC pending boot-testi — lataa ipc_pending_test-ELF, ring 3 pending-demo.
//!
//! **Vastuu**: Lataa ELF ja aja ipc.pending empty/send/recv ring 3:ssa.
//! **Riippuvuudet**: `loader/elf.zig`, `usermode.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu ipc_pending-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const ipc_pending_test_elf = @embedFile("loader/ipc_pending_test_prog.bin");

// Ipc pending -testin pinon heap-slot — erillään muista user-ELF:istä.
const IPC_PENDING_STACK_SLOT: u64 = 106;

// Boot-testi — lataa ipc_pending_test-ELF, hyppää ring 3:een.
pub fn runBootTest() void {
    // Lataa ipc_pending_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(ipc_pending_test_elf, IPC_PENDING_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland IPC pending ELF load failed");
        // Lopeta testi.
        return;
    };
    // Siirry ring 3:een ipcPendingMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland ipc pending OK".
    log.info("Userland IPC pending test OK");
}
