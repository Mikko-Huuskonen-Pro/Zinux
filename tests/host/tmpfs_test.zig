//! Host-testit tmpfs-ytimelle.

const std = @import("std");
const tmpfs = @import("tmpfs_core");

test "tmpfs add open read close" {
    // Suorita ytimen self-test (addFile + open/read/close).
    tmpfs.runSelfTest() catch return error.TestFailed;
}

test "tmpfs not found" {
    // Puhdas tila.
    tmpfs.initCore();
    // Avaa tuntematon polku → NotFound.
    const result = tmpfs.open("/missing");
    try std.testing.expectError(tmpfs.TmpfsError.NotFound, result);
}
