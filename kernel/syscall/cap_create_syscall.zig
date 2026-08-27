//! Capability create boot-testi — sys_cap_create invoke()-kautta.
//!
//! **Vastuu**: Luo portti+cap send/recv, varmista IPC roundtrip.
//! **Riippuvuudet**: `dispatch.zig`, `port.zig`, `cap_syscall_core.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo IPC-portit — MAX_MSG_SIZE vastaanottopuskurille.
const port = @import("../ipc/port.zig");
// Tuo capability-syscall-ydin — tyypit ja maskit.
const cap_core = @import("cap_syscall_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — sys_cap_create + sys_ipc_send/recv roundtrip.
pub fn runBootTest() void {
    // Oikeudet send + recv uudelle portille.
    const rights_mask = cap_core.MASK_SEND | cap_core.MASK_RECV;
    // Luo portti-capability invoke()-kautta.
    const slot = dispatch.invoke(abi.SYS_cap_create, cap_core.CAP_TYPE_PORT, rights_mask, 0, 0, 0, 0);
    // Varmista että slot-indeksi palautui.
    if (slot < 0) {
        // Luonti epäonnistui.
        log.err("Cap create syscall failed");
        // Lopeta testi.
        return;
    }
    // Lähetettävä testiviesti.
    const msg = "PRT";
    // Lähetä uuden slotin kautta.
    const sent = dispatch.invoke(abi.SYS_ipc_send, @intCast(slot), @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista lähetys onnistui.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui.
        log.err("Cap create send failed");
        // Lopeta testi.
        return;
    }
    // Vastaanottopuskuri kernel-pinossa.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota samasta slotista.
    const got = dispatch.invoke(abi.SYS_ipc_recv, @intCast(slot), @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista vastaanotettu pituus.
    if (got != @as(i64, @intCast(msg.len))) {
        // Recv epäonnistui.
        log.err("Cap create recv failed");
        // Lopeta testi.
        return;
    }
    // Vertaa tavut yksi kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            log.err("Cap create payload mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Kaikki OK.
    log.info("Cap create syscall OK");
}
