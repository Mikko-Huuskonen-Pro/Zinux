//! Host-yksikkötestit — ajetaan normaalilla Zig-targetilla (std käytössä).
//!
//! **Vastuu**: Testaa kernel-apukirjaston logiikka ilman freestanding-rajoituksia.

const std = @import("std");

// Testaa että placeholder-testi ajetaan — varmistaa CI-putken toimivuuden.
test "host test infrastructure works" {
    // Luo test-allokaattori std.testing-allocatorilla.
    const allocator = std.testing.allocator;
    // Allokoi pieni tavu varmistaaksemme allocatorin toimivuuden.
    const buf = try allocator.alloc(u8, 4);
    // Vapauta allokaatio — ei muistivuotoja testeissä.
    defer allocator.free(buf);
    // Varmista että allokaatio onnistui (buf.len > 0).
    try std.testing.expect(buf.len == 4);
}

// Tuo PMM-yksikkötestit.
test {
    _ = @import("pmm_test.zig");
}

// Tuo heap-ydin-yksikkötestit.
test {
    _ = @import("heap_test.zig");
}

// Tuo capability-ydin-yksikkötestit.
test {
    _ = @import("capability_test.zig");
}
