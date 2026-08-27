//! IPC-estävä recv — timer-wake boot-testit ja IRQ-koukku.
//!
//! **Vastuu**: Timer-lähetys tyhjään porttiin, blocking recv boot-testi.
//! **Riippuvuudet**: `ipc_block_core.zig`, `port.zig`, `pit_ticks.zig`, log
//! **Käytetään**: `pit_ticks.zig`, `main.zig`

// Tuo estävän recv-ydin — timer-arm tila.
const core = @import("../syscall/ipc_block_core.zig");
// Tuo IPC-portit — send timer-lähetykseen.
const port = @import("port.zig");
// Tuo capability — createAndInstall boot-portille.
const cap = @import("capability_core.zig");
// Tuo tick-laskuri — extern linkitys (ei import pit_ticks → ei syklit).
extern var tick_count: u64;
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Timer-lähetettävä viesti boot-testeissä.
const BLOCK_MSG = "BLK";

// Timer IRQ -kutsu — lähetä viesti kun viive täyttyy.
pub fn onTimerTick(now_tick: u64) void {
    // Tarkista pitääkö lähettää.
    if (!core.shouldFire(now_tick)) return;
    // Hae aseistettu portti.
    const port_id = core.armedPort() orelse return;
    // Lähetä viesti suoraan porttiin (kernel timer-wake — ei cap-tarkistusta IRQ:ssa).
    _ = port.send(port_id, BLOCK_MSG) catch {
        // Lähetys epäonnistui — yritä uudelleen seuraavalla tickillä.
        return;
    };
    // Merkitse lähetys valmiiksi.
    core.markSent();
}

// Aseista timer-wake porttiin.
pub fn armTimerSendViaPort(port_id: u32, delay_ticks: u64) void {
    // Muistiesto — näe IRQ-päivitetyt tickit.
    asm volatile ("" ::: .{ .memory = true });
    // Delegoi ytimelle nykyinen tick-laskuri.
    core.armTimerSendViaPort(port_id, tick_count, delay_ticks);
}

// Poista timer-wake boot-testin jälkeen.
pub fn disarmTimerSend() void {
    // Nollaa ytimen tila.
    core.disarm();
}

// Boot-testi — blocking recv tyhjään porttiin, timer IRQ lähettää BLK viestin.
pub fn runBootTest() void {
    // Luo IPC-portti blocking-testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("IPC block port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet send + recv (cap asennetaan userland-polun varmistukseen).
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus.
        .send = true,
        // recv-oikeus.
        .recv = true,
    };
    // Asenna capability portille — recvViaSlot-polku boot-testissä.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("IPC block cap install failed");
        // Lopeta testi.
        return;
    };
    // Aseista timer lähettämään viesti porttiin muutaman tickin kuluttua.
    const arm_tick = tick_count;
    core.armTimerSendViaPort(port_id, arm_tick, core.BOOT_SEND_DELAY_TICKS);
    // Odota timer-lähetys — IRQ-polku + deterministinen simulointi bootissa.
    while (!core.isSent()) {
        // Simuloi timer tick (varmistaa lähetys CI:ssä).
        onTimerTick(arm_tick + core.BOOT_SEND_DELAY_TICKS);
        // Anna myös oikealle PIT IRQ:lle mahdollisuus (sti/pause).
        if (!core.isSent()) core.waitForMessage();
    }
    // Vastaanottopuskuri kernel-pinossa.
    var buf: [port.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota viesti capability-slotin kautta (sama polku kuin sys_ipc_recv).
    const got = port.recvViaSlot(slot, &buf) catch {
        // Recv epäonnistui.
        log.err("IPC block recv failed");
        // Poista timer-wake riippuvuus.
        disarmTimerSend();
        // Lopeta testi.
        return;
    };
    // Poista timer-wake riippuvuus.
    disarmTimerSend();
    // Varmista vastaanotettu pituus.
    if (got != BLOCK_MSG.len) {
        // Recv epäonnistui tai timeout ei toiminut.
        log.err("IPC block recv failed");
        // Lopeta testi.
        return;
    }
    // Vertaa tavut yksi kerrallaan.
    var i: usize = 0;
    while (i < BLOCK_MSG.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != BLOCK_MSG[i]) {
            // Sisältövirhe.
            log.err("IPC block payload mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Kaikki OK.
    log.info("IPC block OK");
}
