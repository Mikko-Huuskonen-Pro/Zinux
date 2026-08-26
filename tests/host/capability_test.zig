//! Host-testit capability-ytimelle.

const std = @import("std");
const cap = @import("capability_core");

test "rights subset and intersect" {
    // Täydet oikeudet lähtökohtana.
    const full = cap.Rights{ .read = true, .send = true, .grant = true };
    // Osajoukko pyyntö.
    const partial = cap.Rights{ .send = true };
    // partial ⊆ full.
    try std.testing.expect(cap.rightsSubset(full, partial));
    // full ⊄ partial.
    try std.testing.expect(!cap.rightsSubset(partial, full));
    // Leikkaus = partial.
    const ix = cap.rightsIntersect(full, partial);
    // send säilyy.
    try std.testing.expect(ix.send);
    // read poistuu.
    try std.testing.expect(!ix.read);
}

test "create install delegate revoke" {
    // Puhdas tila.
    cap.initCore();
    // Luo portti full-oikeuksilla.
    const slot = cap.createAndInstall(.port, 1, 7, .{
        .send = true,
        .recv = true,
        .grant = true,
    }) orelse return error.TestFailed;
    // Delegoi recv-only.
    const child = cap.delegateSlot(slot, .{ .recv = true }) orelse return error.TestFailed;
    // Lapsi-slotissa ei sendiä.
    try std.testing.expect(!cap.slotHasRights(child, .{ .send = true }));
    // Lapsi-slotissa recv.
    try std.testing.expect(cap.slotHasRights(child, .{ .recv = true }));
    // Hae objektin id slotista.
    const ref = cap.lookupSlot(slot) orelse return error.TestFailed;
    // Peruuta objekti.
    try std.testing.expect(cap.revokeObject(ref.object_id));
    // Slotit eivät enää anna oikeuksia.
    try std.testing.expect(!cap.slotHasRights(slot, .{ .recv = true }));
}
