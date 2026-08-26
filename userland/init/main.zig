//! Init-prosessi — Zinuxin ensimmäinen käyttäjätilan prosessi.
//!
//! **Vastuu**: Tyhjä Zig-juuri; suoritus start.S:ssä (freestanding).
//! **Riippuvuudet**: ei
//! **Käytetään**: build.zig → zinux-init ELF → kernel/init.zig

// Pakota linkittäjän säilyttämään start.S — ei Zig-logiikkaa vielä.
pub export fn initAnchor() void {}
