//! Userland spawn-kirjasto — sys_spawn wrapper ring 3:ssa (Vaihe 21.3).
//!
//! **Vastuu**: Luo uusi prosessi upotetusta ELF-tunnisteesta kernelin kautta.
//! **Riippuvuudet**: ei
//! **Käytetään**: tulevat userland-prosessit (spawn-demo myöhemmin)

// Syscall-numero: sys_spawn(embedded_id) → uusi pid tai neg. virhe.
pub const SYS_spawn: u64 = 20;
// Embedded ELF -tunniste: spawn-lapsi A (kernel/spawn.zig).
pub const SPAWN_ID_CHILD_A: u64 = 0;
// Embedded ELF -tunniste: spawn-lapsi B (kernel/spawn.zig).
pub const SPAWN_ID_CHILD_B: u64 = 1;

// Spawn-kirjaston virheet — negatiiviset syscall-palut.
pub const SpawnError = error{
    // Tuntematon embedded-id tai taulukko täynnä.
    InvalidArg,
    // Muu kernel-virhe.
    Failed,
};

// Muunna negatiivinen syscall-palu SpawnError:ksi.
fn mapSyscallError(ret: i64) SpawnError {
    // EINVAL tuntemattomalle id:lle.
    if (ret == -22) return error.InvalidArg;
    // Muu virhe.
    return error.Failed;
}

// Kutsu sys_spawn suoraan — palauttaa uuden pid:n tai SpawnError.
pub fn spawnEmbedded(id: u64) SpawnError!u64 {
    // SYSCALL: RAX=num, RDI=embedded_id.
    const ret = asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_spawn),
          [id] "{rdi}" (id),
        : .{ .rcx = true, .r11 = true, .memory = true });
    // Negatiivinen paluu → virhe.
    if (ret < 0) return mapSyscallError(ret);
    // Palauta uusi prosessitunniste.
    return @intCast(ret);
}
