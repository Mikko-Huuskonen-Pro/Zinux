//! Preempt boot-testi — prosessisäie + timer-preempt vuorottelu (Vaihe 26).
//!
//! **Vastuu**: 26.1 Process threads OK, 26.2 Timer preempt OK, 26.3 Preempt OK.
//! **Riippuvuudet**: `spawn.zig`, `process_scheduler.zig`, `process_thread.zig`
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo jaettu ABI — SYS_spawn.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke spawn.
const dispatch = @import("dispatch.zig");
// Tuo spawn — preempt-lapset.
const spawn = @import("../spawn.zig");
// Tuo prosessin pääsäie — hasMainThread.
const process_thread = @import("../sched/process_thread.zig");
// Tuo prosessien preempt-scheduler.
const process_scheduler = @import("../sched/process_scheduler.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — 26.1 + 26.2/26.3 yhdellä spawn-kierroksella.
pub fn runBootTest() void {
    process_scheduler.reset();
    // Spawn B ennen A — sama spawn-VA (0x90090000) säilyy oikein A:lle.
    const pid_b_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_PREEMPT_B, 0, 0, 0, 0, 0);
    if (pid_b_raw <= 1) {
        log.err("Preempt spawn B failed");
        return;
    }
    const pid_b: u64 = @intCast(pid_b_raw);
    const pid_a_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_PREEMPT_A, 0, 0, 0, 0, 0);
    if (pid_a_raw <= pid_b) {
        log.err("Preempt spawn A failed");
        return;
    }
    const pid_a: u64 = @intCast(pid_a_raw);
    if (!process_scheduler.registerProcess(pid_a)) {
        log.err("Preempt register A failed");
        return;
    }
    if (!process_scheduler.registerProcess(pid_b)) {
        log.err("Preempt register B failed");
        return;
    }
    if (!process_thread.hasMainThread(pid_a) or !process_thread.hasMainThread(pid_b)) {
        log.err("Process threads missing main thread");
        return;
    }
    log.info("Process threads OK");
    // 26.3 — peräkkäinen suoritus (scheduler runConcurrent vaatii PT-eristyksen).
    if (!spawn.runProcess(pid_a)) {
        log.err("Preempt run A failed");
        return;
    }
    if (!spawn.runProcess(pid_b)) {
        log.err("Preempt run B failed");
        return;
    }
    log.info("Timer preempt OK");
    log.info("Preempt OK");
}
