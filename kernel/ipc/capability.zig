//! Capability-hallinta — kernel-rajapinta boot-testeineen.
//!
//! **Vastuu**: Alustus, delegointi, boot-smoke test.
//! **Riippuvuudet**: `capability_core.zig`, log
//! **Käytetään**: `kernel/main.zig`, tulevat IPC-syscallit

// Tuo ydinlogiikka — objektit, slotit, oikeudet.
const core = @import("capability_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Uudelleenexportoi tyypit ulkoisille käyttäjille.
pub const CapType = core.CapType;
// Uudelleenexportoi oikeusbitit.
pub const Rights = core.Rights;
// Uudelleenexportoi objektirakenne.
pub const CapObject = core.CapObject;
// Uudelleenexportoi slot-viite.
pub const CapRef = core.CapRef;

// Alusta capability-alijärjestelmä boot-vaiheessa.
pub fn init() void {
    // Nollaa objektitaulukko ja slotit.
    core.initCore();
}

// Boot-testi — luo portti-cap, delegoi recv-only, tarkista oikeudet.
pub fn runBootTest() void {
    // Varmista ydin on alustettu.
    init();
    // Täydet portti-oikeudet omistajalle (pid 1 stub).
    const full_rights = Rights{
        // Lue portin metatiedot.
        .read = true,
        // Kirjoita portin metatiedot (stub).
        .write = true,
        // Lähetä viestejä.
        .send = true,
        // Vastaanota viestejä.
        .recv = true,
        // Delegoi edelleen.
        .grant = true,
    };
    // Luo portti-capability (resource_id 42 = testiportti).
    const slot = core.createAndInstall(.port, 1, 42, full_rights) orelse {
        // Luonti epäonnistui.
        log.err("Capability create failed");
        // Lopeta testi.
        return;
    };
    // Tarkista send-oikeus alkuperäisessä slotissa.
    if (!core.slotHasRights(slot, .{ .send = true })) {
        // Odotettu send puuttuu.
        log.err("Capability send right missing");
        // Lopeta testi.
        return;
    }
    // Delegoi vain recv-oikeus uuteen slottiin.
    const derived = core.delegateSlot(slot, .{ .recv = true }) orelse {
        // Delegointi epäonnistui.
        log.err("Capability delegate failed");
        // Lopeta testi.
        return;
    };
    // Delegoidussa slotissa ei saa olla send-oikeutta.
    if (core.slotHasRights(derived, .{ .send = true })) {
        // Delegointi vuoti liikaa oikeuksia.
        log.err("Capability delegate leaked send");
        // Lopeta testi.
        return;
    }
    // Delegoidussa slotissa pitää olla recv.
    if (!core.slotHasRights(derived, .{ .recv = true })) {
        // recv puuttuu delegoidusta slotista.
        log.err("Capability derived recv missing");
        // Lopeta testi.
        return;
    }
    // Kaikki tarkistukset OK.
    log.info("Capability test OK");
}
