//! Host-testit IPC-estävän recv-ytimelle.

const std = @import("std");
const block = @import("ipc_block_core");

test "timer arm and fire" {
    // Puhdas tila.
    block.disarm();
    // Aseista portti 3 tick 10:stä, viive 2.
    block.armTimerSendViaPort(3, 10, 2);
    // Ei vielä aika.
    try std.testing.expect(!block.shouldFire(11));
    // Viive täyttyy tick 12.
    try std.testing.expect(block.shouldFire(12));
    // Ei vielä lähetetty.
    try std.testing.expect(!block.isSent());
    // Merkitse lähetetyksi.
    block.markSent();
    // Ei enää ammu.
    try std.testing.expect(!block.shouldFire(13));
}

test "disarm clears state" {
    // Aseista ja disarm.
    block.armTimerSendViaPort(1, 0, 1);
    block.disarm();
    // Ei ammu.
    try std.testing.expect(block.armedPort() == null);
    try std.testing.expect(!block.shouldFire(100));
}
