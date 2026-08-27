//! IPC flush boot-testi — sys_ipc_flush invoke()-kautta.
//!
//! **Vastuu**: send ×2 → pending=2 → flush=2 → pending=0 → try_recv EAGAIN.
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

// Boot-testi — sys_ipc_flush tyhjentää jonon ilman recv:ää.
pub fn runBootTest() void {
    // Luo uusi IPC-portti flush-syscall-testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("IPC flush port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet send + recv boot-prosessille (pid 1 stub).
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus viestin jonoon.
        .send = true,
        // recv-oikeus flush-kutsuun.
        .recv = true,
    };
    // Asenna capability portille — resource_id = port_id.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("IPC flush cap install failed");
        // Lopeta testi.
        return;
    };
    // Lähetettävä testiviesti.
    const msg = "FLU";
    // Lähetä kaksi viestiä porttiin.
    var n: usize = 0;
    while (n < 2) : (n += 1) {
        // Lähetä viesti invoke()-kautta.
        const sent = dispatch.invoke(abi.SYS_ipc_send, slot, @intFromPtr(msg), msg.len, 0, 0, 0);
        // Varmista lähetys onnistui.
        if (sent != @as(i64, @intCast(msg.len))) {
            // Send epäonnistui.
            log.err("IPC flush send failed");
            // Lopeta testi.
            return;
        }
    }
    // Kysy jonon pituus ennen flushia — pitää olla 2.
    const pending = dispatch.invoke(abi.SYS_ipc_pending, slot, 0, 0, 0, 0, 0);
    // Varmista kaksi odottavaa viestiä.
    if (pending != 2) {
        // Odotettiin kahta odottavaa viestiä.
        log.err("IPC flush pending should be 2");
        // Lopeta testi.
        return;
    }
    // Tyhjennä jono flush-syscallilla — pitää palauttaa 2.
    const flushed = dispatch.invoke(abi.SYS_ipc_flush, slot, 0, 0, 0, 0, 0);
    // Varmista poistettujen viestien määrä.
    if (flushed != 2) {
        // Flush ei poistanut kahta viestiä.
        log.err("IPC flush count should be 2");
        // Lopeta testi.
        return;
    }
    // Kysy jonon pituus flushin jälkeen — pitää olla 0.
    const after = dispatch.invoke(abi.SYS_ipc_pending, slot, 0, 0, 0, 0, 0);
    // Varmista tyhjä jono.
    if (after != 0) {
        // Odotettiin nollaa flushin jälkeen.
        log.err("IPC flush pending should be 0");
        // Lopeta testi.
        return;
    }
    // Vastaanottopuskuri kernel-pinossa.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Yritä vastaanottaa tyhjältä portilta — pitää palauttaa EAGAIN.
    const empty_recv = dispatch.invoke(abi.SYS_ipc_try_recv, slot, @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista non-blocking recv epäonnistui tyhjällä jonolla.
    if (empty_recv != abi.EAGAIN) {
        // Odotettiin EAGAIN flushin jälkeen.
        log.err("IPC flush try recv should EAGAIN");
        // Lopeta testi.
        return;
    }
    // Kaikki OK.
    log.info("IPC flush syscall OK");
}
