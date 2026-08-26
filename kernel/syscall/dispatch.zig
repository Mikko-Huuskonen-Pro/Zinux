//! Syscall dispatch — numerosta handler-funktioon.
//!
//! **Vastuu**: Syscall-taulukko, sys_write/sys_exit stubit.
//! **Riippuvuudet**: `../../libs/zinuxabi.zig`, UART, log
//! **Käytetään**: `arch/x86_64/syscall_entry.S`, `main.zig`

// Tuo jaettu ABI — syscall-numerot ja virhekoodit.
const abi = @import("zinuxabi");
// Tuo UART sys_write-toteutukseen.
const uart = @import("../drivers/char/uart.zig");
// Tuo lokitus boot-testiin.
const log = @import("../lib/log.zig");
// Tuo usermode — ring 3 paluu boot-testiin.
const usermode = @import("../arch/x86_64/usermode.zig");

// Syscall-käsittelijän funktiotyyppi (6 argumenttia, i64 paluu).
const SyscallFn = *const fn (u64, u64, u64, u64, u64, u64) i64;

// Syscall-kehyksen kuvaus — assembly tallentaa rekisterit ennen C-kutsua.
pub const SyscallFrame = extern struct {
    // Syscall-numero (RAX).
    num: u64,
    // Argumentti 1 (RDI).
    arg1: u64,
    // Argumentti 2 (RSI).
    arg2: u64,
    // Argumentti 3 (RDX).
    arg3: u64,
    // Argumentti 4 (R10).
    arg4: u64,
    // Argumentti 5 (R8).
    arg5: u64,
    // Argumentti 6 (R9).
    arg6: u64,
    // Käyttäjän paluosoite (RCX syscall:in jälkeen).
    user_rip: u64,
    // Käyttäjän RFLAGS (R11 syscall:in jälkeen).
    user_rflags: u64,
};

// sys_write — kirjoita fd:hen (1=stdout UART, 2=stderr UART).
fn sysWrite(a1: u64, a2: u64, a3: u64, _: u64, _: u64, _: u64) i64 {
    // Tiedoston kuvaus (fd).
    const fd = a1;
    // Puskurin osoite (kernel stub: luotetaan osoitteeseen).
    const buf = a2;
    // Kirjoitettavien tavujen määrä.
    const len = a3;
    // Vain stdout/stderr tuettu toistaiseksi.
    if (fd != 1 and fd != 2) return abi.EBADF;
    // Tyhjä kirjoitus on OK.
    if (len == 0) return 0;
    // Osoitin puskuriin tavuina.
    const ptr: [*]const u8 = @ptrFromInt(buf);
    // Kirjoita jokainen tavu UART:iin.
    var i: u64 = 0;
    while (i < len) : (i += 1) {
        // Tulosta yksi merkki serialiin.
        uart.putc(ptr[i]);
    }
    // Palauta kirjoitettujen tavujen määrä.
    return @intCast(len);
}

// sys_read — lue fd:stä (0=stdin UART + injektorirengas).
fn sysRead(a1: u64, a2: u64, a3: u64, _: u64, _: u64, _: u64) i64 {
    // Tiedoston kuvaus (vain stdin tuettu).
    const fd = a1;
    // Puskurin osoite ring 3:ssa.
    const buf = a2;
    // Luettavien tavujen enimmäismäärä.
    const len = a3;
    // Vain stdin (fd 0) tuettu toistaiseksi.
    if (fd != 0) return abi.EBADF;
    // Tyhjä luku on OK.
    if (len == 0) return 0;
    // Osoitin puskuriin tavuina.
    const ptr: [*]u8 = @ptrFromInt(buf);
    // Lue tavuja kunnes puskuri täynnä.
    var i: u64 = 0;
    while (i < len) : (i += 1) {
        // Blokkaava luku rengasjonosta tai UART:ista.
        ptr[i] = uart.readc();
        // Lopeta rivin lopussa (shell-komento valmis).
        if (ptr[i] == '\n') {
            // Palauta luettujen tavujen määrä mukaan lukien newline.
            return @intCast(i + 1);
        }
    }
    // Puskuri täynnä ilman newlinea.
    return @intCast(len);
}

