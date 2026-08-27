//! Prosessitaulukon ydin — pid-allokaatio ja current pid (host-testattava).
//!
//! **Vastuu**: Rekisteröi prosessit, pid → indeksi, nykyinen prosessi syscall-kontekstissa.
//! **Riippuvuudet**: ei
//! **Käytetään**: `process.zig`, `capability_core.zig`, `spawn.zig`, host-testit

// Boot/init-prosessin oletus-pid (stub userland ennen spawnia).
pub const BOOT_PID: u64 = 1;
// Maksimi prosessien määrä kernelin taulukossa.
pub const MAX_PROCESSES: usize = 16;

// Yksittäinen prosessi prosessitaulukossa.
pub const Process = struct {
    // Onko taulukkopaikka käytössä.
    used: bool,
    // Prosessitunniste (uniikki taulukossa).
    pid: u64,
    // Onko ELF ladattu ja entry/pino valmiina (Vaihe 21 spawn).
    loaded: bool,
    // Ring 3 entry-piste ladatusta ELF:stä.
    entry: u64,
    // Käyttäjäpinon yläreuna iretq:ä varten.
    stack_top: u64,
    // Heap-slot josta pino kartoitettiin.
    stack_slot: u64,
};

// Ladatun prosessin suoritustiedot — runProcess/spawn.
pub const LoadedProcess = struct {
    // ELF e_entry.
    entry: u64,
    // Pinon yläreuna.
    stack_top: u64,
    // Pinon heap-slot (debug/erottelu).
    stack_slot: u64,
};

// Kiinteä prosessitaulukko — indeksi = capability-slottien ryhmä.
var processes: [MAX_PROCESSES]Process = undefined;
// Montako prosessia on rekisteröity.
var used_count: usize = 0;
// Nykyinen prosessi syscall- ja capability-kontekstissa.
var current_pid: u64 = BOOT_PID;
// Onko ydin alustettu.
var initialized: bool = false;

// Nollaa prosessitaulukko — boot ja host-testit.
pub fn initCore() void {
    // Tyhjennä jokainen prosessipaikka.
    for (&processes) |*p| {
        // Merkitse vapaa.
        p.used = false;
        // Nollaa pid.
        p.pid = 0;
        // Ei ladattua ELF:ää.
        p.loaded = false;
        // Nollaa entry.
        p.entry = 0;
        // Nollaa pinon huippu.
        p.stack_top = 0;
        // Nollaa pinon slot.
        p.stack_slot = 0;
    }
    // Ei rekisteröityjä prosesseja.
    used_count = 0;
    // Nykyinen prosessi boot-pid ennen ensimmäistä allocia.
    current_pid = BOOT_PID;
    // Rekisteröi boot-prosessi (pid 1).
    _ = allocProcess(BOOT_PID);
    // Merkitse alustetuksi.
    initialized = true;
}

// Hae prosessin taulukkoindeksi pid:llä.
pub fn findIndex(pid: u64) ?usize {
    // Vaadi alustus.
    if (!initialized) return null;
    // Käy rekisteröidyt prosessit.
    var i: usize = 0;
    while (i < used_count) : (i += 1) {
        // Täsmäävä pid → indeksi.
        if (processes[i].used and processes[i].pid == pid) return i;
    }
    // Prosessia ei löydy.
    return null;
}

// Rekisteröi uusi prosessi taulukkoon — palauttaa false jos täynnä.
pub fn allocProcess(pid: u64) bool {
    // Vaadi alustus (initCore rekursiota varten asettaa initialized viimeisenä).
    if (!initialized and pid != BOOT_PID) return false;
    // Jos initCore kutsuu allocProcess ennen initialized=true, salli vain boot.
    if (!initialized and pid == BOOT_PID and used_count == 0) {
        // Ensimmäinen prosessi initCore:n aikana.
        processes[0] = .{
            .used = true,
            .pid = BOOT_PID,
            .loaded = false,
            .entry = 0,
            .stack_top = 0,
            .stack_slot = 0,
        };
        // Yksi prosessi rekisteröity.
        used_count = 1;
        // Onnistui.
        return true;
    }
    // Vaadi alustus muiden pid:ien kohdalla.
    if (!initialized) return false;
    // Jo rekisteröity → OK.
    if (findIndex(pid) != null) return true;
    // Taulukko täynnä.
    if (used_count >= MAX_PROCESSES) return false;
    // Lisää uusi prosessi.
    processes[used_count] = .{
        .used = true,
        .pid = pid,
        .loaded = false,
        .entry = 0,
        .stack_top = 0,
        .stack_slot = 0,
    };
    // Kasvata lukumäärää.
    used_count += 1;
    // Onnistui.
    return true;
}

// Allokoi seuraava vapaa pid (aloita 2:sta) — Vaihe 21 spawn.
pub fn allocNextPid() ?u64 {
    // Vaadi alustus.
    if (!initialized) return null;
    // Etsi ensimmäinen vapaa pid.
    var pid: u64 = 2;
    // Rajaa haku järkevään alueeseen.
    while (pid < 0x10000) : (pid += 1) {
        // Jos pid ei ole taulukossa, rekisteröi ja palauta.
        if (findIndex(pid) == null) {
            // Rekisteröi uusi prosessi.
            if (!allocProcess(pid)) return null;
            // Palauta uusi tunniste.
            return pid;
        }
    }
    // Kaikki numerot käytössä.
    return null;
}

// Tallenna ladatun prosessin suoritustiedot taulukkoon.
pub fn setLoaded(pid: u64, entry: u64, stack_top: u64, stack_slot: u64) bool {
    // Hae prosessin indeksi.
    const idx = findIndex(pid) orelse return false;
    // Merkitse ELF ladatuksi.
    processes[idx].loaded = true;
    // Tallenna entry.
    processes[idx].entry = entry;
    // Tallenna pinon huippu.
    processes[idx].stack_top = stack_top;
    // Tallenna pinon slot.
    processes[idx].stack_slot = stack_slot;
    // Onnistui.
    return true;
}

// Hae ladatun prosessin suoritustiedot — null jos ei ladattu.
pub fn getLoadedInfo(pid: u64) ?LoadedProcess {
    // Hae prosessin indeksi.
    const idx = findIndex(pid) orelse return null;
    // Vaadi ladattu ELF.
    if (!processes[idx].loaded) return null;
    // Palauta kopio suoritustiedoista.
    return .{
        .entry = processes[idx].entry,
        .stack_top = processes[idx].stack_top,
        .stack_slot = processes[idx].stack_slot,
    };
}

// Palauta nykyinen prosessitunniste.
pub fn currentPid() u64 {
    // Palauta syscall-kontekstin pid.
    return current_pid;
}

// Aseta nykyinen prosessi — false jos pid ei ole taulukossa.
pub fn setCurrentPid(pid: u64) bool {
    // Vaadi että prosessi on rekisteröity.
    if (findIndex(pid) == null) return false;
    // Päivitä nykyinen konteksti.
    current_pid = pid;
    // Onnistui.
    return true;
}

// Montako prosessia on rekisteröity.
pub fn processCount() usize {
    // Palauta rekisteröityjen prosessien määrä.
    return used_count;
}
