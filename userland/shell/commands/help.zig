//! help-komento — tulostaa saatavilla olevat komennot.
//!
//! **Vastuu**: Staattinen komentolista serialiin.
//! **Riippuvuudet**: `../syscall.zig`
//! **Käytetään**: `dispatch.zig`

// Tuo syscall-apu tulostukseen.
const sc = @import("../syscall.zig");

// Suorita help-komento — ei argumentteja.
pub fn run() void {
    // Tulosta komentolista (help, meminfo, ps).
    sc.print("Available commands:\n  help    - show this help\n  meminfo - memory info\n  ps      - list processes\n");
}
