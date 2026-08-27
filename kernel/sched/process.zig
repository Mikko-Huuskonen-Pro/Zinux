//! Prosessitaulukko — kernel-alustus ja boot-vahvistus (Vaihe 20).
//!
//! **Vastuu**: Prosessitaulukon init, kaksi prosessia samassa taulukossa, getpid.
//! **Riippuvuudet**: `process_core.zig`, `capability_core.zig`, `dispatch.zig`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo prosessitaulukon ydin.
const core = @import("process_core");
// Tuo capability — slotit per pid.
const cap = @import("../ipc/capability_core.zig");
// Tuo dispatch — sys_getpid invoke boot-testiin.
const dispatch = @import("../syscall/dispatch.zig");
// Tuo jaettu ABI — SYS_getpid.
const abi = @import("zinuxabi");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Alusta prosessitaulukko boot-vaiheessa (capability init kutsuu myös).
pub fn init() void {
    // Delegoi ytimelle — idempotentti jos capability jo alusti.
    core.initCore();
}

// Boot-testi — kaksi prosessia, erilliset slotit, getpid current kontekstissa.
pub fn runBootTest() void {
    // Varmista vähintään boot-prosessi (pid 1).
    if (core.processCount() < 1) {
        // Prosessitaulukko tyhjä — alustus puuttuu.
        log.err("Process table empty");
        // Lopeta testi.
        return;
    }
    // Rekisteröi toinen prosessi (pid 2) — ei vielä ELF-spawnia.
    if (!core.allocProcess(2)) {
        // Toinen prosessi ei mahdu taulukkoon.
        log.err("Process alloc pid 2 failed");
        // Lopeta testi.
        return;
    }
    // Luo objekti prosessille 1.
    const obj1 = cap.createObject(.port, 1, 1001) orelse {
        // Objektin luonti epäonnistui.
        log.err("Process table obj1 failed");
        // Lopeta testi.
        return;
    };
    // Asenna slotti prosessille 1.
    const slot1 = cap.installSlotForPid(1, obj1, .{ .send = true }) orelse {
        // Slotti-asennus epäonnistui.
        log.err("Process table slot1 failed");
        // Lopeta testi.
        return;
    };
    // Luo objekti prosessille 2.
    const obj2 = cap.createObject(.port, 2, 2002) orelse {
        // Objektin luonti epäonnistui.
        log.err("Process table obj2 failed");
        // Lopeta testi.
        return;
    };
    // Asenna slotti prosessille 2.
    const slot2 = cap.installSlotForPid(2, obj2, .{ .recv = true }) orelse {
        // Slotti-asennus epäonnistui.
        log.err("Process table slot2 failed");
        // Lopeta testi.
        return;
    };
    // Prosessi 2 on uusi — ensimmäinen slotti on indeksi 0.
    if (slot2 != 0) {
        // Odotettiin ensimmäistä slottia prosessille 2.
        log.err("Process table pid2 first slot unexpected");
        // Lopeta testi.
        return;
    }
    // Hae slotit prosessikohtaisesti — eri objektit.
    const ref1 = cap.lookupSlotForPid(1, slot1) orelse {
        // Prosessi 1 slotti puuttuu.
        log.err("Process table lookup pid1 failed");
        // Lopeta testi.
        return;
    };
    const ref2 = cap.lookupSlotForPid(2, slot2) orelse {
        // Prosessi 2 slotti puuttuu.
        log.err("Process table lookup pid2 failed");
        // Lopeta testi.
        return;
    };
    // Slotit viittaavat eri objekteihin.
    if (ref1.object_id == ref2.object_id) {
        // Prosessien slotit eivät eristy.
        log.err("Process table slot isolation failed");
        // Lopeta testi.
        return;
    }
    // Nykyinen prosessi 2 → getpid = 2.
    if (!core.setCurrentPid(2)) {
        // setCurrentPid epäonnistui.
        log.err("Process set current pid 2 failed");
        // Lopeta testi.
        return;
    }
    const got2 = dispatch.invoke(abi.SYS_getpid, 0, 0, 0, 0, 0, 0);
    if (got2 != 2) {
        // getpid ei palauttanut 2.
        log.err("Process getpid pid2 failed");
        // Lopeta testi.
        return;
    }
    // Nykyinen prosessi 1 → getpid = 1.
    if (!core.setCurrentPid(1)) {
        // setCurrentPid epäonnistui.
        log.err("Process set current pid 1 failed");
        // Lopeta testi.
        return;
    }
    const got1 = dispatch.invoke(abi.SYS_getpid, 0, 0, 0, 0, 0, 0);
    if (got1 != 1) {
        // getpid ei palauttanut 1.
        log.err("Process getpid pid1 failed");
        // Lopeta testi.
        return;
    }
    // Kaikki prosessitaulukko-testit OK.
    log.info("Process table OK");
}
