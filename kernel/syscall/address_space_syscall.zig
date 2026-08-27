//! Address space boot-testi — CR3 per pid + sama VA eri prosesseissa (Vaihe 25).
//!
//! **Vastuu**: Varmista erilliset page tablet ja ELF-kartoitus per prosessi.
//! **Riippuvuudet**: `spawn.zig`, `process_core`, `dispatch.zig`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo jaettu ABI — SYS_spawn.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke spawn.
const dispatch = @import("dispatch.zig");
// Tuo spawn — address space -lapset ja runProcess.
const spawn = @import("../spawn.zig");
// Tuo prosessitaulukko — page_table per pid.
const process = @import("process_core");
// Tuo VMM — kernel PML4 vertailuun.
const vmm = @import("../mm/vmm.zig");
// Tuo paging — getCr3 kun prosessi ajossa.
const paging = @import("../arch/x86_64/paging.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi 25.1 — spawnattujen prosessien PML4 erillään.
fn runPageTablePerPidTest() void {
    // Spawn address space A.
    const pid_a_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_ASPACE_A, 0, 0, 0, 0, 0);
    if (pid_a_raw <= 1) {
        // Spawn A epäonnistui.
        log.err("Page table spawn A failed");
        // Lopeta alitesti.
        return;
    }
    const pid_a: u64 = @intCast(pid_a_raw);
    // Spawn address space B.
    const pid_b_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_ASPACE_B, 0, 0, 0, 0, 0);
    if (pid_b_raw <= pid_a) {
        // Spawn B epäonnistui tai sama pid.
        log.err("Page table spawn B failed");
        // Lopeta alitesti.
        return;
    }
    const pid_b: u64 = @intCast(pid_b_raw);
    // Hae prosessien PML4 osoitteet.
    const pt_a = process.getPageTable(pid_a) orelse {
        log.err("Page table pid A missing");
        return;
    };
    const pt_b = process.getPageTable(pid_b) orelse {
        log.err("Page table pid B missing");
        return;
    };
    // Molemmilla pitää olla oma sivutaulu (ei 0, ei kernel).
    if (pt_a == 0 or pt_b == 0) {
        log.err("Page table zero");
        return;
    }
    if (pt_a == vmm.pml4Phys() or pt_b == vmm.pml4Phys()) {
        log.err("Page table equals kernel");
        return;
    }
    // Eri prosessit → eri PML4-kehykset.
    if (pt_a == pt_b) {
        log.err("Page table not isolated");
        return;
    }
    // Molemmat ladattu samaan virtuaaliosoitteeseen.
    const info_a = process.getLoadedInfo(pid_a) orelse {
        log.err("Page table loaded A missing");
        return;
    };
    const info_b = process.getLoadedInfo(pid_b) orelse {
        log.err("Page table loaded B missing");
        return;
    };
    if (info_a.entry != spawn.ADDRESS_SPACE_LOAD_VADDR or info_b.entry != spawn.ADDRESS_SPACE_LOAD_VADDR) {
        log.err("Page table entry VA wrong");
        return;
    }
    // 25.1 OK.
    log.info("Page table per pid OK");
}

// Boot-testi 25.2/25.3 — aja molemmat prosessit samalla VA:lla eri CR3:llä.
fn runAddressSpaceIsolationTest() void {
    // Spawn uudet prosessit (erilliset pidevaihtoehdot edellisestä alitestistä).
    const pid_a_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_ASPACE_A, 0, 0, 0, 0, 0);
    if (pid_a_raw <= 1) {
        log.err("Address space spawn A failed");
        return;
    }
    const pid_a: u64 = @intCast(pid_a_raw);
    const pid_b_raw = dispatch.invoke(abi.SYS_spawn, spawn.SPAWN_ID_ASPACE_B, 0, 0, 0, 0, 0);
    if (pid_b_raw <= pid_a) {
        log.err("Address space spawn B failed");
        return;
    }
    const pid_b: u64 = @intCast(pid_b_raw);
    // Suorita A ring 3:ssa — tulostaa "asa\n".
    if (!spawn.runProcess(pid_a)) {
        log.err("Address space run A failed");
        return;
    }
    // CR3 pitää palautua kerneliin runProcess jälkeen.
    if (paging.getCr3() != vmm.pml4Phys()) {
        log.err("Address space CR3 not restored after A");
        return;
    }
    // Suorita B samalla entry-VA:lla — tulostaa "asb\n".
    if (!spawn.runProcess(pid_b)) {
        log.err("Address space run B failed");
        return;
    }
    if (paging.getCr3() != vmm.pml4Phys()) {
        log.err("Address space CR3 not restored after B");
        return;
    }
    // 25.3 OK — molemmat ajettu erillisissä osoiteavaruuksissa.
    log.info("Address space OK");
}

// Boot-testi — aja Vaihe 25 alitestit.
pub fn runBootTest() void {
    // 25.1 — erilliset page tablet per spawnattu prosessi.
    runPageTablePerPidTest();
    // 25.2/25.3 — sama VA, eri CR3, peräkkäinen suoritus.
    runAddressSpaceIsolationTest();
}
