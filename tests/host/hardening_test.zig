//! Host-testit SMEP/SMAP-ytimelle.

const std = @import("std");
const hard = @import("hardening_core");

test "smep smap feature bits" {
    // EBX jossa vain SMEP (bit 7).
    try std.testing.expect(hard.smepSupported(1 << 7));
    try std.testing.expect(!hard.smapSupported(1 << 7));
    // EBX jossa vain SMAP (bit 20).
    try std.testing.expect(hard.smapSupported(1 << 20));
    try std.testing.expect(!hard.smepSupported(1 << 20));
    // Molemmat.
    const both: u32 = (1 << 7) | (1 << 20);
    try std.testing.expect(hard.smepSupported(both));
    try std.testing.expect(hard.smapSupported(both));
}

test "cr4 with hardening sets bits" {
    // SMEP+SMAP tuettu EBX.
    const ebx: u32 = (1 << 7) | (1 << 20);
    // CR4=0 → molemmat bitit.
    const next = hard.cr4WithHardening(0, ebx);
    try std.testing.expect((next & hard.CR4_SMEP) != 0);
    try std.testing.expect((next & hard.CR4_SMAP) != 0);
}

test "activation ok when enabled" {
    // Tila: tuettu ja enabled.
    const st = hard.makeState((1 << 7) | (1 << 20), hard.CR4_SMEP | hard.CR4_SMAP);
    try std.testing.expect(hard.activationOk(st));
}

test "activation fails when supported not enabled" {
    // Tuki SMEP mutta CR4 ei asetettu.
    const st = hard.makeState(1 << 7, 0);
    try std.testing.expect(!hard.activationOk(st));
}
