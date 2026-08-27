//! Host-testit prosessitaulukon ytimelle.

const std = @import("std");
const proc = @import("process_core");
const cap = @import("capability_core");

test "process table alloc and current pid" {
    // Puhdas tila.
    proc.initCore();
    // Boot-prosessi rekisteröity automaattisesti.
    try std.testing.expectEqual(@as(usize, 1), proc.processCount());
    try std.testing.expectEqual(@as(u64, 1), proc.currentPid());
    // Toinen prosessi.
    try std.testing.expect(proc.allocProcess(2));
    try std.testing.expectEqual(@as(usize, 2), proc.processCount());
    // Vaihda current pid.
    try std.testing.expect(proc.setCurrentPid(2));
    try std.testing.expectEqual(@as(u64, 2), proc.currentPid());
    // Tuntematon pid hylätään.
    try std.testing.expect(!proc.setCurrentPid(99));
}

test "capability slots isolated per process" {
    // Puhdas tila — prosessi 1 + capability.
    cap.initCore();
    // Rekisteröi prosessi 2.
    try std.testing.expect(proc.allocProcess(2));
    // Objekti prosessille 1.
    const obj1 = cap.createObject(.port, 1, 11) orelse return error.TestFailed;
    const slot1 = cap.installSlotForPid(1, obj1, .{ .send = true }) orelse return error.TestFailed;
    // Objekti prosessille 2.
    const obj2 = cap.createObject(.port, 2, 22) orelse return error.TestFailed;
    const slot2 = cap.installSlotForPid(2, obj2, .{ .recv = true }) orelse return error.TestFailed;
    // Sama slot-indeksi molemmilla prosesseilla (0).
    try std.testing.expectEqual(@as(u32, 0), slot1);
    try std.testing.expectEqual(@as(u32, 0), slot2);
    // Eri objektit lookupSlotForPid:llä.
    const ref1 = cap.lookupSlotForPid(1, slot1) orelse return error.TestFailed;
    const ref2 = cap.lookupSlotForPid(2, slot2) orelse return error.TestFailed;
    try std.testing.expect(ref1.object_id != ref2.object_id);
    // lookupSlot käyttää current pid:tä.
    try std.testing.expect(proc.setCurrentPid(2));
    const cur = cap.lookupSlot(slot2) orelse return error.TestFailed;
    try std.testing.expectEqual(ref2.object_id, cur.object_id);
}
