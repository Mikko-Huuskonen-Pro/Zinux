//! Null-ajuri — stub joka aina probe:aa ja alustuu (demo 6.5).
//!
//! **Vastuu**: Esimerkkiajuri rekisteriin ilman oikeaa laitetta.
//! **Riippuvuudet**: `driver.zig`
//! **Käytetään**: `registry.zig`

// Tuo Driver-vtable ja virheet.
const driver = @import("driver.zig");

// Onko null-ajuri alustettu (shutdown nollaa).
var initialized: bool = false;

// Null-laitteen tunnistus — aina läsnä boot-demossa.
fn probe() bool {
    // Demo-ajuri — aina true.
    return true;
}

// Null-laitteen alustus — merkitse valmiiksi.
fn init() driver.DriverError!void {
    // Merkitse alustettu.
    initialized = true;
    // Onnistui.
    return;
}

// Null-laitteen sammutus — nollaa tila.
fn shutdown() void {
    // Merkitse sammutettu.
    initialized = false;
}

// Onko null-ajuri alustettu? (host-testi / debug).
pub fn isInitialized() bool {
    // Palauta globaali lippu.
    return initialized;
}

// Null-ajurin vtable rekisteriä varten.
pub const null_driver = driver.Driver{
    // Nimi boot-logissa.
    .name = "null",
    // Alusta callback.
    .init = init,
    // Probe callback.
    .probe = probe,
    // Shutdown callback.
    .shutdown = shutdown,
};
