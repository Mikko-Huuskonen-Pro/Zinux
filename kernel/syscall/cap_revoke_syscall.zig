//! Capability revoke boot-testi — sys_cap_revoke invoke()-kautta.
//!
//! **Vastuu**: Luo portti, peruuta slotti, varmista että IPC epäonnistuu.
//! **Riippuvuudet**: `dispatch.zig`, `cap_syscall_core.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo capability-syscall-ydin — oikeusmaskit.
const cap_core = @import("cap_syscall_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — sys_cap_create + send + sys_cap_revoke + send epäonnistuu.
pub fn runBootTest() void {
    // Oikeudet send + recv uudelle portille.
    const rights_mask = cap_core.MASK_SEND | cap_core.MASK_RECV;
    // Luo portti-capability invoke()-kautta.
    const slot = dispatch.invoke(abi.SYS_cap_create, cap_core.CAP_TYPE_PORT, rights_mask, 0, 0, 0, 0);
    // Varmista että slot-indeksi palautui.
    if (slot < 0) {
        // Luonti epäonnistui.
        log.err("Cap revoke create failed");
        // Lopeta testi.
        return;
    }
    // Lähetettävä testiviesti ennen peruutusta.
    const msg = "RVK";
    // Lähetä uuden slotin kautta — pitää onnistua.
    const sent = dispatch.invoke(abi.SYS_ipc_send, @intCast(slot), @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista lähetys onnistui.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui ennen peruutusta.
        log.err("Cap revoke pre-send failed");
        // Lopeta testi.
        return;
    }
    // Peruuta capability-slotti invoke()-kautta.
    const revoked = dispatch.invoke(abi.SYS_cap_revoke, @intCast(slot), 0, 0, 0, 0, 0);
    // Varmista peruutus onnistui (paluu 0).
    if (revoked != 0) {
        // Revoke epäonnistui.
        log.err("Cap revoke syscall failed");
        // Lopeta testi.
        return;
    }
    // Yritä lähettää peruutetun slotin kautta — pitää epäonnistua.
    const after = dispatch.invoke(abi.SYS_ipc_send, @intCast(slot), @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista että send palautti EBADF.
    if (after != abi.EBADF) {
        // Slot ei mitätöitynyt oikein.
        log.err("Cap revoke post-send should fail");
        // Lopeta testi.
        return;
    }
    // Kaikki OK.
    log.info("Cap revoke syscall OK");
}
