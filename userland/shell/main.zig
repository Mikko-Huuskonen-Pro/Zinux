//! Interaktiivinen shell — yksi komento per boot-testi (Vaihe 5.3/5.5).
//!
//! **Vastuu**: Prompt, sys_read, dispatch, sys_test_return.
//! **Riippuvuudet**: `syscall.zig`, `commands/dispatch.zig`
//! **Käytetään**: start.S → shellMain

// Tuo syscall wrapperit.
const sc = @import("syscall.zig");
// Tuo komentodispatch.
const dispatch = @import("commands/dispatch.zig");

// Rivi-puskuri stdin-lukua varten.
var line_buf: [128]u8 = undefined;

// Shell-sisäänkäynti — start.S kutsuu tätä.
export fn shellMain() void {
    // Tulosta interaktiivinen prompt.
    sc.print("zinux> ");
    // Lue yksi komento stdin:stä (kernel injektoi boot-testissä).
    const n = sc.sysRead(0, &line_buf, line_buf.len);
    // Rajaa luettu pituus puskurin kokoon.
    const read_len: usize = if (n <= 0) 0 else @intCast(@min(n, @as(i64, line_buf.len)));
    // Suorita komento jos rivi luettiin.
    if (read_len > 0) {
        // Delegoi help/meminfo/ps dispatchille.
        dispatch.dispatch(line_buf[0..read_len]);
    }
    // Palaa kerneliin — shell.zig jatkaa boot-testiä.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään shellMain (freestanding juuri).
pub export fn shellAnchor() void {}
