//! Prosessin odotus — sys_wait-ydin (host-testattava).
//!
//! **Vastuu**: Tarkista parent/child-suhde ja zombie-tila, palauta exit-koodi.
//! **Riippuvuudet**: ei
//! **Käytetään**: `dispatch.zig`, `wait_syscall.zig`, host-testit

// Virhe: lapsi ei kuulu odottavalle vanhemmalle (Linux ECHILD).
pub const ECHILD: i64 = -10;
// Virhe: prosessia ei löydy (Linux ESRCH).
pub const ESRCH: i64 = -3;
// Virhe: lapsi ei vielä zombie — odota uudelleen (Linux EAGAIN).
pub const EAGAIN: i64 = -11;

// Yritä odottaa yhtä lasta — palauttaa exit-koodi tai negatiivinen virhe.
pub fn tryWaitChild(
    parent_pid: u64,
    child_pid: u64,
    exists_fn: *const fn (u64) bool,
    parent_of_fn: *const fn (u64) ?u64,
    is_zombie_fn: *const fn (u64) bool,
    exit_code_fn: *const fn (u64) ?u32,
) i64 {
    // Lapsiprosessia ei ole taulukossa.
    if (!exists_fn(child_pid)) return ESRCH;
    // Hae lapsen vanhempi.
    const parent = parent_of_fn(child_pid) orelse return ECHILD;
    // Vain oikea vanhempi saa odottaa.
    if (parent != parent_pid) return ECHILD;
    // Lapsi elää vielä — ei blokata tässä stubissa.
    if (!is_zombie_fn(child_pid)) return EAGAIN;
    // Hae zombie exit-koodi.
    const code = exit_code_fn(child_pid) orelse return EAGAIN;
    // Palauta positiivinen exit status (0..255 tyypillisesti).
    return @intCast(code);
}
