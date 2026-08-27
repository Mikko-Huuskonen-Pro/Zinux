//! Host-testit ajurirekisteri-ytimelle.

const std = @import("std");
const reg = @import("driver_registry_core");

// Testilaskuri init-kutsuille.
var init_calls: usize = 0;
// Testilaskuri shutdown-kutsuille.
var shutdown_calls: usize = 0;
// Probe palauttaako true testiajurille.
var probe_yes: bool = true;

// Testiajurin probe-callback.
fn testProbe() bool {
    // Palauta testilippu.
    return probe_yes;
}

// Testiajurin init-callback.
fn testInit() reg.DriverError!void {
    // Kasvata laskuria.
    init_calls += 1;
}

// Testiajurin shutdown-callback.
fn testShutdown() void {
    // Kasvata laskuria.
    shutdown_calls += 1;
}

// Testiajurin vtable.
const test_driver = reg.Driver{
    // Nimi testissä.
    .name = "test",
    // Init callback.
    .init = testInit,
    // Probe callback.
    .probe = testProbe,
    // Shutdown callback.
    .shutdown = testShutdown,
};

test "registry init and shutdown probed drivers" {
    // Nollaa laskurit.
    init_calls = 0;
    shutdown_calls = 0;
    probe_yes = true;
    // Yksi testiajuri taulukossa.
    const table = [_]reg.Driver{test_driver};
    // Alusta — init kutsutaan kerran.
    try reg.initAll(&table);
    try std.testing.expect(init_calls == 1);
    // Sammuta — shutdown kutsutaan kerran.
    reg.shutdownAll(&table);
    try std.testing.expect(shutdown_calls == 1);
}

test "registry skips probe false" {
    // Nollaa laskurit.
    init_calls = 0;
    probe_yes = false;
    // Yksi testiajuri jota ei probata.
    const table = [_]reg.Driver{test_driver};
    // Alusta — ei init-kutsuja.
    try reg.initAll(&table);
    try std.testing.expect(init_calls == 0);
    // countProbed = 0.
    try std.testing.expect(reg.countProbed(&table) == 0);
}
