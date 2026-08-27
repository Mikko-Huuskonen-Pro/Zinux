//! IPC-portit — capability-integroitu send/recv ja boot-testi.
//!
//! **Vastuu**: Porttien alustus, cap-tarkistettu send/recv, boot-smoke test.
//! **Riippuvuudet**: `port_core.zig`, `capability_core.zig`, log
//! **Käytetään**: `kernel/main.zig`, tulevat sys_ipc_* syscallit

// Tuo porttien ydinlogiikka.
const core = @import("port_core.zig");
// Tuo capability-tarkistukset send/recv-oikeuksille.
const cap = @import("capability_core.zig");
// Tuo estävän recv-ydin — odotus ennen uudelleenyritystä.
const ipc_block_core = @import("../syscall/ipc_block_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Uudelleenexportoi porttivirheet.
pub const PortError = core.PortError;
// Uudelleenexportoi viestin max-koko.
pub const MAX_MSG_SIZE = core.MAX_MSG_SIZE;

// Alusta porttijärjestelmä boot-vaiheessa.
pub fn init() void {
    // Nollaa porttitaulukko.
    core.initCore();
}

// Luo uusi IPC-portti — palauttaa port_id.
pub fn createPort() ?u32 {
    // Delegoi ydinlogiikalle.
    return core.createPort();
}

// Lähetä viesti suoraan port_id:llä (kernel sisäinen).
pub fn send(port_id: u32, payload: []const u8) PortError!usize {
    // Delegoi ydinlogiikalle.
    return core.send(port_id, payload);
}

// Vastaanota viesti suoraan port_id:llä (kernel sisäinen).
pub fn recv(port_id: u32, buf: []u8) PortError!usize {
    // Delegoi ydinlogiikalle.
    return core.recv(port_id, buf);
}

// Lähetä capability-slotin kautta — vaatii send-oikeuden.
pub fn sendViaSlot(slot_idx: u32, payload: []const u8) PortError!usize {
    // Hae slotti capability-taulukosta.
    const slot = cap.lookupSlot(slot_idx) orelse return error.NotFound;
    // Tarkista send-oikeus.
    if (!cap.slotHasRights(slot_idx, .{ .send = true })) return error.NotFound;
    // Hae objekti.
    const obj = cap.getObject(slot.object_id) orelse return error.NotFound;
    // Varmista että objekti on portti-tyyppiä.
    if (obj.typ != .port) return error.NotFound;
    // object_id kenttä = port_id resurssissa.
    const port_id: u32 = @intCast(obj.object_id);
    // Lähetä porttiin.
    return core.send(port_id, payload);
}

// Vastaanota capability-slotin kautta — vaatii recv-oikeuden.
pub fn recvViaSlot(slot_idx: u32, buf: []u8) PortError!usize {
    // Hae slotti capability-taulukosta.
    const slot = cap.lookupSlot(slot_idx) orelse return error.NotFound;
    // Tarkista recv-oikeus.
    if (!cap.slotHasRights(slot_idx, .{ .recv = true })) return error.NotFound;
    // Hae capability-objekti.
    const obj = cap.getObject(slot.object_id) orelse return error.NotFound;
    // Varmista portti-tyyppi.
    if (obj.typ != .port) return error.NotFound;
    // Resurssitunniste = port_id.
    const port_id: u32 = @intCast(obj.object_id);
    // Vastaanota portista.
    return core.recv(port_id, buf);
}

// Palauta capability-slotin portin jonossa olevien viestien määrä — vaatii recv-oikeuden.
pub fn pendingViaSlot(slot_idx: u32) PortError!u8 {
    // Hae slotti capability-taulukosta.
    const slot = cap.lookupSlot(slot_idx) orelse return error.NotFound;
    // Tarkista recv-oikeus (vastaanottajan näkymä jonoon).
    if (!cap.slotHasRights(slot_idx, .{ .recv = true })) return error.NotFound;
    // Hae capability-objekti.
    const obj = cap.getObject(slot.object_id) orelse return error.NotFound;
    // Varmista portti-tyyppi.
    if (obj.typ != .port) return error.NotFound;
    // Resurssitunniste = port_id.
    const port_id: u32 = @intCast(obj.object_id);
    // Hae jonon pituus port_core:stä.
    const count = core.pendingCount(port_id) orelse return error.NotFound;
    // Palauta odottavien viestien määrä.
    return count;
}

// Vastaanota capability-slotin kautta — blokkaa kunnes viesti saapuu.
pub fn recvViaSlotBlocking(slot_idx: u32, buf: []u8) PortError!usize {
    // Yritä recv kunnes onnistuu tai muu virhe.
    while (true) {
        // Yritä non-blocking recv.
        const len = recvViaSlot(slot_idx, buf) catch |err| {
            // Muu virhe kuin tyhjä jono — palauta heti.
            if (err != error.Empty) return err;
            // Tyhjä jono — odota timer IRQ / lähettäjää.
            ipc_block_core.waitForMessage();
            // Yritä uudelleen.
            continue;
        };
        // Onnistui — palauta pituus.
        return len;
    }
}

// Boot-testi — luo portti + cap, send/recv "IPC" viesti.
pub fn runBootTest() void {
    // Alusta portit (capability alustetaan capability.runBootTest:ssä ennen tätä).
    init();
    // Luo fyysinen IPC-portti.
    const port_id = createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("IPC port create failed");
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
    // Luo capability portille — resource_id = port_id.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("IPC port cap install failed");
        // Lopeta testi.
        return;
    };
    // Lähetettävä testiviesti.
    const msg = "IPC";
    // Lähetä slotin kautta (capability-tarkistus).
    const sent = sendViaSlot(slot, msg) catch {
        // Send epäonnistui.
        log.err("IPC port send failed");
        // Lopeta testi.
        return;
    };
    // Varmista että 3 tavua lähetettiin.
    if (sent != msg.len) {
        // Väärä lähetetty määrä.
        log.err("IPC port send length mismatch");
        // Lopeta testi.
        return;
    }
    // Vastaanottopuskuri.
    var buf: [core.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota slotin kautta.
    const got = recvViaSlot(slot, &buf) catch {
        // Recv epäonnistui.
        log.err("IPC port recv failed");
        // Lopeta testi.
        return;
    };
    // Varmista pituus.
    if (got != msg.len) {
        // Väärä vastaanotettu pituus.
        log.err("IPC port recv length mismatch");
        // Lopeta testi.
        return;
    }
    // Vertaa tavut yksi kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            log.err("IPC port payload mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Kaikki OK.
    log.info("IPC port test OK");
}
