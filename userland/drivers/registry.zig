//! Ajurirekisteri — comptime ajurilista userland-ajureille.
//!
//! **Vastuu**: Rekisteröi ajurit, delegoi registry_core:lle.
//! **Riippuvuudet**: `registry_core.zig`, `null_dev.zig`
//! **Käytetään**: `main.zig`

// Tuo ydin — init/shutdown-silmukka.
const core = @import("registry_core.zig");
// Tuo null-demoajuri.
const null_dev = @import("null_dev.zig");

// Uudelleenexportoi tyypit.
pub const Driver = core.Driver;
// Uudelleenexportoi virheet.
pub const DriverError = core.DriverError;

// Kaikki käyttäjätilan ajurit — comptime taulukko (ARCHITECTURE §8).
const driver_table = [_]Driver{
    // Demo-stub — aina probe + init.
    null_dev.null_driver,
};

// Alusta kaikki rekisteröidyt ajurit.
pub fn initAll() DriverError!void {
    // Delegoi ytimelle comptime-taulukko.
    try core.initAll(&driver_table);
}

// Sammuta kaikki rekisteröidyt ajurit.
pub fn shutdownAll() void {
    // Delegoi ytimelle comptime-taulukko.
    core.shutdownAll(&driver_table);
}

// Montako ajuria probe hyväksyy — boot-vahvistus.
pub fn probedCount() usize {
    // Delegoi ytimelle.
    return core.countProbed(&driver_table);
}
