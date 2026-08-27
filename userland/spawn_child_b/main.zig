//! Spawn-lapsi B — tyhjä Zig-juuri (koodi start.S:ssä).
//!
//! **Vastuu**: Pakottaa linkittäjän sisällyttämään start.S:n.
//! **Riippuvuudet**: ei
//! **Käytetään**: build.zig → spawn_child_b ELF

// Ei Zig-koodia — kaikki logiikka start.S:ssä freestanding-kutsuina.
pub export fn spawnChildBAnchor() void {}
