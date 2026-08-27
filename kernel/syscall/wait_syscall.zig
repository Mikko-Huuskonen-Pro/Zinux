//! Exit/wait boot-testi — sys_exit + sys_wait spawn-lapsella (Vaihe 24).
//!
//! **Vastuu**: Prosessin tila, exit-syscall ring 3:sta, wait-syscall, spawn→exit→wait.
//! **Riippuvuudet**: `dispatch.zig`, `spawn.zig`, `wait_syscall_core.zig`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() ja runProcess-polku.
const dispatch = @import("dispatch.zig");
// Tuo spawn — embedded exit-lapsi ja runProcess.
const spawn = @import("../spawn.zig");
// Tuo ring 3 — activeRing3Pid diagnostiikkaan.
const usermode = @import("../arch/x86_64/usermode.zig");
// Tuo prosessitaulukko — tila ja parent_pid.
const process = @import("process_core");
// Tuo wait-ydin — tryWaitChild vahvistukseen.
const wait_core = @import("wait_syscall_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Callback wait_core:lle — onko prosessi olemassa.
fn existsCb(pid: u64) bool {
    // Delegoi process_core.exists.
    return process.exists(pid);
}

// Callback wait_core:lle — vanhemman pid.
fn parentOfCb(pid: u64) ?u64 {
    // Delegoi process_core.parentPid.
    return process.parentPid(pid);
}

// Callback wait_core:lle — onko zombie.
fn isZombieCb(pid: u64) bool {
    // Delegoi process_core.isZombie.
    return process.isZombie(pid);
}

// Callback wait_core:lle — exit-koodi.
fn exitCodeCb(pid: u64) ?u32 {
    // Delegoi process_core.exitCode.
    return process.exitCode(pid);
}

// Boot-testi 24.1 — running/zombie-tila prosessitaulukossa.
fn runProcessStateTest() void {
    // Puhdas tila testiin (boot pid 1 jo rekisteröity).
    // Boot-prosessi on running.
    const boot_state = process.getState(process.BOOT_PID) orelse {
        // Boot-prosessi puuttuu.
        log.err("Process state boot missing");
        // Lopeta alitesti.
        return;
    };
    if (boot_state != .running) {
        // Boot ei saa olla zombie alussa.
        log.err("Process state boot not running");
        // Lopeta alitesti.
        return;
    }
    // Allokoi lapsi vanhemmalle boot:lle.
    const child = process.allocNextPid() orelse {
        // Taulukko täynnä.
        log.err("Process state alloc child failed");
        // Lopeta alitesti.
        return;
    };
    // Aseta parent boot-prosessiksi.
    if (!process.setParentPid(child, process.BOOT_PID)) {
        // setParentPid epäonnistui.
        log.err("Process state set parent failed");
        // Lopeta alitesti.
        return;
    }
    // Merkitse lapsi zombieksi exit-koodilla 7.
    if (!process.markZombie(child, 7)) {
        // markZombie epäonnistui.
        log.err("Process state mark zombie failed");
        // Lopeta alitesti.
        return;
    }
    // Lapsen tila pitää olla zombie.
    if (!process.isZombie(child)) {
        // Tila ei päivittynyt.
        log.err("Process state child not zombie");
        // Lopeta alitesti.
        return;
    }
    // Exit-koodi tallessa.
    const code = process.exitCode(child) orelse {
        // exitCode puuttuu zombielta.
        log.err("Process state exit code missing");
        // Lopeta alitesti.
        return;
    };
    if (code != 7) {
        // Väärä exit-koodi.
        log.err("Process state exit code wrong");
        // Lopeta alitesti.
        return;
    }
    // 24.1 OK.
    log.info("Process state OK");
}

// Boot-testi 24.2 — spawn exit-lapsi ring 3:ssa sys_exit(42).
fn runExitSyscallTest() void {
    // Spawn exit-lapsi embedded-id:llä 2.
    const child_pid_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_EXIT, 0, 0, 0, 0, 0);
    // Varmista positiivinen pid.
    if (child_pid_raw <= 1) {
        // Spawn epäonnistui.
        log.err("Exit syscall spawn failed");
        // Lopeta alitesti.
        return;
    }
    // Spawn palauttaa uuden prosessin tunnisteen u64:na.
    const child_pid: u64 = @intCast(child_pid_raw);
    // Lapsen parent pitää olla boot (current pid 1 spawn-kutsussa).
    const parent = process.parentPid(child_pid) orelse {
        // parent_pid puuttuu.
        log.err("Exit syscall parent missing");
        // Lopeta alitesti.
        return;
    };
    if (parent != process.BOOT_PID) {
        // spawnEmbedded ei asettanut parentia.
        log.err("Exit syscall parent wrong");
        // Lopeta alitesti.
        return;
    }
    // Varmista ladattu entry — exit-ELF @ 0xFFFFFFFF9008F000.
    const loaded = process.getLoadedInfo(child_pid) orelse {
        // Prosessia ei ladattu spawnissa.
        log.err("Exit syscall not loaded");
        // Lopeta alitesti.
        return;
    };
    if (loaded.entry != 0xFFFFFFFF9008F000) {
        // Väärä ELF ladattu tai entry ei täsmää.
        log.err("Exit syscall wrong entry");
        // Lopeta alitesti.
        return;
    }
    // Suorita lapsi ring 3:ssa — kutsuu sys_exit(42).
    if (!spawn.runProcess(child_pid)) {
        // runProcess epäonnistui.
        log.err("Exit syscall run child failed");
        // Lopeta alitesti.
        return;
    }
    // Käytä ring 3:ssa suoritetun prosessin pid:tä (sys_exit merkitsi tämän).
    const exited_pid = usermode.activeRing3Pid();
    // Lapsen pitää olla zombie sys_exit:n jälkeen.
    if (!process.isZombie(exited_pid)) {
        // sys_exit ei merkinnyt zombieksi.
        log.err("Exit syscall child not zombie");
        // Lopeta alitesti.
        return;
    }
    // Exit-koodi 42.
    const code = process.exitCode(exited_pid) orelse {
        // exit-koodi puuttuu.
        log.err("Exit syscall exit code missing");
        // Lopeta alitesti.
        return;
    };
    if (code != 42) {
        // Väärä status ring 3 exit:stä.
        log.err("Exit syscall exit code wrong");
        // Lopeta alitesti.
        return;
    }
    // 24.2 OK.
    log.info("Exit syscall OK");
}

