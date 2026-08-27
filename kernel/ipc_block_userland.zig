//! Userland IPC block boot-testi — lataa ipc_block_test-ELF, ring 3 blocking recv.
//!
//! **Vastuu**: Luo portti+cap, timer-wake, aja blocking recv ring 3:ssa.
//! **Riippuvuudet**: `loader/elf.zig`, `ipc_block.zig`, `usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo IPC block — timer-arm ennen recv:ää.
const ipc_block = @import("ipc/ipc_block.zig");
// Tuo IPC-portit — createPort boot-portille.
const port = @import("ipc/port.zig");
// Tuo capability — createAndInstall slotille.
const cap = @import("ipc/capability_core.zig");
// Tuo estävän recv-ydin — viive boot-testissä.
const block_core = @import("syscall/ipc_block_core.zig");
// Tuo tick-laskuri — extern linkitys timer-simulaatioon.
extern var tick_count: u64;
// Tuo user_access — SMAP-yhteensopiva kirjoitus user-sivulle.
const user_access = @import("arch/x86_64/user_access.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu ipc_block-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const ipc_block_test_elf = @embedFile("loader/ipc_block_test_prog.bin");

// Timer-lähetettävä viesti boot-testeissä (sama kuin ipc_block.zig).
const BLOCK_MSG = "BLK";

// Ipc block -testin pinon heap-slot.
const IPC_BLOCK_STACK_SLOT: u64 = 103;
// Boot-info — kernel kirjoittaa capability-slotin ennen ring 3 -hyppyä.
const IPC_BLOCK_SLOT_VADDR: u64 = 0xFFFFFFFF90091000;

// Boot-testi — luo portti, timer-wake, hyppää ring 3 blocking recv:ään.
pub fn runBootTest() void {
    // Luo IPC-portti userland blocking-testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Userland IPC block port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet recv (send timer IRQ:sta).
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus timer-lähetykseen.
        .send = true,
        // recv-oikeus blocking-testiin.
        .recv = true,
    };
    // Asenna capability portille.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("Userland IPC block cap install failed");
        // Lopeta testi.
        return;
    };
    // Vastaanottopuskuri kernel-pinossa.
    var kbuf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Kernel blocking recv -testi samalla portilla (timer-wake polku).
    const arm_tick = tick_count;
    block_core.armTimerSendViaPort(port_id, arm_tick, block_core.BOOT_SEND_DELAY_TICKS);
    while (!block_core.isSent()) {
        // Simuloi timer tick + anna PIT IRQ:lle mahdollisuus.
        ipc_block.onTimerTick(arm_tick + block_core.BOOT_SEND_DELAY_TICKS);
        if (!block_core.isSent()) block_core.waitForMessage();
    }
    // Vastaanota timer-viesti capability-slotin kautta.
    _ = port.recvViaSlot(slot, &kbuf) catch {
        log.err("Userland IPC block kernel recv failed");
        ipc_block.disarmTimerSend();
        return;
    };
    ipc_block.disarmTimerSend();
    // Aseista uusi timer-lähetys ring 3 recv -testille.
    ipc_block.armTimerSendViaPort(port_id, 0);
    ipc_block.onTimerTick(tick_count);
    // Lataa ipc_block_test-ELF muistiiin.
    const loaded = elf.loadElfWithStack(ipc_block_test_elf, IPC_BLOCK_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland IPC block ELF load failed");
        // Poista timer-wake.
        ipc_block.disarmTimerSend();
        // Lopeta testi.
        return;
    };
    // Kirjoita capability-slotti userland boot-info -osoitteeseen.
    const slot_ptr: *u32 = @ptrFromInt(IPC_BLOCK_SLOT_VADDR);
    // SMAP: salli user-sivun kirjoitus kernelistä.
    user_access.stac();
    // Tallenna slotti ring 3 -testiä varten.
    slot_ptr.* = slot;
    // Palauta SMAP-suojaus.
    user_access.clac();
    // Siirry ring 3:een ipcBlockMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Poista timer-wake boot-testin jälkeen.
    ipc_block.disarmTimerSend();
    // Paluu sys_test_return:lla — userland tulosti "userland ipc block OK".
    log.info("Userland IPC block test OK");
}
