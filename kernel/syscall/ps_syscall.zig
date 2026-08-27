//! Prosessilista boot-testi — cap_create currentPid + sys_ps (Vaihe 23).
//!
//! **Vastuu**: Security S1 korjaus ja prosessilistan syscall-vahvistus.
//! **Riippuvuudet**: `dispatch.zig`, `capability_core.zig`, `process_core`, log
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("dispatch.zig");
// Tuo capability — lookupSlotForPid cap create -testiin.
const cap = @import("../ipc/capability_core.zig");
// Tuo capability-syscall-ydin — tyypit ja maskit.
const cap_core = @import("cap_syscall_core.zig");
// Tuo prosessitaulukko — pid-allokaatio ja listing.
const process = @import("process_core");
// Tuo ps-ydin — listingContainsPid vahvistukseen.
const ps_core = @import("ps_syscall_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Boot-testi — cap_create currentPid (23.0 / security S1).
fn runCapCreatePidTest() void {
    // Allokoi uusi prosessi — erillinen capability-taulukko.
    const pid = process.allocNextPid() orelse {
        // Prosessi ei mahdu taulukkoon.
        log.err("Cap create pid alloc failed");
        // Lopeta alitesti.
        return;
    };
    // Aseta current pid ennen sys_cap_create-kutsua.
    if (!process.setCurrentPid(pid)) {
        // setCurrentPid epäonnistui.
        log.err("Cap create pid set current failed");
        // Lopeta alitesti.
        return;
    }
    // Oikeudet send + recv uudelle portille.
    const rights_mask = cap_core.MASK_SEND | cap_core.MASK_RECV;
    // Luo portti-capability invoke()-kautta — pitää asentua `pid`:n slottiin.
    const slot = dispatch.invoke(abi.SYS_cap_create, cap_core.CAP_TYPE_PORT, rights_mask, 0, 0, 0, 0);
    // Varmista että slot-indeksi palautui.
    if (slot < 0) {
        // Luonti epäonnistui.
        log.err("Cap create pid syscall failed");
        // Lopeta alitesti.
        return;
    }
    // Hae slotti prosessikohtaisesti — ei pid 1:n taulukosta.
    const ref = cap.lookupSlotForPid(pid, @intCast(slot)) orelse {
        // Cap asentui väärään prosessiin tai puuttuu.
        log.err("Cap create pid lookup failed");
        // Lopeta alitesti.
        return;
    };
    // Slotti ilman objektiviitettä on virhe.
    if (ref.object_id == 0) {
        // Tyhjä capability-slotti.
        log.err("Cap create pid empty slot");
        // Lopeta alitesti.
        return;
    }
    // Palauta boot-prosessin konteksti.
    _ = process.setCurrentPid(process.BOOT_PID);
    // Security S1 korjaus OK (23.0).
    log.info("Cap create pid OK");
}

// Boot-testi — sys_ps listaa prosessitaulukon (23.1 + 23.3).
fn runPsListingTest() void {
    // Varmista vähintään boot-prosessi rekisteröity.
    if (process.processCount() < 1) {
        // Prosessitaulukko tyhjä.
        log.err("Ps syscall empty process table");
        // Lopeta alitesti.
        return;
    }
    // Rekisteröi toinen prosessi jos vain boot (testaa useita rivejä).
    _ = process.allocProcess(2);
    // Kernel-puskuri sys_ps invoke:lle.
    var kbuf: [256]u8 = undefined;
    // Kutsu sys_ps suoraan dispatch invoke:lla.
    const got = dispatch.invoke(abi.SYS_ps, @intFromPtr(&kbuf), kbuf.len, 0, 0, 0, 0);
    // Varmista että jotain kirjoitettiin.
    if (got <= 0) {
        // sys_ps epäonnistui tai tyhjä lista.
        log.err("Ps syscall failed");
        // Lopeta alitesti.
        return;
    }
    // Listing pitää sisältää otsikon.
    if (got < 10) {
        // Liian lyhyt vastaus.
        log.err("Ps syscall short listing");
        // Lopeta alitesti.
        return;
    }
    // sys_ps palauttaa muotoillun listan (23.1).
    log.info("Ps syscall OK");
    // Boot-pid 1 pitää näkyä listassa.
    if (!ps_core.listingContainsPid(kbuf[0..@intCast(got)], process.BOOT_PID)) {
        // Boot-prosessi puuttuu listauksesta.
        log.err("Ps lists boot pid missing");
        // Lopeta alitesti.
        return;
    }
    // Prosessi 2 pitää näkyä (allocProcess yllä).
    if (!ps_core.listingContainsPid(kbuf[0..@intCast(got)], 2)) {
        // Toinen prosessi puuttuu listauksesta.
        log.err("Ps lists pid 2 missing");
        // Lopeta alitesti.
        return;
    }
    // Useita prosesseja listassa (23.3).
    log.info("Ps lists processes OK");
}

// Boot-testi — aja cap_create pid + sys_ps alitestit.
pub fn runBootTest() void {
    // 23.0 — security S1: sys_cap_create → currentPid.
    runCapCreatePidTest();
    // 23.1 + 23.3 — sys_ps prosessitaulukosta.
    runPsListingTest();
}
