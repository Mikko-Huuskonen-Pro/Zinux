//! Syscall-apu — freestanding shell käyttää näitä kernel-kutsuihin.
//!
//! **Vastuu**: sys_write, sys_read, sys_meminfo, sys_ps, sys_test_return wrapperit.
//! **Riippuvuudet**: ei (numerot kopioitu zinuxabi:sta)
//! **Käytetään**: `commands/*.zig`, `main.zig`

// Syscall-numero: sys_write(fd, buf, len).
pub const SYS_write: u64 = 1;
// Syscall-numero: sys_read(fd, buf, len).
pub const SYS_read: u64 = 11;
// Syscall-numero: sys_meminfo(buf, len) → kirjoitetut tavut.
pub const SYS_meminfo: u64 = 12;
// Syscall-numero: sys_ps(buf, len) → kirjoitetut tavut.
pub const SYS_ps: u64 = 13;
// Syscall-numero: sys_test_return — palaa kernel boot-jatkoon.
pub const SYS_test_return: u64 = 10;

// Kirjoita tavuja fd:hen — palauttaa kirjoitettujen määrän tai neg. virhe.
pub fn sysWrite(fd: u64, buf: [*]const u8, len: u64) i64 {
    // SYSCALL: RAX=num, RDI=fd, RSI=buf, RDX=len.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_write),
          [fd] "{rdi}" (fd),
          [buf] "{rsi}" (@intFromPtr(buf)),
          [len] "{rdx}" (len),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Lue tavuja fd:stä — palauttaa luettujen määrän tai neg. virhe.
pub fn sysRead(fd: u64, buf: [*]u8, len: u64) i64 {
    // SYSCALL: RAX=num, RDI=fd, RSI=buf, RDX=len.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_read),
          [fd] "{rdi}" (fd),
          [buf] "{rsi}" (@intFromPtr(buf)),
          [len] "{rdx}" (len),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Hae muistitiedot kernelistä käyttäjän puskuriin.
pub fn sysMeminfo(buf: [*]u8, len: u64) i64 {
    // SYSCALL: RAX=num, RDI=buf, RSI=len.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_meminfo),
          [buf] "{rdi}" (@intFromPtr(buf)),
          [len] "{rsi}" (len),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Hae prosessilista kernelistä käyttäjän puskuriin.
pub fn sysPs(buf: [*]u8, len: u64) i64 {
    // SYSCALL: RAX=num, RDI=buf, RSI=len.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_ps),
          [buf] "{rdi}" (@intFromPtr(buf)),
          [len] "{rsi}" (len),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Palaa kerneliin boot-testin jatkoon (ei paluuta user-tilaan).
pub fn sysTestReturn() noreturn {
    // SYS_test_return ilman argumentteja.
    asm volatile ("syscall"
        :
        : [num] "{rax}" (SYS_test_return),
          [a1] "{rdi}" (@as(u64, 0)),
        : .{ .rcx = true, .r11 = true });
    // Ei saavuteta.
    unreachable;
}

// Tulosta merkkijono stdout:iin (fd 1 = UART).
pub fn print(msg: []const u8) void {
    // Kutsu sys_write ja ohita paluu.
    _ = sysWrite(1, msg.ptr, msg.len);
}

// Tulosta puskurin [0..len) stdout:iin.
pub fn printBuf(buf: [*]const u8, len: usize) void {
    // Kutsu sys_write annetulla pituudella.
    _ = sysWrite(1, buf, @intCast(len));
}

// Vertaa riviä (ilman newline) annettuun komentoon.
pub fn lineEquals(line: []const u8, cmd: []const u8) bool {
    // Poista mahdollinen rivinvaihto lopusta.
    var len = line.len;
    // Jos viimeinen merkki on '\n', lyhennä vertailua.
    if (len > 0 and line[len - 1] == '\n') len -= 1;
    // Pituuksien on täsmättävä.
    if (len != cmd.len) return false;
    // Vertaa tavu kerrallaan.
    var i: usize = 0;
    // Käy jokainen merkki.
    while (i < len) : (i += 1) {
        // Ero → ei täsmää.
        if (line[i] != cmd[i]) return false;
    }
    // Kaikki merkit täsmäsivät.
    return true;
}
