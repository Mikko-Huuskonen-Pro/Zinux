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
// Syscall-numero: sys_ipc_send(slot, buf, len) → lähetetyt tavut tai neg. virhe.
pub const SYS_ipc_send: u64 = 4;
// Syscall-numero: sys_ipc_recv(slot, buf, len) → vastaanotetut tavut tai neg. virhe.
pub const SYS_ipc_recv: u64 = 5;
// Syscall-numero: sys_cap_delegate(slot, rights_mask) → uusi slot tai neg. virhe.
pub const SYS_cap_delegate: u64 = 6;
// Syscall-numero: sys_cap_create(type, rights_mask) → uusi slot tai neg. virhe.
pub const SYS_cap_create: u64 = 7;
// Syscall-numero: sys_read(fd, buf, len) → luettujen tavujen määrä.
pub const SYS_read: u64 = 11;
// Syscall-numero: sys_meminfo(buf, len) → kirjoitetut tavut.
pub const SYS_meminfo: u64 = 12;
// Syscall-numero: sys_ps(buf, len) → kirjoitetut tavut.
pub const SYS_ps: u64 = 13;
// Syscall-numero: sys_test_return — palaa kernel boot-testiin (vain kehitys).
pub const SYS_test_return: u64 = 10;

// Virhekoodit (negatiiviset paluuarvot, Linux-yhteensopiva tyyli).
pub const EPERM: i64 = -1;
pub const EAGAIN: i64 = -11;
pub const EINVAL: i64 = -22;
pub const EBADF: i64 = -9;
pub const ENOSYS: i64 = -38;
