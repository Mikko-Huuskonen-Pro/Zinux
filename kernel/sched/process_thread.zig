//! Prosessin pääsäie — ring 3 konteksti timer-preemptiota varten (Vaihe 26).
//!
//! **Vastuu**: Tallenna/ palauta user RIP/RSP/RFLAGS per pid.
//! **Riippuvuudet**: `process_core.zig`, `vmm.zig`
//! **Käytetään**: `process_scheduler.zig`, `process.zig`

// Tuo prosessitaulukko — ladatut kentät ja page_table.
const process = @import("process_core");
// Tuo VMM — kernel PML4 oletus.
const vmm = @import("../mm/vmm.zig");

// Montako prosessia preempt-jonossa kerrallaan.
pub const MAX_THREADS: usize = 8;

// Säikeen suoritustila scheduler-jonossa.
pub const ThreadRunState = enum {
    // Valmis ajettavaksi (ei vielä käynnissä tai tallennettu konteksti).
    ready,
    // Säie suorittaa ring 3:ssa (diagnostiikka).
    running,
    // sys_test_return / sys_exit — ei enää ajettava.
    finished,
};

// Ring 3 -konteksti yhdelle prosessille.
pub const ProcessThread = struct {
    // Prosessitunniste — linkki process_core:en.
    pid: u64,
    // ELF entry ensimmäiselle iretq:lle.
    entry: u64,
    // Pinon yläreuna ensimmäiselle iretq:lle.
    stack_top: u64,
    // Prosessin CR3 fyysinen osoite.
    pml4: u64,
    // Tallennettu user RIP (preempt jälkeen).
    rip: u64,
    // Tallennettu user RSP (preempt jälkeen).
    rsp: u64,
    // Tallennettu RFLAGS (preempt jälkeen).
    rflags: u64,
    // Tallennettu user CS (RPL 3).
    user_cs: u64,
    // Tallennettu user SS (RPL 3).
    user_ss: u64,
    // Onko rip/rsp/rflags tallennettu (ei ensimmäinen ajo).
    has_saved: bool,
    // Scheduler-tila — ready / running / finished.
    run_state: ThreadRunState,
};

// Kiinteä taulukko pääsäikeitä — indeksi = scheduler-jono.
var threads: [MAX_THREADS]ProcessThread = undefined;
// Montako säiettä on alustettu.
var thread_count: usize = 0;

// Nollaa säietaulukko — boot ja host-testit.
pub fn initCore() void {
    // Tyhjennä jokainen paikka.
    var i: usize = 0;
    while (i < MAX_THREADS) : (i += 1) {
        // Nollaa pid.
        threads[i].pid = 0;
        // Nollaa entry.
        threads[i].entry = 0;
        // Nollaa pinon huippu.
        threads[i].stack_top = 0;
        // Nollaa CR3.
        threads[i].pml4 = 0;
        // Nollaa tallennettu RIP.
        threads[i].rip = 0;
        // Nollaa tallennettu RSP.
        threads[i].rsp = 0;
        // Nollaa RFLAGS.
        threads[i].rflags = 0;
        // Nollaa user CS.
        threads[i].user_cs = 0;
        // Nollaa user SS.
        threads[i].user_ss = 0;
        // Ei tallennettua kontekstia.
        threads[i].has_saved = false;
        // Valmis ajettavaksi.
        threads[i].run_state = .ready;
    }
    // Ei alustettuja säieitä.
    thread_count = 0;
}

// Etsi säie indeksillä prosessitaulukossa.
fn findIndex(pid: u64) ?usize {
    // Käy alustetut säieet.
    var i: usize = 0;
    while (i < thread_count) : (i += 1) {
        // Täsmäävä pid → indeksi.
        if (threads[i].pid == pid) return i;
    }
    // Säiettä ei löydy.
    return null;
}

