//! IPC try recv boot-testi — sys_ipc_try_recv invoke()-kautta.
//!
//! **Vastuu**: Tyhjä jono → EAGAIN, send → try_recv OK, tyhjä uudelleen → EAGAIN.
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
// Tuo IPC-syscall-ydin — EAGAIN virhekoodi.
const ipc_core = @import("ipc_syscall_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — sys_ipc_try_recv empty → send → recv → empty.
pub fn runBootTest() void {
    // Luo uusi IPC-portti syscall-testiin.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("IPC try recv port create failed");
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
        log.err("IPC try recv cap install failed");
        // Lopeta testi.
        return;
    };
    // Vastaanottopuskuri kernel-pinossa.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Yritä recv tyhjään jonoon — pitää palauttaa EAGAIN.
    const empty = dispatch.invoke(abi.SYS_ipc_try_recv, slot, @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista EAGAIN tyhjällä jonolla.
    if (empty != ipc_core.EAGAIN) {
        // Odotettiin WouldBlock-tyyppistä virhettä.
        log.err("IPC try recv empty should EAGAIN");
        // Lopeta testi.
        return;
    }
    // Lähetettävä testiviesti.
    const msg = "TRY";
    // Lähetä viesti porttiin ennen try_recv:ää.
    const sent = dispatch.invoke(abi.SYS_ipc_send, slot, @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista lähetys onnistui.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui.
        log.err("IPC try recv send failed");
        // Lopeta testi.
        return;
    }
    // Yritä recv viestillä täytetyllä jonolla — pitää onnistua.
    const got = dispatch.invoke(abi.SYS_ipc_try_recv, slot, @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista vastaanotettu pituus.
    if (got != @as(i64, @intCast(msg.len))) {
        // Recv epäonnistui tai väärä pituus.
        log.err("IPC try recv got failed");
        // Lopeta testi.
        return;
    }
    // Vertaa tavut yksi kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            log.err("IPC try recv payload mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Yritä recv uudelleen tyhjään jonoon — pitää palauttaa EAGAIN.
    const empty2 = dispatch.invoke(abi.SYS_ipc_try_recv, slot, @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista EAGAIN tyhjän jonon jälkeen.
    if (empty2 != ipc_core.EAGAIN) {
        // Odotettiin EAGAIN tyhjälle jonolle.
        log.err("IPC try recv empty2 should EAGAIN");
        // Lopeta testi.
        return;
    }
    // Kaikki OK.
    log.info("IPC try recv syscall OK");
}
