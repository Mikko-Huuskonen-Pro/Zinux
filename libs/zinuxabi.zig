//! Zinux käyttäjätilan ↔ kernel ABI — jaettu syscall-numerot.
//!
//! **Vastuu**: Vakiot kernelin ja userlandin välillä.
//! **Riippuvuudet**: ei
//! **Käytetään**: `kernel/syscall/dispatch.zig`, userland (myöhemmin)

// Syscall-numero: sys_write(fd, buf, len) → kirjoitetut tavut tai neg. virhe.
pub const SYS_write: u64 = 1;
// Syscall-numero: sys_exit(status) → ei paluuta.
pub const SYS_exit: u64 = 2;
// Syscall-numero: sys_getpid() → prosessitunniste (stub 1).
pub const SYS_getpid: u64 = 3;

// Virhekoodit (negatiiviset paluuarvot, Linux-yhteensopiva tyyli).
pub const EINVAL: i64 = -22;
pub const EBADF: i64 = -9;
pub const ENOSYS: i64 = -38;
