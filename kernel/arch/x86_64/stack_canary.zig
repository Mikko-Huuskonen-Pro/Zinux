//! Kernel-pinon canaryt — maalaus, tarkistus ja rikkomus-käsittelijä.
//!
//! **Vastuu**: Suojaa tunnetut kernel-pinot ylivuodoilta boot-vaiheessa.
//! **Riippuvuudet**: `stack_canary_core.zig`, log, syscall, gdt
//! **Käytetään**: `kernel/main.zig`, `sched/scheduler.zig`

// Tuo ydin — magic ja tarkistuslogiikka.
const core = @import("stack_canary_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../../lib/log.zig");
// Tuo syscall pinon export-symboli.
const syscall = @import("syscall.zig");
// Tuo GDT — TSS ring-0 pinon slice.
const gdt = @import("gdt.zig");

// Early boot -pino — export entry.zig:stä.
extern var early_stack: [16 * 1024]u8 align(16);

// Rekisteröidyt pinot tarkistusta varten (max 8 — riittää boot-vaiheeseen).
var tracked: [8][]const u8 = undefined;
// Montako pinon slicea tracked-taulukossa.
var tracked_len: usize = 0;

// Rekisteröi pino ja maalaa canary alareunaan.
pub fn trackStack(stack: []const u8) void {
    // Maalaa canary heti rekisteröinnin yhteydessä.
    core.paintBottom(stack);
    // Lisää seurantaan jos tilaa.
    if (tracked_len < tracked.len) {
        // Tallenna slice viittaus pinomuistoon.
        tracked[tracked_len] = stack;
        // Kasvata laskuria.
        tracked_len += 1;
    }
}

// Maalaa ja rekisteröi kaikki kernel-pinot jotka ovat jo olemassa bootissa.
pub fn init() void {
    // Nollaa seurantalista.
    tracked_len = 0;
    // Early boot -pino (kmain ja init ennen schedulera).
    trackStack(&early_stack);
    // Syscall-käsittelijän kernel-pino.
    trackStack(&syscall.syscall_stack);
    // TSS rsp0 — ring 3 poikkeusten kernel-pino.
    trackStack(gdt.tssStackSlice());
}

// Tarkista kaikki rekisteröidyt pinot.
pub fn verifyTracked() bool {
    // Delegoi ydinmoduulille.
    return core.verifyAll(tracked[0..tracked_len]);
}

// Kutsutaan kun canary on ylikirjoitettu — pysäytä kernel.
pub fn onViolation() noreturn {
    // Ilmoita serialiin.
    log.err("Stack canary violation");
    // Poista keskeytykset ja pysäytä CPU.
    asm volatile ("cli; hlt");
    // Ei saavuteta.
    unreachable;
}

// Boot-testi — vahvista canaryt maalattu ja ehjiä.
pub fn runBootTest() void {
    // Jokin pino rikki → virhe.
    if (!verifyTracked()) {
        // Pysäytä heti — stack overflow tai bugi.
        onViolation();
    }
    // Kaikki tunnetut pinot ehjiä.
    log.info("Stack canary OK");
}
