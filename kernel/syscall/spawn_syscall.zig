//! Spawn boot-testi — sys_spawn invoke + kaksi erillistä user-prosessia (Vaihe 21).
//!
//! **Vastuu**: Varmista spawn-syscall ja peräkkäinen suoritus kahdella pid:llä.
//! **Riippuvuudet**: `dispatch.zig`, `spawn.zig`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo jaettu ABI — SYS_spawn.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo spawn-ydin — embedded id:t ja runProcess.
const spawn = @import("../spawn.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — sys_spawn + runProcess kahdelle lapselle.
pub fn runBootTest() void {
    // 21.1 — spawn lapsi A invoke()-kautta (palauttaa uuden pid:n).
    const pid_a = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_CHILD_A, 0, 0, 0, 0, 0);
    // Varmista että pid on positiivinen ja suurempi kuin boot (1).
    if (pid_a <= 1) {
        // Spawn-syscall epäonnistui tai palautti virheen.
        log.err("Spawn syscall child A failed");
        // Lopeta testi.
        return;
    }
    // Varmista getpid ei muuttunut spawn-kutsun jälkeen (kernel konteksti).
    const self_pid = dispatch.invoke(abi.SYS_getpid, 0, 0, 0, 0, 0, 0);
    if (self_pid != 1) {
        // Spawn ei saa vaihtaa kernelin current pid:tä pysyvästi.
        log.err("Spawn syscall changed current pid");
        // Lopeta testi.
        return;
    }
    // Spawn-syscall OK (21.1).
    log.info("Spawn syscall OK");
    // 21.2 — spawn lapsi B toisella embedded-id:llä.
    const pid_b = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_CHILD_B, 0, 0, 0, 0, 0);
    // Varmista eri pid kuin lapsi A.
    if (pid_b <= pid_a) {
        // Toinen spawn epäonnistui tai sama pid.
        log.err("Spawn syscall child B failed");
        // Lopeta testi.
        return;
    }
    // Suorita lapsi A ring 3:ssa — tulostaa "spa\n" serialiin.
    if (!spawn.runProcess(@intCast(pid_a))) {
        // Ladattua prosessia ei löydy tai enterUser epäonnistui.
        log.err("Spawn run process A failed");
        // Lopeta testi.
        return;
    }
    // Suorita lapsi B ring 3:ssa — tulostaa "spb\n" serialiin.
    if (!spawn.runProcess(@intCast(pid_b))) {
        // Ladattua prosessia ei löydy tai enterUser epäonnistui.
        log.err("Spawn run process B failed");
        // Lopeta testi.
        return;
    }
    // Molemmat prosessit suoritettu erillisillä pinokartoituksilla (21.2).
    log.info("Two processes boot OK");
}
