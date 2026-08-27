//! IPC-syscall boot-testi — sys_ipc_send / sys_ipc_recv invoke()-kautta.
//!
//! **Vastuu**: Luo portti+cap, kutsu dispatch invoke(), varmista roundtrip.
//! **Riippuvuudet**: `dispatch.zig`, `port.zig`, `capability_core.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo IPC-portit — createPort sendViaSlot recvViaSlot.
const port = @import("../ipc/port.zig");
// Tuo capability — createAndInstall slotille.
const cap = @import("../ipc/capability_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — sys_ipc_send + sys_ipc_recv capability-slotin kautta.
pub fn runBootTest() void {
    // capability.runBootTest + port.runBootTest ovat jo alustaneet järjestelmän.
    // Luo uusi IPC-portti syscall-testiin.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("IPC syscall port create failed");
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
        log.err("IPC syscall cap install failed");
        // Lopeta testi.
        return;
    };
    // Lähetettävä testiviesti (kernel literaali — boot ei vaadi ring 3).
    const msg = "IPC";
    // Kutsu sys_ipc_send(slot, buf, len).
    const sent = dispatch.invoke(abi.SYS_ipc_send, slot, @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista että 3 tavua lähetettiin.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui tai väärä pituus.
        log.err("IPC syscall send failed");
        // Lopeta testi.
        return;
    }
    // Vastaanottopuskuri kernel-pinossa.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Kutsu sys_ipc_recv(slot, buf, len).
    const got = dispatch.invoke(abi.SYS_ipc_recv, slot, @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista vastaanotettu pituus.
    if (got != @as(i64, @intCast(msg.len))) {
        // Recv epäonnistui tai väärä pituus.
        log.err("IPC syscall recv failed");
        // Lopeta testi.
        return;
    }
    // Vertaa tavut yksi kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            log.err("IPC syscall payload mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Kaikki OK.
    log.info("IPC syscall OK");
}
