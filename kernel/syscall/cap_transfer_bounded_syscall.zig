//! Cap transfer bounded boot-testi — deduplikointi + MAX_SLOTS raja (Vaihe 27.0).
//!
//! **Vastuu**: Varmista ettei sys_cap_transfer täytä uhrin 32 slottia duplikaateilla.
//! **Riippuvuudet**: `capability_core.zig`, `port.zig`, `process_core`
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo capability — transferSlotToPid ja slotCountForPid.
const cap = @import("../ipc/capability_core.zig");
// Tuo IPC-portit — createPort uusille objekteille.
const port = @import("../ipc/port.zig");
// Tuo prosessitaulukko — pid-allokaatio ja current pid.
const process = @import("process_core");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — 33× sama transfer dedup + 33. eri objekti epäonnistuu.
pub fn runBootTest() void {
    // Uhrin prosessitunniste — vastaanottaa transferit.
    const victim = process.allocNextPid() orelse {
        // Prosessitaulukko täynnä.
        log.err("Cap transfer bounded alloc victim failed");
        // Lopeta testi.
        return;
    };
    // Hyökkääjän prosessitunniste — omistaa grant-capabilityn.
    const attacker = process.allocNextPid() orelse {
        // Prosessitaulukko täynnä.
        log.err("Cap transfer bounded alloc attacker failed");
        // Lopeta testi.
        return;
    };
    // Luo IPC-portti grant-transfer-testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Cap transfer bounded port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet grant + read — recv siirrettävissä uhrille.
    const rights = cap.Rights{
        // Lue portin metatiedot.
        .read = true,
        // Siirto-oikeus uhrille.
        .grant = true,
        // Vastaanotto siirrettävissä (dedup-testi).
        .recv = true,
    };
    // Asenna capability hyökkääjälle.
    const slot = cap.createAndInstall(.port, attacker, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("Cap transfer bounded cap install failed");
        // Lopeta testi.
        return;
    };
    // Aseta current pid hyökkääjälle ennen transfer-silmukkaa.
    if (!process.setCurrentPid(attacker)) {
        // setCurrentPid epäonnistui.
        log.err("Cap transfer bounded set attacker failed");
        // Lopeta testi.
        return;
    }
    // Siirrä recv-oikeus uhrille — dedup palauttaa saman slotin.
    const recv_rights = cap.Rights{ .read = true, .recv = true };
    // Ensimmäinen siirto — tallenna slot-indeksi vertailuun.
    var first_slot: u32 = undefined;
    // Toista sama transfer 33 kertaa — ei saa täyttää slottitaulukkoa.
    var dup_i: usize = 0;
    while (dup_i < 33) : (dup_i += 1) {
        // Siirrä sama objekti uhrille uudelleen.
        const got = cap.transferSlotToPid(slot, victim, recv_rights) orelse {
            // Dedup-silmukan transfer epäonnistui.
            log.err("Cap transfer bounded dedup transfer failed");
            // Lopeta testi.
            return;
        };
        // Ensimmäisellä kierroksella tallenna odotettu slotti.
        if (dup_i == 0) {
            // Uhrin ensimmäinen slotti.
            first_slot = got;
        } else if (got != first_slot) {
            // Dedup palautti eri slotin — S2-aukkoa ei korjattu.
            log.err("Cap transfer bounded dedup slot mismatch");
            // Lopeta testi.
            return;
        }
    }
    // Uhrilla pitää olla tasan yksi slotti dedup-silmukan jälkeen.
    const after_dup = cap.slotCountForPid(victim) orelse {
        // slotCountForPid epäonnistui.
        log.err("Cap transfer bounded slot count failed");
        // Lopeta testi.
        return;
    };
    if (after_dup != 1) {
        // Liikaa slotteja duplikaateista.
        log.err("Cap transfer bounded dedup slot count wrong");
        // Lopeta testi.
        return;
    }
    // Täytä loput slottipaikat eri objekteilla (ei uusia IPC-portteja — porttitaulukko usein täynnä bootissa).
    var fill_i: usize = 0;
    // MAX_SLOTS - 1 koska recv-slotti jo uhrilla dedup-silmakasta.
    const fill_target = cap.MAX_SLOTS - 1;
    while (fill_i < fill_target) : (fill_i += 1) {
        // Luo capability-objekti ilman fyysistä porttia — riittää slottitäyttötestiin.
        const obj_id = cap.createObject(.port, attacker, 8000 + fill_i) orelse {
            // Objektitaulukko täynnä kesken täyttöä.
            log.err("Cap transfer bounded fill object failed");
            // Lopeta testi.
            return;
        };
        // Asenna suoraan uhrille — simuloi aiemmin siirrettyjä cappeja.
        _ = cap.installSlotForPid(victim, obj_id, .{ .read = true }) orelse {
            // Slottiasennus epäonnistui ennen MAX_SLOTS:ia.
            log.err("Cap transfer bounded fill install failed");
            // Lopeta testi.
            return;
        };
    }
    // Uhrin slottitaulukko nyt täynnä (32 slottia).
    const full_count = cap.slotCountForPid(victim) orelse {
        // slotCountForPid epäonnistui.
        log.err("Cap transfer bounded full count failed");
        // Lopeta testi.
        return;
    };
    if (full_count != cap.MAX_SLOTS) {
        // Odotettiin MAX_SLOTS slottia täytön jälkeen.
        log.err("Cap transfer bounded full count wrong");
        // Lopeta testi.
        return;
    }
    // 33. eri objekti hyökkääjällä — transfer pitää epäonnistua (uhrin taulukko täynnä).
    const overflow_obj = cap.createObject(.port, attacker, 8999) orelse {
        // Objektin luonti epäonnistui.
        log.err("Cap transfer bounded overflow object failed");
        // Lopeta testi.
        return;
    };
    // Grant-cap hyökkääjän slottiin siirtoa varten.
    const overflow_slot = cap.installSlotForPid(attacker, overflow_obj, .{
        // Siirto-oikeus.
        .grant = true,
        // Lue metatiedot.
        .read = true,
    }) orelse {
        // Asennus epäonnistui.
        log.err("Cap transfer bounded overflow cap failed");
        // Lopeta testi.
        return;
    };
    // Yritä siirtää täyteen taulukkoon — pitää palauttaa null.
    if (cap.transferSlotToPid(overflow_slot, victim, .{ .read = true }) != null) {
        // MAX_SLOTS ylittyi — S2 korjaus puutteellinen.
        log.err("Cap transfer bounded overflow should fail");
        // Lopeta testi.
        return;
    }
    // Palauta boot-prosessin konteksti.
    _ = process.setCurrentPid(process.BOOT_PID);
    // Vaihe 27.0 valmis.
    log.info("Cap transfer bounded OK");
}
