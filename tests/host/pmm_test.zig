//! Host-testit PMM:lle.

// Tuo standardikirjasto testiasserteja varten.
const std = @import("std");
// Tuo PMM-moduuli suoraan kernel/mm:stä.
const pmm = @import("pmm");

// Testaa kehyksen allokointi, vapautus ja uudelleenkäyttö.
test "PMM alloc and free frame" {
    // Paikallinen bitmap-puskuri 64 kehykselle (16 tavua).
    var bmp: [16]u8 = undefined;
    // Alusta PMM 64 kehyksellä.
    pmm.init(&bmp, 64);
    // Allokoi kaksi kehystä peräkkäin.
    const a = pmm.allocFrame() orelse return error.TestFailed;
    const b = pmm.allocFrame() orelse return error.TestFailed;
    // Kehysten indeksit eri (bitmap next-fit).
    try std.testing.expect(a != b);
    // Vapauta ensimmäinen kehys.
    pmm.freeFrame(a);
    // Allokoi uudelleen — saa validin indeksin.
    const c = pmm.allocFrame() orelse return error.TestFailed;
    // c on validi kehysindeksi (< 64).
    try std.testing.expect(c < 64);
}

// Testaa availableFrames() ennen ja jälkeen allokoinnin.
test "PMM available frame count" {
    // Paikallinen bitmap 32 kehykselle.
    var bmp: [4]u8 = undefined;
    // Alusta PMM — kaikki 32 kehystä vapaana.
    pmm.init(&bmp, 32);
    // Kaikkien kehysten pitäisi olla vapaana.
    try std.testing.expectEqual(@as(usize, 32), pmm.availableFrames());
    // Allokoi yksi kehys.
    _ = pmm.allocFrame() orelse return error.TestFailed;
    // Vapaita jäljellä 31.
    try std.testing.expectEqual(@as(usize, 31), pmm.availableFrames());
}