// Alusta prosessin pääsäie ladatuista tiedoista (Vaihe 26.1).
pub fn initMainThread(pid: u64) bool {
    // Hae ladatun prosessin suoritustiedot.
    const info = process.getLoadedInfo(pid) orelse return false;
    // Hae prosessin CR3 — kernel oletus jos 0.
    const pml4 = process.getPageTableOrDefault(pid, vmm.pml4Phys());
    // Jo alustettu → OK.
    if (findIndex(pid) != null) return true;
    // Taulukko täynnä.
    if (thread_count >= MAX_THREADS) return false;
    // Täytä uusi säie.
    threads[thread_count] = .{
        // Linkitä prosessiin.
        .pid = pid,
        // ELF entry.
        .entry = info.entry,
        // Pinon yläreuna.
        .stack_top = info.stack_top,
        // Prosessikohtainen CR3.
        .pml4 = pml4,
        // Ei vielä tallennettua RIP:ä.
        .rip = 0,
        // Ei vielä tallennettua RSP:ä.
        .rsp = 0,
        // Ei vielä RFLAGS.
        .rflags = 0,
        // Ei vielä CS.
        .user_cs = 0,
        // Ei vielä SS.
        .user_ss = 0,
        // Ensimmäinen ajo käyttää entry/stack_top.
        .has_saved = false,
        // Valmis scheduler-jonoon.
        .run_state = .ready,
    };
    // Kasvata lukumäärää.
    thread_count += 1;
    // Onnistui.
    return true;
}

// Onko prosessilla alustettu pääsäie.
pub fn hasMainThread(pid: u64) bool {
    // findIndex löytyy → säie on olemassa.
    return findIndex(pid) != null;
}

// Montako pääsäiettä on rekisteröity.
pub fn threadCount() usize {
    // Palauta alustettujen säieiden määrä.
    return thread_count;
}

// Hae säie indeksillä scheduler-jonossa (0..threadCount-1).
pub fn threadAt(index: usize) ?*ProcessThread {
    // Indeksi ulkopuolella.
    if (index >= thread_count) return null;
    // Palauta osoitin taulukkoon.
    return &threads[index];
}

// Hae säie pid:llä.
pub fn threadForPid(pid: u64) ?*ProcessThread {
    // Etsi indeksi.
    const idx = findIndex(pid) orelse return null;
    // Palauta osoitin.
    return &threads[idx];
}

// Tallenna ring 3 -konteksti timer-preempt:in yhteydessä.
pub fn saveContext(
    pid: u64,
    rip: u64,
    rsp: u64,
    rflags: u64,
    user_cs: u64,
    user_ss: u64,
) bool {
    // Hae säie.
    const t = threadForPid(pid) orelse return false;
    // Tallenna CPU-tila.
    t.rip = rip;
    // Tallenna user pinon osoite.
    t.rsp = rsp;
    // Tallenna RFLAGS (IF jne.).
    t.rflags = rflags;
    // Tallenna code segmentti.
    t.user_cs = user_cs;
    // Tallenna stack segmentti.
    t.user_ss = user_ss;
    // Seuraava ajo käyttää tallennettua kontekstia.
    t.has_saved = true;
    // Säie valmis uudelleenajoon.
    t.run_state = .ready;
    // Onnistui.
    return true;
}

// Merkitse säie valmiiksi (sys_test_return / sys_exit).
pub fn markFinished(pid: u64) bool {
    // Hae säie.
    const t = threadForPid(pid) orelse return false;
    // Ei enää ajettava.
    t.run_state = .finished;
    // Onnistui.
    return true;
}

// Merkitse säie parhaillaan suoritettavaksi.
pub fn markRunning(pid: u64) bool {
    // Hae säie.
    const t = threadForPid(pid) orelse return false;
    // Säie käyttää CPU:ta.
    t.run_state = .running;
    // Onnistui.
    return true;
}

// Onko kaikki rekisteröidyt säieet valmiita (finished).
pub fn allFinished() bool {
    // Tyhjä jono → valmis.
    if (thread_count == 0) return true;
    // Tarkista jokainen säie.
    var i: usize = 0;
    while (i < thread_count) : (i += 1) {
        // Jos joku ei ole finished → ei valmis.
        if (threads[i].run_state != .finished) return false;
    }
    // Kaikki valmiit.
    return true;
}
