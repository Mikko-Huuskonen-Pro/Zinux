//! Prosessitaulukon ydin — pid-allokaatio ja current pid (host-testattava).
//!
//! **Vastuu**: Rekisteröi prosessit, pid → indeksi, nykyinen prosessi syscall-kontekstissa.
//! **Riippuvuudet**: ei
//! **Käytetään**: `process.zig`, `capability_core.zig`, host-testit

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
        processes[0] = .{ .used = true, .pid = BOOT_PID };
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
    processes[used_count] = .{ .used = true, .pid = pid };
    // Kasvata lukumäärää.
    used_count += 1;
    // Onnistui.
    return true;
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
