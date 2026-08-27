//! Host-testit ps_syscall_core-ytimelle.

const std = @import("std");
const ps = @import("ps_syscall_core");
const proc = @import("process_core");

// Callback testeihin — delegoi process_core.pidAt.
fn pidAtCb(index: usize) ?u64 {
    // Hae pid prosessitaulukosta.
    return proc.pidAt(index);
}

// Callback testeihin — delegoi process_core.isLoaded.
fn loadedAtCb(pid: u64) bool {
    // Hae loaded-tila prosessitaulukosta.
    return proc.isLoaded(pid);
}

test "process name by pid and loaded flag" {
    // Boot-prosessi.
    try std.testing.expectEqualStrings("boot", ps.processName(1, false));
    // Ladattu user-prosessi.
    try std.testing.expectEqualStrings("user", ps.processName(5, true));
    // Rekisteröity mutta ei ladattu.
    try std.testing.expectEqualStrings("proc", ps.processName(5, false));
}

test "format listing from process table" {
    // Puhdas tila.
    proc.initCore();
    // Boot + kaksi prosessia.
    try std.testing.expect(proc.allocProcess(2));
    try std.testing.expect(proc.allocProcess(3));
    // Prosessi 3 spawnattu (loaded).
    try std.testing.expect(proc.setLoaded(3, 0x1000, 0x2000, 1));
    // Muotoile lista.
    var buf: [256]u8 = undefined;
    const len = ps.formatListing(proc.processCount(), pidAtCb, loadedAtCb, &buf);
    // Pitää mahtua otsikko + rivit.
    try std.testing.expect(len > 12);
    const listing = buf[0..len];
    // Boot-pid ja muut prosessit listassa.
    try std.testing.expect(ps.listingContainsPid(listing, 1));
    try std.testing.expect(ps.listingContainsPid(listing, 2));
    try std.testing.expect(ps.listingContainsPid(listing, 3));
    // Otsikkorivi.
    try std.testing.expect(std.mem.indexOf(u8, listing, "PID") != null);
}
