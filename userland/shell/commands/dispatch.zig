//! Shell-komentojen dispatch — rivi → oikea handler.
//!
//! **Vastuu**: Tunnista help/meminfo/ps ja kutsu moduulia.
//! **Riippuvuudet**: `help.zig`, `meminfo.zig`, `ps.zig`
//! **Käytetään**: `main.zig`

// Tuo syscall-apu rivin vertailuun.
const sc = @import("../syscall.zig");
// Tuo help-komento.
const help = @import("help.zig");
// Tuo meminfo-komento.
const meminfo = @import("meminfo.zig");
// Tuo ps-komento.
const ps = @import("ps.zig");

// Suorita yksi shell-rivi — tunnista komento ja delegoi.
pub fn dispatch(line: []const u8) void {
    // help-komento.
    if (sc.lineEquals(line, "help")) {
        // Tulosta komentolista.
        help.run();
        // Valmis.
        return;
    }
    // meminfo-komento.
    if (sc.lineEquals(line, "meminfo")) {
        // Tulosta muistitiedot.
        meminfo.run();
        // Valmis.
        return;
    }
    // ps-komento.
    if (sc.lineEquals(line, "ps")) {
        // Tulosta prosessilista.
        ps.run();
        // Valmis.
        return;
    }
    // Tuntematon komento — lyhyt virheilmoitus.
    sc.print("Unknown command\n");
}
