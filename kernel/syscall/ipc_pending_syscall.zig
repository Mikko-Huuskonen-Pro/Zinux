//! IPC pending boot-testi — sys_ipc_pending invoke()-kautta.
//!
//! **Vastuu**: Tyhjä jono → 0, send → 1, recv → 0.
//! **Riippuvuudet**: `dispatch.zig`, `port.zig`, `capability_core.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo IPC-portit — createPort ja MAX_MSG_SIZE.
const port = @import("../ipc/port.zig");
// Tuo capability — createAndInstall slotille.
const cap = @import("../ipc/capability_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — sys_ipc_pending empty → send → pending=1 → recv → pending=0.
pub fn runBootTest() void {
    // Luo uusi IPC-portti syscall-testiin.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("IPC pending port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet send + recv boot-prosessille (pid 1 stub).
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus.
        .send = true,
        // recv-oikeus.
        .recv = true,
    };
    // Asenna capability portille — resource_id = port_id.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("IPC pending cap install failed");
        // Lopeta testi.
        return;
    };
    // Kysy jonon pituus tyhjällä portilla — pitää olla 0.
    const empty = dispatch.invoke(abi.SYS_ipc_pending, slot, 0, 0, 0, 0, 0);
    // Varmista tyhjä jono.
    if (empty != 0) {
        // Odotettiin nollaa odottavia viestejä.
        log.err("IPC pending empty should be 0");
        // Lopeta testi.
        return;
    }
    // Lähetettävä testiviesti.
    const msg = "PND";
    // Lähetä viesti porttiin.
    const sent = dispatch.invoke(abi.SYS_ipc_send, slot, @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista lähetys onnistui.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui.
        log.err("IPC pending send failed");
        // Lopeta testi.
        return;
    }
    // Kysy jonon pituus viestin jälkeen — pitää olla 1.
    const pending = dispatch.invoke(abi.SYS_ipc_pending, slot, 0, 0, 0, 0, 0);
    // Varmista yksi odottava viesti.
    if (pending != 1) {
        // Odotettiin yhtä odottavaa viestiä.
        log.err("IPC pending after send should be 1");
        // Lopeta testi.
        return;
    }
    // Vastaanottopuskuri kernel-pinossa.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota viesti try_recv:llä (non-blocking).
    const got = dispatch.invoke(abi.SYS_ipc_try_recv, slot, @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista vastaanotettu pituus.
    if (got != @as(i64, @intCast(msg.len))) {
        // Recv epäonnistui.
        log.err("IPC pending recv failed");
        // Lopeta testi.
        return;
    }
    // Kysy jonon pituus recv:n jälkeen — pitää olla 0.
    const after = dispatch.invoke(abi.SYS_ipc_pending, slot, 0, 0, 0, 0, 0);
    // Varmista tyhjä jono uudelleen.
    if (after != 0) {
        // Odotettiin nollaa recv:n jälkeen.
        log.err("IPC pending after recv should be 0");
        // Lopeta testi.
        return;
    }
    // Kaikki OK.
    log.info("IPC pending syscall OK");
}
