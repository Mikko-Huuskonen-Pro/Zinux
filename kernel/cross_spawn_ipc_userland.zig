//! Cross-spawn IPC userland boot-testi — parent spawn + transfer + child recv (Vaihe 27.3).
//!
//! **Vastuu**: Parent ring 3:ssa ilman kernel-orchestraatiota, lapsi runProcess:llä.
//! **Riippuvuudet**: `loader/elf.zig`, `spawn.zig`, `usermode.zig`, `process_core`
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry tietyllä pid:llä.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo spawn — runProcess lapselle parentin sys_spawn:in jälkeen.
const spawn = @import("spawn.zig");
// Tuo prosessitaulukko — parent/child etsintä.
const process = @import("process_core");
// Tuo VMM — varmista kernel CR3 ennen ring 3 -hyppyä.
const vmm = @import("mm/vmm.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu cross-spawn IPC parent -ELF — build.zig kopioi ennen kernel-käännöstä.
const cross_spawn_ipc_test_elf = @embedFile("loader/cross_spawn_ipc_test_prog.bin");

// Cross-spawn parent -testin pinon heap-slot (slot 120 — sama kuin spawn_cap, eri ajankohta).
const CROSS_SPAWN_PARENT_STACK_SLOT: u64 = 120;

// Etsi parentin spawnattu ladattu lapsi prosessitaulukosta.
fn findSpawnedChild(parent_pid: u64) ?u64 {
    // Käy kaikki rekisteröidyt prosessit.
    var i: usize = 0;
    while (i < process.processCount()) : (i += 1) {
        // Hae pid indeksistä.
        const pid = process.pidAt(i) orelse continue;
        // Ohita jos ei parentin lapsi.
        const pp = process.parentPid(pid) orelse continue;
        // Täsmää parent ja varmista ELF ladattu.
        if (pp == parent_pid and process.isLoaded(pid)) return pid;
    }
    // Lapsia ei löytynyt.
    return null;
}

// Boot-testi — parent ring 3 spawn+transfer+send, lapsi recv.
pub fn runBootTest() void {
    // Parent-prosessi — spawnaa lapsen userlandista.
    const parent_pid = process.allocNextPid() orelse {
        // Prosessitaulukko täynnä.
        log.err("Userland cross spawn IPC alloc parent failed");
        // Lopeta testi.
        return;
    };
    // Lataa cross_spawn_ipc_test parent -ELF.
    const loaded = elf.loadElfWithStack(cross_spawn_ipc_test_elf, CROSS_SPAWN_PARENT_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland cross spawn IPC ELF load failed");
        // Lopeta testi.
        return;
    };
    // Varmista kernelin osoiteavaruus ennen parent-ajoa.
    vmm.switchToKernel();
    // Suorita parent ring 3:ssa — spawn, transfer, send, sys_test_return.
    usermode.enterUserAs(loaded.entry, loaded.stack_top, parent_pid);
    // Etsi parentin spawnattu lapsi.
    const child_pid = findSpawnedChild(parent_pid) orelse {
        // Lapsi puuttuu — spawn epäonnistui userlandissa.
        log.err("Userland cross spawn IPC child not found");
        // Lopeta testi.
        return;
    };
    // Suorita lapsi ring 3:ssa — vastaanottaa ja tulostaa OK.
    if (!spawn.runProcess(child_pid)) {
        // runProcess epäonnistui.
        log.err("Userland cross spawn IPC run child failed");
        // Lopeta testi.
        return;
    }
    // Vaihe 27.2 userland-viesti näkyy serialissa — kernel yhteenveto.
    log.info("Userland cross spawn IPC test OK");
    // Palauta boot-prosessin konteksti.
    _ = process.setCurrentPid(process.BOOT_PID);
}
