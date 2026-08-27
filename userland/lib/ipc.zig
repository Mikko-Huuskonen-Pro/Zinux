//! Userland IPC-kirjasto — sys_ipc_send / sys_ipc_recv wrapperit.
//!
//! **Vastuu**: Lähetä/vastaanota viestejä capability-slotin kautta ring 3:ssa.
//! **Riippuvuudet**: `ipc_core.zig`
//! **Käytetään**: `userland/ipc_test/main.zig`, tulevat userland-prosessit

// Tuo IPC-ydin — pituusrajat ja virheiden tulkinta.
const core = @import("ipc_core");

// Syscall-numero: sys_ipc_send(slot, buf, len).
pub const SYS_ipc_send: u64 = 4;
// Syscall-numero: sys_ipc_recv(slot, buf, len).
pub const SYS_ipc_recv: u64 = 5;
// Uudelleenexportoi max-viestikoko.
pub const MAX_MSG_SIZE = core.MAX_MSG_SIZE;

// IPC-kirjaston virheet — negatiiviset syscall-palut muunnetaan näiksi.
pub const IpcError = error{
    // Capability-slotti tai portti virheellinen.
    BadSlot,
    // Jono tyhjä tai täynnä (EAGAIN).
    WouldBlock,
    // Liian suuri viesti tai huono argumentti.
    InvalidArg,
};

// Muunna negatiivinen syscall-paluuarvo IpcError:ksi.
fn mapSyscallError(ret: i64) IpcError {
    // switch tunnetuille virhekoodeille.
    return switch (ret) {
        // EBADF → BadSlot.
        core.EBADF => error.BadSlot,
        // EAGAIN → WouldBlock.
        core.EAGAIN => error.WouldBlock,
        // EINVAL → InvalidArg.
        core.EINVAL => error.InvalidArg,
        // Muu negatiivinen → InvalidArg.
        else => error.InvalidArg,
    };
}

// Alin tason sys_ipc_send — palauttaa raakan i64-paluuarvon.
fn sysIpcSend(slot: u32, buf: [*]const u8, len: u64) i64 {
    // SYSCALL: RAX=num, RDI=slot, RSI=buf, RDX=len.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_ipc_send),
          [slot] "{rdi}" (@as(u64, slot)),
          [buf] "{rsi}" (@intFromPtr(buf)),
          [len] "{rdx}" (len),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Alin tason sys_ipc_recv — palauttaa raakan i64-paluuarvon.
fn sysIpcRecv(slot: u32, buf: [*]u8, len: u64) i64 {
    // SYSCALL: RAX=num, RDI=slot, RSI=buf, RDX=len.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_ipc_recv),
          [slot] "{rdi}" (@as(u64, slot)),
          [buf] "{rsi}" (@intFromPtr(buf)),
          [len] "{rdx}" (len),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Lähetä viesti capability-slotin kautta — palauttaa lähetettyjen tavujen määrä.
pub fn send(slot: u32, payload: []const u8) IpcError!usize {
    // Tarkista pituus ennen syscallia.
    if (!core.validSendLen(payload.len)) return error.InvalidArg;
    // Kutsu kerneliä.
    const ret = sysIpcSend(slot, payload.ptr, @intCast(payload.len));
    // Negatiivinen → virhe.
    if (core.isError(ret)) return mapSyscallError(ret);
    // Palauta lähetettyjen tavujen määrä.
    return @intCast(ret);
}

// Vastaanota viesti capability-slotin kautta — palauttaa viestin pituuden.
pub fn recv(slot: u32, buf: []u8) IpcError!usize {
    // Tyhjä puskuri hylätään.
    if (!core.validRecvBufLen(buf.len)) return error.InvalidArg;
    // Kutsu kerneliä.
    const ret = sysIpcRecv(slot, buf.ptr, @intCast(buf.len));
    // Negatiivinen → virhe.
    if (core.isError(ret)) return mapSyscallError(ret);
    // Palauta vastaanotettujen tavujen määrä.
    return @intCast(ret);
}
