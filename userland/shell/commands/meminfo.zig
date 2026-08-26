//! meminfo-komento — kernelin PMM/heap-tiedot syscallilla.
//!
//! **Vastuu**: sys_meminfo → stdout.
//! **Riippuvuudet**: `../syscall.zig`
//! **Käytetään**: `dispatch.zig`

// Tuo syscall-apu.
const sc = @import("../syscall.zig");

// Tulostuspuskuri meminfo-tekstille (kernel täyttää).
var out_buf: [128]u8 = undefined;

// Suorita meminfo-komento — kysy kerneliltä ja tulosta.
pub fn run() void {
    // Kysy kerneliltä muistitiedot puskuriin.
    const n = sc.sysMeminfo(&out_buf, out_buf.len);
    // Jos syscall onnistui, tulosta puskuri.
    if (n > 0) {
        // Tulosta kernelin muotoilema teksti.
        sc.printBuf(&out_buf, @intCast(@min(n, @as(i64, out_buf.len))));
    }
}
