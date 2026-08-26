//! Loader-testi — tyhjä Zig-juuri (koodi start.S:ssä).
//!
//! **Vastuu**: Pakottaa linkittäjän sisällyttämään start.S:n.
//! **Riippuvuudet**: ei
//! **Käytetään**: build.zig → loader-test-user ELF

// Ei Zig-koodia — kaikki logiikka start.S:ssä freestanding-kutsuina.
pub export fn loaderTestAnchor() void {}
