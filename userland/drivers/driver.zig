//! Käyttäjätilan ajuri — vtable-rajapinta (ARCHITECTURE.md §8).
//!
//! **Vastuu**: Driver-rakenne init/probe/shutdown -callbackeineen.
//! **Riippuvuudet**: ei
//! **Käytetään**: `registry_core.zig`, `null_dev.zig`

// Ajurin alustus-/sulkemisvirheet.
pub const DriverError = error{
    // Laitetta ei löydy tai probe epäonnistui.
    NotPresent,
    // Alustus epäonnistui (resurssit, capability).
    InitFailed,
};

// Yksittäinen käyttäjätilan ajuri — sama muoto kuin kernel Driver-vtable.
pub const Driver = struct {
    // Lyhyt nimi boot-logissa (esim. "null").
    name: []const u8,
    // Alusta laite — kutsutaan vain jos probe() true.
    init: *const fn () DriverError!void,
    // Tunnista laite — false ohittaa init/shutdown.
    probe: *const fn () bool,
    // Vapauta resurssit sammutuksessa.
    shutdown: *const fn () void,
};
