//! x86_64 SYSCALL/SYSRET — MSR-alustus ja kernel pinon hallinta.
//!
//! **Vastuu**: STAR/LSTAR/SFMASK, syscall pinon alue.
//! **Riippuvuudet**: `gdt.zig`, `syscall_entry.S`
//! **Käytetään**: `kernel/main.zig`

// Tuo GDT segmenttivalitsimet STAR MSR:ää varten.
const gdt = @import("gdt.zig");

// IA32_STAR — segmenttivalitsimet SYSCALL/SYSRET:lle.
const MSR_STAR: u32 = 0xC0000081;
// IA32_LSTAR — SYSCALL entry point (RIP).
const MSR_LSTAR: u32 = 0xC0000082;
// IA32_FMASK — RFLAGS mask (SFMASK), tyypillisesti IF pois.
const MSR_FMASK: u32 = 0xC0000084;
// IA32_EFER — extended feature enable (SCE = SYSCALL/SYSRET).
const MSR_EFER: u32 = 0xC0000080;
// EFER.SCE — salli SYSCALL/SYSRET-komennot.
const EFER_SCE: u64 = 1 << 0;

// RFLAGS interrupt flag -bitti (SFMASK tyhjentää tämän SYSCALL:lla).
const RFLAGS_IF: u64 = 1 << 9;

// Syscall entry — assembly (syscall_entry.S), palaa sysretq:lla.
extern fn syscallEntry() callconv(.naked) void;

// Käyttäjän RSP tallennus (syscall entry swap).
pub export var saved_user_rsp: u64 = 0;

// Syscall-kernel pinon alue — 4 KiB riittää C-käsittelijälle.
pub export var syscall_stack: [4096]u8 align(16) linksection(".bss") = undefined;

// Pinon yläreuna (export assemblylle).
pub export var syscall_stack_top: u64 = 0;

// Kirjoita 64-bit MSR (wrmsr).
fn wrmsr(msr: u32, value: u64) void {
    // EDX:EAX = value, ECX = msr.
    const lo: u32 = @truncate(value);
    const hi: u32 = @truncate(value >> 32);
    // Aseta rekisterit ja suorita wrmsr.
    asm volatile (
        \\mov %[msr_val], %%ecx
        \\mov %[lo_val], %%eax
        \\mov %[hi_val], %%edx
        \\wrmsr
        :
        : [msr_val] "r" (msr),
          [lo_val] "r" (lo),
          [hi_val] "r" (hi),
    );
}

// Ota EFER.SCE käyttöön säilyttäen olemassa olevat LME/NXE-bitit.
fn enableEferSce() void {
    // rdmsr → or SCE → wrmsr (ECX=MSR_EFER kiinteä immediate).
    asm volatile (
        \\mov %[msr], %%ecx
        \\rdmsr
        \\or %[sce], %%eax
        \\wrmsr
        :
        : [msr] "i" (MSR_EFER),
          [sce] "i" (@as(u32, @truncate(EFER_SCE))),
    );
}

// Alusta SYSCALL MSRs ja syscall pinon yläreuna.
pub fn init() void {
    // Laske syscall pinon yläreuna.
    syscall_stack_top = @intFromPtr(&syscall_stack) + syscall_stack.len;
    // STAR: SYSRET user CS (ring 3) yläosaan, SYSCALL kernel CS alaosaan.
    const user_cs_sysret: u64 = (@as(u64, gdt.USER_CODE_SEL | 3) << 48);
    // Kernel code selector SYSCALL entrylle (bits 47:32).
    const kernel_cs_syscall: u64 = (@as(u64, gdt.KERNEL_CODE_SEL) << 32);
    // Yhdistä STAR MSR arvo.
    const star: u64 = user_cs_sysret | kernel_cs_syscall;
    // Kirjoita STAR.
    wrmsr(MSR_STAR, star);
    // LSTAR = syscall entry point.
    wrmsr(MSR_LSTAR, @intFromPtr(&syscallEntry));
    // SFMASK — tyhjennä IF syscall entryssä (ei keskeytyksiä handlerissa).
    wrmsr(MSR_FMASK, RFLAGS_IF);
    // EFER.SCE — ota SYSCALL/SYSRET käyttöön (lue-modify-kirjoita turvallisesti).
    enableEferSce();
}

// Palauta syscall entry -osoite (debug).
pub fn entryAddr() u64 {
    // Palauta LSTAR-osoite.
    return @intFromPtr(&syscallEntry);
}
