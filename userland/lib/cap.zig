//! Userland capability-kirjasto — sys_cap_delegate wrapper.
//!
//! **Vastuu**: Delegoi osa oikeuksista uuteen slottiin ring 3:ssa.
//! **Riippuvuudet**: `cap_core.zig`
//! **Käytetään**: `userland/cap_test/main.zig`

// Tuo capability-ydin — maskit ja virhekoodeja.
const core = @import("cap_core");

// Syscall-numero: sys_cap_delegate(slot, rights_mask).
pub const SYS_cap_delegate: u64 = 6;

// Uudelleenexportoi yleiset oikeusmaskit.
pub const MASK_READ = core.MASK_READ;
// write-maski.
pub const MASK_WRITE = core.MASK_WRITE;
// send-maski.
pub const MASK_SEND = core.MASK_SEND;
// recv-maski.
pub const MASK_RECV = core.MASK_RECV;
// map-maski.
pub const MASK_MAP = core.MASK_MAP;
// grant-maski.
pub const MASK_GRANT = core.MASK_GRANT;

// Capability-tyyppi: IPC-portti.
pub const CAP_TYPE_PORT = core.CAP_TYPE_PORT;

// Syscall-numero: sys_cap_create(type, rights_mask).
pub const SYS_cap_create: u64 = 7;
// Syscall-numero: sys_cap_revoke(slot).
pub const SYS_cap_revoke: u64 = 8;

// Capability-kirjaston virheet.
pub const CapError = error{
    // Virheellinen capability-slotti.
    BadSlot,
    // Ei grant-oikeutta tai liikaa oikeuksia.
    PermissionDenied,
    // Virheellinen rights_mask tai tyyppi.
    InvalidArg,
    // Portti- tai slottitaulukko täynnä.
    NoResources,
};

// Muunna negatiivinen syscall-palu cap-virheeksi.
fn mapSyscallError(ret: i64) CapError {
    // switch tunnetuille virhekoodeille.
    return switch (ret) {
        // EPERM → PermissionDenied.
        core.EPERM => error.PermissionDenied,
        // EBADF → BadSlot.
        core.EBADF => error.BadSlot,
        // EINVAL → InvalidArg.
        core.EINVAL => error.InvalidArg,
        // Muu negatiivinen → NoResources tai InvalidArg.
        else => error.NoResources,
    };
}

// Alin tason sys_cap_create — palauttaa raa'an i64-paluuarvon.
fn sysCapCreate(typ: u32, rights_mask: u32) i64 {
    // SYSCALL: RAX=num, RDI=type, RSI=rights_mask.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_cap_create),
          [typ] "{rdi}" (@as(u64, typ)),
          [mask] "{rsi}" (@as(u64, rights_mask)),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Alin tason sys_cap_revoke — palauttaa raa'an i64-paluuarvon.
fn sysCapRevoke(slot: u32) i64 {
    // SYSCALL: RAX=num, RDI=slot.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_cap_revoke),
          [slot] "{rdi}" (@as(u64, slot)),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Alin tason sys_cap_delegate — palauttaa raa'an i64-paluuarvon.
fn sysCapDelegate(slot: u32, rights_mask: u32) i64 {
    // SYSCALL: RAX=num, RDI=slot, RSI=rights_mask.
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> i64),
        : [num] "{rax}" (SYS_cap_delegate),
          [slot] "{rdi}" (@as(u64, slot)),
          [mask] "{rsi}" (@as(u64, rights_mask)),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

// Delegoi osa oikeuksista uuteen slottiin — palauttaa uuden slot-indeksin.
pub fn delegate(slot: u32, rights_mask: u32) CapError!u32 {
    // Tarkista maski ennen syscallia.
    if (!core.validMask(rights_mask)) return error.InvalidArg;
    // Kutsu kerneliä.
    const ret = sysCapDelegate(slot, rights_mask);
    // Negatiivinen → virhe.
    if (core.isError(ret)) return mapSyscallError(ret);
    // Palauta uuden slotin indeksi.
    return @intCast(ret);
}

// Luo uusi IPC-portti capability — palauttaa uuden slot-indeksin.
pub fn createPort(rights_mask: u32) CapError!u32 {
    // Tarkista maski ennen syscallia.
    if (!core.validMask(rights_mask)) return error.InvalidArg;
    // Kutsu kerneliä — luo portti-tyyppinen capability.
    const ret = sysCapCreate(CAP_TYPE_PORT, rights_mask);
    // Negatiivinen → virhe.
    if (core.isError(ret)) return mapSyscallError(ret);
    // Palauta uuden slotin indeksi.
    return @intCast(ret);
}

// Peruuta capability-slotti — mitätöi objekti ja kaikki viitteet.
pub fn revoke(slot: u32) CapError!void {
    // Kutsu kerneliä — peruuta slotin taustalla oleva objekti.
    const ret = sysCapRevoke(slot);
    // Negatiivinen → virhe.
    if (core.isError(ret)) return mapSyscallError(ret);
}
