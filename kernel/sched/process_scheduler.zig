//! Prosessien timer-preempt scheduler — ring 3 vuorottelu (Vaihe 26).
//!
//! **Vastuu**: Timer IRQ tunnistaa ring 3 -preemptin; useita prosesseja peräkkäin + timer.
//! **Riippuvuudet**: `process_thread.zig`, `usermode.zig`, `vmm.zig`, `gdt.zig`
//! **Käytetään**: `pit_ticks.zig`, `dispatch.zig`, `preempt_syscall.zig`

// Tuo prosessin pääsäie — kontekstit ja tilat.
const thread_mod = @import("process_thread.zig");
// Tuo prosessitaulukko — current pid.
const process = @import("process_core");
// Tuo ring 3 siirtymä — iretq ja boot-paluu.
const usermode = @import("../arch/x86_64/usermode.zig");
// Tuo GDT — user segmenttivalitsimet.
const gdt = @import("../arch/x86_64/gdt.zig");
// Tuo VMM — CR3-vaihto prosessien välillä.
const vmm = @import("../mm/vmm.zig");
// Tuo lokitus milestone-viesteihin.
const log = @import("../lib/log.zig");

// Montako rekisteröityä prosessia preempt-testissä.
const MAX_PREEMPT: usize = 4;

// Rekisteröityjen prosessien pid-jono (scheduler-indeksit).
var pid_list: [MAX_PREEMPT]u64 = undefined;
// Montako prosessia preempt-jonossa.
var pid_count: usize = 0;
// Aktiivisen prosessin indeksi pid_list:ssä.
var current_idx: usize = 0;
// Boot RSP tallennettu ennen ensimmäistä scheduler-iretq:ä.
var boot_rsp_saved: bool = false;
// Preempt-scheduler aktiivinen — timer IRQ tunnistaa ring 3 -preemptin.
var preempt_active: bool = false;
// Timer-preempt milestone jo logattu.
var timer_preempt_logged: bool = false;

// RFLAGS ensimmäiselle iretq:lle — bitti 1 pakollinen; IF=0 kunnes scheduler vahvistettu.
const INITIAL_RFLAGS: u64 = 0x2;

// User segmenttivalitsimet ring 3:een (RPL 3).
const USER_CS: u64 = gdt.USER_CODE_SEL | 3;
const USER_SS: u64 = gdt.USER_DATA_SEL | 3;

// Montako rekisteröityä säiettä (delegoi process_thread).
pub fn registeredThreadCount() usize {
    return thread_mod.threadCount();
}

// Onko preempt-scheduler aktiivinen.
pub fn isActive() bool {
    return preempt_active;
}

// Onko timer-preempt milestone logattu (boot-testi 26.2).
pub fn timerPreemptLogged() bool {
    return timer_preempt_logged;
}

// Nollaa scheduler-tila boot-testien välissä.
pub fn reset() void {
    preempt_active = false;
    timer_preempt_logged = false;
    pid_count = 0;
    current_idx = 0;
    boot_rsp_saved = false;
    thread_mod.initCore();
}

// Rekisteröi prosessi preempt-jonoon — alustaa pääsäie (26.1).
pub fn registerProcess(pid: u64) bool {
    if (pid_count >= MAX_PREEMPT) return false;
    if (!thread_mod.initMainThread(pid)) return false;
    pid_list[pid_count] = pid;
    pid_count += 1;
    return true;
}

// Laske montako prosessia on vielä ajettavissa (ei finished).
fn countRunnable() usize {
    var n: usize = 0;
    var i: usize = 0;
    while (i < pid_count) : (i += 1) {
        const t = thread_mod.threadForPid(pid_list[i]) orelse continue;
        if (t.run_state == .finished) continue;
        n += 1;
    }
    return n;
}

// Etsi seuraava ajettava indeksi round-robin (ohittaa finished).
fn nextRunnableIndex(from: usize) ?usize {
    if (pid_count == 0) return null;
    var step: usize = 0;
    while (step < pid_count) : (step += 1) {
        const idx = (from + 1 + step) % pid_count;
        const t = thread_mod.threadForPid(pid_list[idx]) orelse continue;
        if (t.run_state == .finished) continue;
        return idx;
    }
    return null;
}

// Etsi ensimmäinen ajettava prosessi jonosta.
fn firstRunnableIndex() ?usize {
    var i: usize = 0;
    while (i < pid_count) : (i += 1) {
        const t = thread_mod.threadForPid(pid_list[i]) orelse continue;
        if (t.run_state != .finished) return i;
    }
    return null;
}

// Hae iretq-parametrit säieelle — entry tai tallennettu konteksti.
fn iretqArgs(t: *thread_mod.ProcessThread) struct { rip: u64, rsp: u64, rflags: u64, cs: u64, ss: u64 } {
    if (t.has_saved) {
        return .{
            .rip = t.rip,
            .rsp = t.rsp,
            .rflags = t.rflags,
            .cs = if (t.user_cs != 0) t.user_cs else USER_CS,
            .ss = if (t.user_ss != 0) t.user_ss else USER_SS,
        };
    }
    return .{
        .rip = t.entry,
        .rsp = t.stack_top,
        .rflags = INITIAL_RFLAGS,
        .cs = USER_CS,
        .ss = USER_SS,
    };
}

// Päivitä prosessi aktiiviseksi — CR3 + current pid + ring3 pid.
fn activateProcess(idx: usize) void {
    current_idx = idx;
    const pid = pid_list[idx];
    const t = thread_mod.threadForPid(pid) orelse return;
    _ = thread_mod.markRunning(pid);
    _ = process.setCurrentPid(pid);
    usermode.usermode_ring3_pid = pid;
    vmm.switchToAddressSpace(t.pml4);
}

// Siirry prosessiin indeksillä — palaa sys_test_return → userReturn -ketjussa.
fn switchToIndex(idx: usize) void {
    activateProcess(idx);
    const pid = pid_list[idx];
    const t = thread_mod.threadForPid(pid) orelse return;
    const args = iretqArgs(t);
    if (!boot_rsp_saved) {
        usermode.saveKernelRspOnce();
        boot_rsp_saved = true;
    }
    usermode.enterUserScheduled(args.rip, args.rsp, args.rflags, pid);
}

// Ota preempt käyttöön boot-testiä varten (ennen runConcurrent/switchToIndex).
pub fn armConcurrent() void {
    preempt_active = true;
    usermode.usermode_saved_pid = process.currentPid();
}

// Käynnistä rekisteröidyt prosessit — ensimmäinen switchToIndex (loput userReturn-ketju).
pub fn runConcurrent() void {
    if (pid_count < 2) return;
    armConcurrent();
    const idx = firstRunnableIndex() orelse return;
    switchToIndex(idx);
}

// Ring 3 sys_test_return — merkitse valmis, jatka seuraavaan tai palaa bootiin.
pub fn userReturn() void {
    const pid = usermode.activeRing3Pid();
    _ = thread_mod.markFinished(pid);
    if (nextRunnableIndex(current_idx)) |next_idx| {
        switchToIndex(next_idx);
        unreachable;
    }
    preempt_active = false;
    usermode.returnToKernelTestContinue();
}

// Timer IRQ — logita ring 3 -preempt (26.2).
pub fn onTimerIrq(frame_ptr: *anyopaque) void {
    if (!preempt_active) return;
    if (pid_count < 2) return;
    const frame: [*]u64 = @ptrCast(@alignCast(frame_ptr));
    const cs = frame[16];
    if ((cs & 3) != 3) return;
    if (!timer_preempt_logged) {
        timer_preempt_logged = true;
        log.info("Timer preempt OK");
    }
}
