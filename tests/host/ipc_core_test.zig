//! Host-testit userland IPC-ytimelle.

const std = @import("std");
const ipc = @import("ipc_core");

test "send and recv length limits" {
    // Nolla ja max sallittu.
    try std.testing.expect(ipc.validSendLen(0));
    try std.testing.expect(ipc.validSendLen(ipc.MAX_MSG_SIZE));
    // Yli max hylätään.
    try std.testing.expect(!ipc.validSendLen(ipc.MAX_MSG_SIZE + 1));
    // Recv vaatii positiivisen puskurin.
    try std.testing.expect(ipc.validRecvBufLen(1));
    try std.testing.expect(!ipc.validRecvBufLen(0));
}

test "syscall error classification" {
    // Onnistunut paluu ei virhe.
    try std.testing.expect(!ipc.isError(3));
    try std.testing.expect(ipc.classifyError(3) == null);
    // Negatiiviset luokitellaan.
    try std.testing.expect(ipc.isError(ipc.EBADF));
    try std.testing.expectEqual(ipc.EBADF, ipc.classifyError(ipc.EBADF));
    try std.testing.expectEqual(ipc.EAGAIN, ipc.classifyError(ipc.EAGAIN));
}
