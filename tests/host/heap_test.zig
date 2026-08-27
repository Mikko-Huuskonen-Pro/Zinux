//! Host-testit heap-ytimelle (first-fit).

const std = @import("std");
const heap_core = @import("heap_core");

test "heap first-fit alloc and free" {
    // 4 KiB puskuri riittää usealle pienelle allokoinnille.
    var buf: [4096]u8 = undefined;
    // Alusta heap puskurilla ilman VMM:ää.
    heap_core.initBuffer(&buf);
    // Allokoi kaksi erikokoista lohkoa.
    const a = heap_core.alloc(64) orelse return error.TestFailed;
    const b = heap_core.alloc(128) orelse return error.TestFailed;
    // Lohkojen pitää olla eri osoitteissa.
    try std.testing.expect(@intFromPtr(a) != @intFromPtr(b));
    // Vapauta ensimmäinen lohko.
    heap_core.free(a);
    // Vapauta toinen lohko.
    heap_core.free(b);
    // Uudelleenallokointi first-fit-listalta.
    const c = heap_core.alloc(32) orelse return error.TestFailed;
    // Osoitteen pitää olla kelvollinen puskurin sisällä.
    try std.testing.expect(@intFromPtr(c) >= @intFromPtr(&buf));
}

test "heap allocWithGrow callback" {
    // Pieni puskuri — pakottaa grow-callbackin kutsumisen.
    var buf: [256]u8 = undefined;
    heap_core.initBuffer(&buf);
    // Laskuri grow-kutsuille testin sisäisessä structissa.
    const GrowState = struct {
        // Montako kertaa grow kutsuttiin.
        var calls: usize = 0;
        // grow palauttaa aina false → allokointi epäonnistuu lopulta.
        fn grow() bool {
            calls += 1;
            return false;
        }
    };
    // Nollaa laskuri ennen testiä.
    GrowState.calls = 0;
    // Allokointi liian suurelle lohkolle → grow kutsutaan.
    const ptr = heap_core.allocWithGrow(512, GrowState.grow);
    // Allokoinnin pitää epäonnistua kun grow ei laajenna heapia.
    try std.testing.expect(ptr == null);
    // Grow-callback kutsuttiin vähintään kerran.
    try std.testing.expect(GrowState.calls >= 1);
}
