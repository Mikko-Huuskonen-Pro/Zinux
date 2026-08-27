//! Käyttäjämuistin käyttö kernelistä — SMAP stac/clac -apu.
//!
//! **Vastuu**: Salli tilapäisesti user-sivujen data-käyttö syscalleissa.
//! **Riippuvuudet**: `hardening.zig`
//! **Käytetään**: `syscall/dispatch.zig`

// Tuo hardening — onko SMAP CR4:ssä käytössä.
const hardening = @import("hardening.zig");

// Aseta RFLAGS.AC — kernel saa lukea/kirjoittaa user-sivuja (SMAP).
pub inline fn stac() void {
    // Ei SMAP:ia → stac aiheuttaisi #UD vanhoilla CPU:illa.
    if (!hardening.smapActive()) return;
    // stac asettaa AC-bitin (RFLAGS bit 18).
    asm volatile ("stac"
        :
        :
        : .{ .memory = true });
}

// Tyhjennä RFLAGS.AC — palauta SMAP-suojaus.
pub inline fn clac() void {
    // Ei SMAP:ia → clac on turha mutta turvallinen; ohita yhtenäisyyden vuoksi.
    if (!hardening.smapActive()) return;
    // clac poistaa AC-bitin.
    asm volatile ("clac"
        :
        :
        : .{ .memory = true });
}
