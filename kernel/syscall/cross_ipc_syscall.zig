//! Cross-process IPC boot-testi — cap transfer + send/recv eri pideillä (Vaihe 22).
//!
//! **Vastuu**: Varmista sys_cap_transfer ja IPC eri prosessikonteksteissa.
//! **Riippuvuudet**: `dispatch.zig`, `port.zig`, `capability_core.zig`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo IPC-portit — createPort ja MAX_MSG_SIZE.
const port = @import("../ipc/port.zig");
// Tuo capability — createAndInstall ja transfer.
const cap = @import("../ipc/capability_core.zig");
// Tuo prosessitaulukko — setCurrentPid cross-process kontekstille.
const process = @import("process_core");
// Tuo capability-syscall-ydin — oikeusmaskit.
const cap_core = @import("cap_syscall_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — cap transfer + cross-pid send/recv invoke()-kautta.
pub fn runBootTest() void {
    // Allokoi kaksi uutta prosessia — vältä aiempien boot-testien slotit (pid 2 jne.).
    const pid_a = process.allocNextPid() orelse {
        // Prosessi A ei mahdu taulukkoon.
        log.err("Cross IPC alloc pid A failed");
        // Lopeta testi.
        return;
    };
    const pid_b = process.allocNextPid() orelse {
        // Prosessi B ei mahdu taulukkoon.
        log.err("Cross IPC alloc pid B failed");
        // Lopeta testi.
        return;
    };
    // Luo fyysinen IPC-portti cross-process viestille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Cross IPC port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet send + recv + grant + read prosessille A (recv siirrettävissä).
    const rights_a = cap.Rights{
        // Lue portin metatiedot.
        .read = true,
        // Lähetys-oikeus prosessille A.
        .send = true,
        // Vastaanotto-oikeus siirrettäväksi prosessille B:hen.
        .recv = true,
        // Siirto-oikeus prosessille B:hen.
        .grant = true,
    };
    // Asenna capability prosessille A.
    const slot_a = cap.createAndInstall(.port, pid_a, port_id, rights_a) orelse {
        // Capability-asennus epäonnistui.
        log.err("Cross IPC cap install A failed");
        // Lopeta testi.
        return;
    };
    // Aseta current pid prosessi A ennen transfer-syscallia.
    if (!process.setCurrentPid(pid_a)) {
        // setCurrentPid epäonnistui.
        log.err("Cross IPC set pid A failed");
        // Lopeta testi.
        return;
    }
    // Siirrä recv-oikeus prosessille B sys_cap_transfer:llä.
    const recv_mask = cap_core.MASK_RECV | cap_core.MASK_READ;
    const slot_b = dispatch.invoke(abi.SYS_cap_transfer, @intCast(slot_a), pid_b, recv_mask, 0, 0, 0);
    // Varmista että slot-indeksi palautui prosessille B.
    if (slot_b < 0) {
        // Cap transfer epäonnistui.
        log.err("Cross IPC cap transfer failed");
        // Lopeta testi.
        return;
    }
    // Cap transfer OK (22.1).
    log.info("Cap transfer OK");
    // Lähetettävä testiviesti prosessista A.
    const msg = "XPC";
    // Prosessi A lähettää slotillaan.
    const sent = dispatch.invoke(abi.SYS_ipc_send, @intCast(slot_a), @intFromPtr(msg), msg.len, 0, 0, 0);
    // Varmista lähetys onnistui.
    if (sent != @as(i64, @intCast(msg.len))) {
        // Send epäonnistui prosessista A.
        log.err("Cross IPC send A failed");
        // Lopeta testi.
        return;
    }
    // Aseta current pid prosessi B ennen recv-syscallia.
    if (!process.setCurrentPid(pid_b)) {
        // setCurrentPid epäonnistui.
        log.err("Cross IPC set pid B failed");
        // Lopeta testi.
        return;
    }
    // Vastaanottopuskuri kernel-pinossa.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Prosessi B vastaanottaa siirretyllä slotilla.
    const got = dispatch.invoke(abi.SYS_ipc_recv, @intCast(slot_b), @intFromPtr(&buf), buf.len, 0, 0, 0);
    // Varmista vastaanotettu pituus.
    if (got != @as(i64, @intCast(msg.len))) {
        // Recv epäonnistui prosessissa B.
        log.err("Cross IPC recv B failed");
        // Lopeta testi.
        return;
    }
    // Vertaa tavut yksi kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe cross-process viestissä.
            log.err("Cross IPC payload mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Palauta boot-prosessin konteksti.
    _ = process.setCurrentPid(process.BOOT_PID);
    // Cross-process send OK (22.2).
    log.info("Cross-process send OK");
    // Yhteenveto kernel-syscall-testistä.
    log.info("Cross-process IPC syscall OK");
}
