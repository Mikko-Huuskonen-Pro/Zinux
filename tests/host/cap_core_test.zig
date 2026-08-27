//! Host-testit userland capability-ytimelle.

const std = @import("std");
const cap = @import("cap_core");

test "mask validation" {
    // recv-only maski kelpaa.
    try std.testing.expect(cap.validMask(cap.MASK_RECV));
    // Yhdistelmä kelpaa.
    try std.testing.expect(cap.validMask(cap.MASK_SEND | cap.MASK_RECV));
    // Varattu bitti hylätään.
    try std.testing.expect(!cap.validMask(cap.MASK_ALL | (1 << 16)));
}

test "syscall error detection" {
    // Positiivinen slot-indeksi ei virhe.
    try std.testing.expect(!cap.isError(6));
    // Negatiivinen on virhe.
    try std.testing.expect(cap.isError(cap.EPERM));
}
