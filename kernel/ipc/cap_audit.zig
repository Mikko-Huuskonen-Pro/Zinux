//! Capability-audit — kernel-loki rengaspuskuri + boot-vahvistus.
//!
//! **Vastuu**: Alusta audit-ydin, delegoi record-kutsut, boot-testi.
//! **Riippuvuudet**: `cap_audit_core.zig`, `capability_core.zig`, log
//! **Käytetään**: `capability_core.zig`, `port.zig`, `main.zig`

// Tuo ydin — rengaspuskuri ja record().
const core = @import("cap_audit_core");
// Tuo capability-tyypit record-kutsujen parametreihin.
const cap = @import("capability_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Uudelleenexportoi audit-op enum testausta varten.
pub const AuditOp = core.AuditOp;

// Muunna Rights → u32 audit-merkintää varten.
fn rightsRaw(rights: cap.Rights) u32 {
    // Packed struct bitcast.
    return @bitCast(rights);
}

// Alusta audit-loki boot-vaiheessa.
pub fn init() void {
    // Nollaa rengaspuskuri.
    core.initCore();
}

// Tallenna audit-tapahtuma — kääre oikeuksille ja tyypille.
pub fn recordCap(
    op: AuditOp,
    pid: u64,
    object_id: u32,
    slot_idx: u32,
    rights: cap.Rights,
    typ: cap.CapType,
) void {
    // Delegoi ytimelle raw-arvoilla.
    core.record(op, pid, object_id, slot_idx, rightsRaw(rights), @intFromEnum(typ));
}

// Kirjaa oikeuksien eväys (send/recv/map tms. epäonnistui).
pub fn logRightsDenied(pid: u64, slot_idx: u32, object_id: u32, requested: cap.Rights, typ: cap.CapType) void {
    // Deny-merkintä pyydetyillä oikeuksilla.
    recordCap(.rights_denied, pid, object_id, slot_idx, requested, typ);
}

// Palauta merkintöjen lukumäärä.
pub fn count() usize {
    // Delegoi ytimelle.
    return core.count();
}

// Boot-testi — vahvista create/delegate lokittu capability-testeistä.
pub fn runBootTest() void {
    // capability.runBootTest + port.runBootTest ovat jo ajaneet.
    if (!core.bootAuditOk()) {
        // Audit-loki puuttuu odotettuja tapahtumia.
        log.err("Capability audit incomplete");
        // Lopeta testi.
        return;
    }
    // Audit-loki sisältää create + delegate.
    log.info("Capability audit OK");
}
