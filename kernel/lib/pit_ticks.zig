//! PIT IRQ -tick-laskuri — jaettu IRQ-käsittelijän ja schedulerin välillä.
//!
//! **Vastuu**: Tick-laskuri ja milestone-logi bootissa.
//! **Riippuvuudet**: `../lib/log.zig`
//! **Käytetään**: `arch/x86_64/timer_irq.S`, `sched/scheduler.zig`, `main.zig`

// Tuo lokitus milestone-viestiin (kerran bootissa).
const log = @import("log.zig");

// Montako tickiä ennen vahvistuslogia (~0,5 s @ 100 Hz idle-silmukassa).
// Montako tickiä ennen vahvistuslogia (ensimmäinen IRQ vahvistaa PIT-polun).
pub const MILESTONE: u64 = 1;

// PIT-tickien kokonaislaskuri.
pub export var tick_count: u64 = 0;
// Milestone jo logattu — estää toistuvan viestin.
var milestone_logged: bool = false;

// Timer IRQ C-puoli — kutsutaan timer_irq.S:stä (pinon tasaus kunnossa).
export fn timerOnIrqC() callconv(.c) void {
    // Kasvata tick-laskuria.
    tick_count += 1;
    // Loggaa kerran kun MILESTONE saavutettu.
    if (!milestone_logged and tick_count >= MILESTONE) {
        // Merkitse logattu.
        milestone_logged = true;
        // Vahvista Vaihe 3 timer tick boot-logissa.
        log.info("Phase 3 timer ticks OK");
    }
}

// Onko milestone saavutettu (diagnostiikka).
pub fn isReady() bool {
    // Muistiesto — näe IRQ-päivitykset.
    asm volatile ("" ::: .{ .memory = true });
    // Palauta milestone-lippu.
    return milestone_logged;
}

// Palauta nykyinen tick-laskuri.
pub fn count() u64 {
    // Muistiesto — näe IRQ-käsittelijän inc-operaatiot.
    asm volatile ("" ::: .{ .memory = true });
    // Palauta laskuri.
    return tick_count;
}
