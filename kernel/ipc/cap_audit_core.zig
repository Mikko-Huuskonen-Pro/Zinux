//! Capability-audit-ydin — rengaspuskuri tapahtumille (host-testattava).
//!
//! **Vastuu**: Tallenna create/delegate/revoke/deny -tapahtumat audit-lokiin.
//! **Riippuvuudet**: ei
//! **Käytetään**: `cap_audit.zig`, `capability_core.zig`, host-testit

// Audit-tapahtuman tyyppi — mitä capability-operaatiota logataan.
pub const AuditOp = enum(u8) {
    // Uusi capability-objekti luotu.
    create = 0,
    // Capability asennettu slottiin.
    install = 1,
    // Oikeuksia delegoitu uuteen slottiin.
    delegate = 2,
    // Objekti peruutettu (revoke).
    revoke = 3,
    // Oikeustarkistus epäonnistui (deny).
    rights_denied = 4,
};

// Yksittäinen audit-merkintä — kiinteä koko rengaspuskurissa.
pub const AuditEntry = struct {
    // Tapahtuman tyyppi.
    op: AuditOp,
    // Prosessi joka aiheutti tapahtuman (stub pid).
    pid: u64,
    // Capability-objektin id (0 jos ei relevantti).
    object_id: u32,
    // Slot-indeksi (0xFFFFFFFF = ei slotia).
    slot_idx: u32,
    // Oikeusbitit raw-muodossa (Rights packed u32).
    rights_raw: u32,
    // Objektin tyyppi numerona (CapType u8).
    cap_type: u8,
};

// Ei slotia — sentinel formatointia varten.
pub const NO_SLOT: u32 = 0xFFFF_FFFF;
// Rengaspuskurin koko — viimeisimmät N tapahtumaa.
pub const AUDIT_CAPACITY: usize = 32;

// Kiinteä rengaspuskuri audit-merkinnöille.
var entries: [AUDIT_CAPACITY]AuditEntry = undefined;
// Seuraava kirjoitusindeksi (mod AUDIT_CAPACITY).
var write_idx: usize = 0;
// Montako merkintää on koskaan tallennettu (max AUDIT_CAPACITY).
var entry_count: usize = 0;
// Onko audit-ydin alustettu.
var initialized: bool = false;

// Nollaa rengaspuskuri — boot ja host-testit.
pub fn initCore() void {
    // Indeksi alkuun.
    write_idx = 0;
    // Ei merkintöjä.
    entry_count = 0;
    // Valmis tallentamaan.
    initialized = true;
}

// Tallenna yksi audit-tapahtuma rengaspuskuriin.
pub fn record(
    op: AuditOp,
    pid: u64,
    object_id: u32,
    slot_idx: u32,
    rights_raw: u32,
    cap_type: u8,
) void {
    // Älä tallenna ennen init():ää.
    if (!initialized) return;
    // Täytä merkintä.
    entries[write_idx] = .{
        // Tapahtumatyyppi.
        .op = op,
        // Prosessitunniste.
        .pid = pid,
        // Objektiviite.
        .object_id = object_id,
        // Slotti tai NO_SLOT.
        .slot_idx = slot_idx,
        // Oikeudet raw-biteinä.
        .rights_raw = rights_raw,
        // CapType numerona.
        .cap_type = cap_type,
    };
    // Siirry seuraavaan rengaslokeroon.
    write_idx = (write_idx + 1) % AUDIT_CAPACITY;
    // Kasvata lukumäärää kunnes puskuri täynnä.
    if (entry_count < AUDIT_CAPACITY) entry_count += 1;
}

// Palauta tallennettujen merkintöjen määrä (max AUDIT_CAPACITY).
pub fn count() usize {
    // Palauta merkintälaskuri.
    return entry_count;
}

// Hae merkintä ikäjärjestyksessä (0 = vanhin tallessa oleva).
pub fn getEntry(age: usize) ?AuditEntry {
    // Ei merkintöjä tai ikä liian suuri.
    if (entry_count == 0 or age >= entry_count) return null;
    // Vanhin indeksi kun puskuri kiertää.
    const oldest = if (entry_count < AUDIT_CAPACITY) 0 else write_idx;
    // Absoluuttinen indeksi rengasbufferissa.
    const idx = (oldest + age) % AUDIT_CAPACITY;
    // Palauta kopio merkinnästä.
    return entries[idx];
}

// Onko vähintään yksi merkintä annetulla op-tyypillä?
pub fn hasOp(op: AuditOp) bool {
    // Käy kaikki tallessa olevat merkinnät.
    var i: usize = 0;
    while (i < entry_count) : (i += 1) {
        // Hae i:s vanhin merkintä.
        const e = getEntry(i) orelse return false;
        // Tyyppi täsmää → löytyi.
        if (e.op == op) return true;
    }
    // Ei löytynyt.
    return false;
}

// Boot/audit-testi: create + delegate pitää olla lokissa.
pub fn bootAuditOk() bool {
    // Vähintään yksi create ja yksi delegate.
    if (!hasOp(.create)) return false;
    if (!hasOp(.delegate)) return false;
    // Vähintään kaksi merkintää yhteensä.
    if (count() < 2) return false;
    // OK.
    return true;
}
