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

test "cap create type validation" {
    // Portti-tyyppi tuettu.
    try std.testing.expect(cap.typeValid(cap.CAP_TYPE_PORT));
    // Tuntematon tyyppi hylätään.
    try std.testing.expect(!cap.typeValid(99));
}

test "rights mask roundtrip" {
    // Täydet oikeudet maskissa.
    const full_mask = cap.MASK_READ | cap.MASK_SEND | cap.MASK_RECV | cap.MASK_GRANT;
    // Dekoodaa maski → Rights.
    const rights = cap.rightsFromMask(full_mask) orelse return error.TestFailed;
    // Koodaa Rights → maski.
    const back = cap.rightsToMask(rights);
    // Roundtrip täsmää.
    try std.testing.expectEqual(full_mask, back);
    // recv-only maski.
    const recv_mask = cap.MASK_RECV;
    // Dekoodaa recv-only.
    const recv_rights = cap.rightsFromMask(recv_mask) orelse return error.TestFailed;
    // Koodaa takaisin.
    try std.testing.expectEqual(recv_mask, cap.rightsToMask(recv_rights));
}
