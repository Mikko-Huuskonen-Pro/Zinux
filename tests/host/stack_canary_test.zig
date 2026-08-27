//! Host-testit pinon canary-ytimelle.

const std = @import("std");
const canary = @import("stack_canary_core");

test "paint and check bottom canary" {
    // Pieni pinomuisti testiin.
    var stack: [64]u8 align(16) = undefined;
    // Aluksi canary puuttuu.
    try std.testing.expect(!canary.checkBottom(&stack));
    // Maalaa magic alareunaan.
    canary.paintBottom(&stack);
    // Nyt tarkistus onnistuu.
    try std.testing.expect(canary.checkBottom(&stack));
}

test "verify all stacks" {
    // Kaksi pinomuistialuetta.
    var a: [32]u8 align(16) = undefined;
    var b: [32]u8 align(16) = undefined;
    // Maalaa molemmat.
    canary.paintBottom(&a);
    canary.paintBottom(&b);
    // verifyAll hyväksyy ehjät pinot.
    try std.testing.expect(canary.verifyAll(&.{ &a, &b }));
    // Ylikirjoita toisen canary → verifyAll epäonnistuu.
    a[0] = 0;
    try std.testing.expect(!canary.verifyAll(&.{ &a, &b }));
}

test "canary constant is non-zero" {
    // Magic ei saa olla nolla — helppo havaita bugi.
    try std.testing.expect(canary.CANARY != 0);
}
