//! Host-testit PMM:lle.

const std = @import("std");
const pmm = @import("pmm");

test "PMM alloc and free frame" {
    var bmp: [16]u8 = undefined;
    pmm.init(&bmp, 64);
    const a = pmm.allocFrame() orelse return error.TestFailed;
    const b = pmm.allocFrame() orelse return error.TestFailed;
    try std.testing.expect(a != b);
    pmm.freeFrame(a);
    const c = pmm.allocFrame() orelse return error.TestFailed;
    // c on validi kehysindeksi.
    try std.testing.expect(c < 64);
}
