//! Capability-syscall boot-testi — sys_cap_delegate invoke()-kautta.
//!
//! **Vastuu**: Luo portti+grant-cap, delegoi recv-only, varmista send estyy.
//! **Riippuvuudet**: `dispatch.zig`, `port.zig`, `capability_core.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo IPC-portit — createPort sendViaSlot recvViaSlot.
const port = @import("../ipc/port.zig");
// Tuo capability — createAndInstall delegateSlot.
const cap = @import("../ipc/capability_core.zig");
// Tuo capability-syscall-ydin — rights_mask vakiot.
const cap_core = @import("cap_syscall_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — sys_cap_delegate + IPC send/recv oikeuksilla.
pub fn runBootTest() void {
    // Luo uusi IPC-portti delegointitestille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Cap syscall port create failed");
        // Lopeta testi.
        return;
    };
    // Täydet oikeudet mukaan grant delegointiin.
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus viestin jonoon.
        .send = true,
        // recv-oikeus viestin lukemiseen.
        .recv = true,
        // grant-oikeus delegointiin.
        .grant = true,
    };
    // Asenna capability portille.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("Cap syscall cap install failed");
        // Lopeta testi.
        return;
    };
    // Delegoi vain recv-oikeus uuteen slottiin.
    const derived = dispatch.invoke(abi.SYS_cap_delegate, slot, cap_core.MASK_RECV, 0, 0, 0, 0);
    // Varmista että uusi slot-indeksi palautui.
    if (derived < 0) {
        // Delegointi epäonnistui.
        log.err("Cap syscall delegate failed");
        // Lopeta testi.
        return;
    }
    // Lähetä viesti parent-slotilla ennen recv-only testiä.
    const msg = "CAP";
    // Käytä parent-slottia sendiin.
    const sent = dispatch.invoke(abi.SYS_ipc_send, slot, @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista lähetys onnistui.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui.
        log.err("Cap syscall parent send failed");
        // Lopeta testi.
        return;
    }
    // Yritä lähettää derived-slotilla — pitäisi epäonnistua (ei send-oikeutta).
    const bad_send = dispatch.invoke(abi.SYS_ipc_send, @intCast(derived), @intFromPtr(msg), msg.len, 0, 0, 0);
    // Odotetaan negatiivista virhekoodia.
    if (bad_send >= 0) {
        // Derived-slot vuoti send-oikeuden.
        log.err("Cap syscall derived send leaked");
        // Lopeta testi.
        return;
    }
    // Vastaanota derived-slotilla — recv-only pitäisi toimia.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Kutsu sys_ipc_recv derived-slotilla.
    const got = dispatch.invoke(abi.SYS_ipc_recv, @intCast(derived), @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista vastaanotettu pituus.
    if (got != @as(i64, @intCast(msg.len))) {
        // Recv epäonnistui derived-slotilla.
        log.err("Cap syscall derived recv failed");
        // Lopeta testi.
        return;
    }
    // Vertaa tavut yksi kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            log.err("Cap syscall payload mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Kaikki OK.
    log.info("Cap syscall OK");
}
