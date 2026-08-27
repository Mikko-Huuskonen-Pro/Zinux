//! IPC queue capacity boot-testi — sys_ipc_queue_capacity invoke()-kautta.
//!
//! **Vastuu**: Varmista jonon maksimisyvyys = MAX_QUEUE, pending ≤ capacity.
//! **Riippuvuudet**: `dispatch.zig`, `port.zig`, `capability_core.zig`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo IPC-portit — createPort ja MAX_QUEUE.
const port = @import("../ipc/port.zig");
// Tuo capability — createAndInstall slotille.
const cap = @import("../ipc/capability_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — capacity = MAX_QUEUE, pending ≤ capacity.
pub fn runBootTest() void {
    // Luo uusi IPC-portti syscall-testiin.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("IPC queue capacity port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet send + recv boot-prosessille (pid 1 stub).
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus.
        .send = true,
        // recv-oikeus (capacity-kysely vaatii recv:n kuten pending).
        .recv = true,
    };
    // Asenna capability portille — resource_id = port_id.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("IPC queue capacity cap install failed");
        // Lopeta testi.
        return;
    };
    // Kysy jonon maksimisyvyys — pitää olla MAX_QUEUE.
    const capacity = dispatch.invoke(abi.SYS_ipc_queue_capacity, slot, 0, 0, 0, 0, 0);
    // Varmista maksimijonon syvyys.
    if (capacity != @as(i64, @intCast(port.MAX_QUEUE))) {
        // Kapasiteetti ei täsmää MAX_QUEUE.
        log.err("IPC queue capacity wrong max");
        // Lopeta testi.
        return;
    }
    // Kysy pending tyhjällä jonolla — pitää olla 0.
    const pending_empty = dispatch.invoke(abi.SYS_ipc_pending, slot, 0, 0, 0, 0, 0);
    // Varmista tyhjä jono.
    if (pending_empty != 0) {
        // Odotettiin nollaa odottavia viestejä.
        log.err("IPC queue capacity pending empty should be 0");
        // Lopeta testi.
        return;
    }
    // Lähetä yksi viesti — pending kasvaa mutta pysyy ≤ capacity.
    const msg = "CAP";
    // Lähetä viesti porttiin.
    const sent = dispatch.invoke(abi.SYS_ipc_send, slot, @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista lähetys onnistui.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui.
        log.err("IPC queue capacity send failed");
        // Lopeta testi.
        return;
    }
    // Kysy pending viestin jälkeen — pitää olla 1.
    const pending_one = dispatch.invoke(abi.SYS_ipc_pending, slot, 0, 0, 0, 0, 0);
    // Varmista yksi odottava viesti.
    if (pending_one != 1) {
        // Odotettiin yhtä odottavaa viestiä.
        log.err("IPC queue capacity pending after send should be 1");
        // Lopeta testi.
        return;
    }
    // Kapasiteetti ei muutu lähetyksen jälkeen.
    const capacity2 = dispatch.invoke(abi.SYS_ipc_queue_capacity, slot, 0, 0, 0, 0, 0);
    // Varmista maksimisyvyys edelleen MAX_QUEUE.
    if (capacity2 != @as(i64, @intCast(port.MAX_QUEUE))) {
        // Kapasiteetti muuttui — ei pitäisi tapahtua.
        log.err("IPC queue capacity changed after send");
        // Lopeta testi.
        return;
    }
    // Kaikki OK.
    log.info("IPC queue capacity syscall OK");
}
