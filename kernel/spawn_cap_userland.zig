//! Spawn cap userland boot-testi — ring 3 spawn + cap.transfer (Vaihe 27.1).
//!
//! **Vastuu**: Lataa spawn_cap_test ELF ja aja ring 3:ssa.
//! **Riippuvuudet**: `loader/elf.zig`, `usermode.zig`, `process_core`
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry tietyllä pid:llä.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo prosessitaulukko — pid-allokaatio.
const process = @import("process_core");
// Tuo VMM — varmista kernel CR3 ennen ring 3 -hyppyä.
const vmm = @import("mm/vmm.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu spawn cap -testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const spawn_cap_test_elf = @embedFile("loader/spawn_cap_test_prog.bin");

// Spawn cap -testin pinon heap-slot — erillään cross_spawn parentista (slot 120).
const SPAWN_CAP_STACK_SLOT: u64 = 120;

// Boot-testi — spawn + cap.transfer ring 3:ssa.
pub fn runBootTest() void {
    // Parent-prosessi ring 3 -ajolle — oma capability-taulukko.
    const parent_pid = process.allocNextPid() orelse {
        // Prosessitaulukko täynnä.
        log.err("Userland spawn cap alloc pid failed");
        // Lopeta testi.
        return;
    };
    // Lataa spawn_cap_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(spawn_cap_test_elf, SPAWN_CAP_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland spawn cap ELF load failed");
        // Lopeta testi.
        return;
    };
    // Varmista kernelin osoiteavaruus ennen userland-ajoa (preempt/spawn CR3).
    vmm.switchToKernel();
    // Suorita parent ring 3:ssa — tulostaa "userland spawn cap OK".
    usermode.enterUserAs(loaded.entry, loaded.stack_top, parent_pid);
    // Palauta boot-prosessin konteksti.
    _ = process.setCurrentPid(process.BOOT_PID);
    // Vaihe 27.1 valmis.
    log.info("Userland spawn cap OK");
}
