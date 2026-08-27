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

// Tuo IPC-portti-ydin-yksikkötestit.
test {
    _ = @import("port_test.zig");
}

// Tuo VFS-ydin-yksikkötestit.
test {
    _ = @import("vfs_test.zig");
}

// Tuo tmpfs-ydin-yksikkötestit.
test {
    _ = @import("tmpfs_test.zig");
}

// Tuo ajurirekisteri-ydin-yksikkötestit.
test {
    _ = @import("driver_registry_test.zig");
}

// Tuo SMEP/SMAP-ydin-yksikkötestit.
test {
    _ = @import("hardening_test.zig");
}

// Tuo pinon canary-ydin-yksikkötestit.
test {
    _ = @import("stack_canary_test.zig");
}

// Tuo KASLR-ydin-yksikkötestit.
test {
    _ = @import("kaslr_test.zig");
}
