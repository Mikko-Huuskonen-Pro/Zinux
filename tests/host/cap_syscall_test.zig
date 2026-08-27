//! Host-testit capability-syscall-ytimelle.

const std = @import("std");
const cap = @import("cap_syscall_core");

test "rights mask decode" {
    // Tyhjä maski on kelvollinen.
    try std.testing.expect(cap.maskValid(0));
    // recv-bitti dekoodataan.
    const recv_only = cap.rightsFromMask(cap.MASK_RECV) orelse return error.TestFailed;
    // recv päällä.
    try std.testing.expect(recv_only.recv);
    // send pois.
    try std.testing.expect(!recv_only.send);
    // Varattu bitti hylätään.
    try std.testing.expect(cap.rightsFromMask(1 << 16) == null);
}

test "mask constants cover all bits" {
    // MASK_ALL sisältää kaikki yksittäiset bitit.
    try std.testing.expectEqual(@as(u32, cap.MASK_READ | cap.MASK_WRITE | cap.MASK_SEND | cap.MASK_RECV | cap.MASK_MAP | cap.MASK_GRANT), cap.MASK_ALL);
}
