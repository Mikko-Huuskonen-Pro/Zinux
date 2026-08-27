//! Userland IPC try recv boot-testi — lataa ipc_try_recv_test-ELF, ring 3 tryRecv-demo.
//!
//! **Vastuu**: Lataa ELF ja aja ipc.tryRecv empty/send/recv/empty ring 3:ssa.
//! **Riippuvuudet**: `loader/elf.zig`, `usermode.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu ipc_try_recv-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const ipc_try_recv_test_elf = @embedFile("loader/ipc_try_recv_test_prog.bin");

// Ipc try recv -testin pinon heap-slot — erillään muista user-ELF:istä.
const IPC_TRY_RECV_STACK_SLOT: u64 = 105;

// Boot-testi — lataa ipc_try_recv_test-ELF, hyppää ring 3:een.
pub fn runBootTest() void {
    // Lataa ipc_try_recv_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(ipc_try_recv_test_elf, IPC_TRY_RECV_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland IPC try recv ELF load failed");
        // Lopeta testi.
        return;
    };
    // Siirry ring 3:een ipcTryRecvMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland ipc try recv OK".
    log.info("Userland IPC try recv test OK");
}