// Boot-testi 24.3 — sys_wait palauttaa zombie-lapsen exit-koodin.
fn runWaitSyscallTest() void {
    // Allokoi uusi lapsi boot-prosessille.
    const child = process.allocNextPid() orelse {
        // allocNextPid epäonnistui.
        log.err("Process wait alloc child failed");
        // Lopeta alitesti.
        return;
    };
    // Aseta vanhempi boot.
    if (!process.setParentPid(child, process.BOOT_PID)) {
        // setParentPid epäonnistui.
        log.err("Process wait set parent failed");
        // Lopeta alitesti.
        return;
    }
    // Merkitse zombie ennen wait-kutsua.
    if (!process.markZombie(child, 99)) {
        // markZombie epäonnistui.
        log.err("Process wait mark zombie failed");
        // Lopeta alitesti.
        return;
    }
    // Nykyinen prosessi boot (vanhempi).
    if (!process.setCurrentPid(process.BOOT_PID)) {
        // setCurrentPid epäonnistui.
        log.err("Process wait set current failed");
        // Lopeta alitesti.
        return;
    }
    // Kutsu sys_wait invoke:lla.
    const ret = dispatch.invoke(abi.SYS_wait, child, 0, 0, 0, 0, 0);
    // Pitää palauttaa exit-koodi 99.
    if (ret != 99) {
        // wait epäonnistui tai väärä koodi.
        log.err("Process wait syscall failed");
        // Lopeta alitesti.
        return;
    }
    // 24.3 OK.
    log.info("Process wait OK");
    // Väärä vanhempi → ECHILD (boot ei ole pid 2:n lapsen vanhempi).
    const pid2 = process.allocNextPid() orelse return;
    const orphan = process.allocNextPid() orelse return;
    if (!process.setParentPid(orphan, pid2)) return;
    if (!process.markZombie(orphan, 1)) return;
    const bad = dispatch.invoke(abi.SYS_wait, orphan, 0, 0, 0, 0, 0);
    if (bad != wait_core.ECHILD) {
        // Boot-prosessi ei saa odottaa toisen vanhemman lasta.
        log.err("Process wait echild failed");
    }
}

// Boot-testi 24.4 — täysi spawn → sys_exit → sys_wait -ketju ring 3:ssa.
fn runSpawnWaitBootTest() void {
    // Spawn uusi exit-lapsi (ei sama kuin 24.2 — uusi pid).
    const child_pid_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_EXIT, 0, 0, 0, 0, 0);
    if (child_pid_raw <= 1) {
        // Spawn epäonnistui.
        log.err("Spawn wait boot spawn failed");
        // Lopeta alitesti.
        return;
    }
    const child_pid: u64 = @intCast(child_pid_raw);
    // Vanhempi boot.
    const parent = process.parentPid(child_pid) orelse {
        log.err("Spawn wait boot parent missing");
        return;
    };
    if (parent != process.BOOT_PID) {
        log.err("Spawn wait boot parent wrong");
        return;
    }
    // Aja lapsi — sys_exit(42) palaa kerneliin.
    if (!spawn.runProcess(child_pid)) {
        log.err("Spawn wait boot run failed");
        return;
    }
    // Ring 3:ssa exitannut prosessi — sys_wait odottaa tätä pid:tä.
    const exited_pid = usermode.activeRing3Pid();
    // Odota lasta invoke-wait:lla.
    const waited = dispatch.invoke(abi.SYS_wait, exited_pid, 0, 0, 0, 0, 0);
    if (waited != 42) {
        // wait ei palauttanut oikeaa exit-koodia.
        log.err("Spawn wait boot wait failed");
        return;
    }
    // Vahvista wait_core-logiikka suoraan.
    const core_ret = wait_core.tryWaitChild(
        process.BOOT_PID,
        exited_pid,
        existsCb,
        parentOfCb,
        isZombieCb,
        exitCodeCb,
    );
    if (core_ret != 42) {
        log.err("Spawn wait boot core failed");
        return;
    }
    // 24.4 OK.
    log.info("Spawn wait boot OK");
}

// Boot-testi — aja kaikki Vaihe 24 alitestit järjestyksessä.
pub fn runBootTest() void {
    // 24.1 — prosessin tila running/zombie.
    runProcessStateTest();
    // 24.2 — sys_exit ring 3:sta.
    runExitSyscallTest();
    // 24.3 — sys_wait invoke.
    runWaitSyscallTest();
    // 24.4 — spawn → exit → wait.
    runSpawnWaitBootTest();
}
