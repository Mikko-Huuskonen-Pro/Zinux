//! Userland IPC queue capacity boot-testi — lataa ipc_queue_capacity_test-ELF, ring 3 demo.
//!
//! **Vastuu**: Lataa ELF ja aja ipc.queueCapacity ring 3:ssa.
//! **Riippuvuudet**: `loader/elf.zig`, `usermode.zig`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu ipc_queue_capacity-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const ipc_queue_capacity_test_elf = @embedFile("loader/ipc_queue_capacity_test_prog.bin");

// Ipc queue capacity -testin pinon heap-slot — erillään muista user-ELF:istä.
const IPC_QUEUE_CAPACITY_STACK_SLOT: u64 = 111;

// Boot-testi — lataa ipc_queue_capacity_test-ELF, hyppää ring 3:een.
pub fn runBootTest() void {
    // Lataa ipc_queue_capacity_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(ipc_queue_capacity_test_elf, IPC_QUEUE_CAPACITY_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland IPC queue capacity ELF load failed");
        // Lopeta testi.
        return;
    };
    // Siirry ring 3:een ipcQueueCapacityMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland ipc queue capacity OK".
    log.info("Userland IPC queue capacity test OK");
}