// sys_exit — lopeta prosessi (stub: pysäytä CPU).
fn sysExit(a1: u64, _: u64, _: u64, _: u64, _: u64, _: u64) i64 {
    // Exit-koodi (ei vielä tallenneta).
    _ = a1;
    // Poista keskeytykset ja pysäytä — oikea prosessi-KO myöhemmin.
    asm volatile ("cli; hlt");
    // Ei saavuteta.
    unreachable;
}

// sys_getpid — palauta prosessitunniste (stub aina 1).
fn sysGetpid(_: u64, _: u64, _: u64, _: u64, _: u64, _: u64) i64 {
    // Yksittäinen kernel-prosessi stub.
    return 1;
}

// sys_test_return — palaa kernel boot-testiin ring 3:sta (Vaihe 4.5).
fn sysTestReturn(_: u64, _: u64, _: u64, _: u64, _: u64, _: u64) i64 {
    // Vaihda boot-pinon osoitteeseen ja hyppää runBootTest-jatkoon.
    usermode.returnToKernelTestContinue();
}

// Dispatch-taulukko — indeksi = syscall-numero (max 31).
const handlers: [32]?SyscallFn = blk: {
    // Alusta kaikki merkinnät tyhjiksi.
    var table: [32]?SyscallFn = .{null} ** 32;
    // Rekisteröi sys_write.
    table[@intCast(abi.SYS_write)] = sysWrite;
    // Rekisteröi sys_read.
    table[@intCast(abi.SYS_read)] = sysRead;
    // Rekisteröi sys_exit.
    table[@intCast(abi.SYS_exit)] = sysExit;
    // Rekisteröi sys_getpid.
    table[@intCast(abi.SYS_getpid)] = sysGetpid;
    // Rekisteröi sys_test_return (ring 3 boot-paluu).
    table[@intCast(abi.SYS_test_return)] = sysTestReturn;
    // Palauta valmis taulukko.
    break :blk table;
};

// Suorita yksi syscall kehyksen perusteella (C-puoli entry:stä).
pub export fn syscallDispatchFromFrame(frame: *SyscallFrame) i64 {
    // Hae syscall-numero kehyksestä.
    const num = frame.num;
    // Numero taulukon ulkopuolella → ENOSYS.
    if (num >= handlers.len) return abi.ENOSYS;
    // Hae handler tai null.
    const handler = handlers[@intCast(num)] orelse return abi.ENOSYS;
    // Kutsu handler argumenteilla.
    return handler(frame.arg1, frame.arg2, frame.arg3, frame.arg4, frame.arg5, frame.arg6);
}

// Suorita syscall suoraan (boot-testi ilman ring 3).
pub fn invoke(num: u64, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64, a6: u64) i64 {
    // Numero taulukon ulkopuolella → ENOSYS.
    if (num >= handlers.len) return abi.ENOSYS;
    // Hae handler tai null.
    const handler = handlers[@intCast(num)] orelse return abi.ENOSYS;
    // Kutsu handler suoraan.
    return handler(a1, a2, a3, a4, a5, a6);
}

// Boot-testi — kutsu sys_write suoraan dispatchista.
pub fn runBootTest() void {
    // Testiviesti serialiin.
    const msg = "SY";
    // Kutsu sys_write(1, msg, 2).
    const ret = invoke(abi.SYS_write, 1, @intFromPtr(msg), 2, 0, 0, 0);
    // Varmista että 2 tavua kirjoitettiin.
    if (ret != 2) {
        // Virhe boot-testissä.
        log.err("Syscall write test failed");
        // Lopeta testi.
        return;
    }
    // Vahvista dispatch toimii.
    log.info("Syscall dispatch test OK");
}
