//! Interaktiivinen shell — tyhjä Zig-juuri (koodi start.S:ssä).
//!
//! **Vastuu**: Pakottaa linkittäjän sisällyttämään start.S:n.
//! **Riippuvuudet**: ei
//! **Käytetään**: build.zig → zinux-shell ELF → kernel/shell.zig

// Ei Zig-koodia — kaikki logiikka start.S:ssä freestanding-syscalleina.
pub export fn shellAnchor() void {}
