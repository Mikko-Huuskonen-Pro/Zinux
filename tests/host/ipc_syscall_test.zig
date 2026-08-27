//! Host-testit IPC-syscall-ytimelle.

const std = @import("std");
const ipc = @import("ipc_syscall_core");

test "map port errors to abi codes" {
    // NotFound → EBADF.
    try std.testing.expectEqual(ipc.EBADF, ipc.mapPortError(error.NotFound));
    // Full → EAGAIN.
    try std.testing.expectEqual(ipc.EAGAIN, ipc.mapPortError(error.Full));
    // Empty → EAGAIN.
    try std.testing.expectEqual(ipc.EAGAIN, ipc.mapPortError(error.Empty));
    // TooLarge → EINVAL.
    try std.testing.expectEqual(ipc.EINVAL, ipc.mapPortError(error.TooLarge));
    // NotInitialized → EINVAL.
    try std.testing.expectEqual(ipc.EINVAL, ipc.mapPortError(error.NotInitialized));
}
