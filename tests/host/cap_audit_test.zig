//! Host-testit capability-audit-ytimelle.

const std = @import("std");
const audit = @import("cap_audit_core");

test "record create and delegate" {
    // Puhdas audit-loki.
    audit.initCore();
    // Simuloi create-merkintä.
    audit.record(.create, 1, 5, audit.NO_SLOT, 0, 1);
    // Simuloi delegate-merkintä.
    audit.record(.delegate, 1, 5, 1, 4, 1);
    // Molemmat tyypit löytyvät.
    try std.testing.expect(audit.hasOp(.create));
    try std.testing.expect(audit.hasOp(.delegate));
    // Boot-audit hyväksyy.
    try std.testing.expect(audit.bootAuditOk());
}

test "ring buffer overwrites oldest" {
    // Puhdas loki.
    audit.initCore();
    // Täytä puskuri yli kapasiteetin.
    var i: usize = 0;
    while (i < audit.AUDIT_CAPACITY + 4) : (i += 1) {
        // Jokainen merkintä on create (yksinkertainen).
        audit.record(.create, @intCast(i), @intCast(i), audit.NO_SLOT, 0, 0);
    }
    // Lukumäärä capped at capacity.
    try std.testing.expect(audit.count() == audit.AUDIT_CAPACITY);
}

test "boot audit fails without delegate" {
    // Puhdas loki.
    audit.initCore();
    // Vain create — ei delegate.
    audit.record(.create, 1, 1, audit.NO_SLOT, 0, 1);
    // bootAuditOk vaatii delegate.
    try std.testing.expect(!audit.bootAuditOk());
}
