//! Prosessilistan muotoilu — sys_ps-ydin (host-testattava).
//!
//! **Vastuu**: Muotoile prosessitaulukon PID:t tekstilistaksi.
//! **Riippuvuudet**: ei
//! **Käytetään**: `dispatch.zig`, `ps_syscall.zig`, host-testit

// Boot-prosessin oletus-pid — nimi "boot".
pub const BOOT_PID: u64 = 1;

// Palauta prosessin lyhyt nimi listaukseen.
pub fn processName(pid: u64, loaded: bool) []const u8 {
    // Boot/init-prosessi pid 1.
    if (pid == BOOT_PID) return "boot";
    // Spawnattu ELF-prosessi.
    if (loaded) return "user";
    // Muu rekisteröity prosessi.
    return "proc";
}

// Kopioi literaali puskuriin — palauttaa uusi offset.
fn appendLiteral(buf: []u8, offset: usize, text: []const u8) usize {
    // Nykyinen kirjoituskohta.
    var pos = offset;
    // Kopioi jokainen merkki jos mahtuu.
    for (text) |c| {
        // Puskuri täynnä — lopeta.
        if (pos >= buf.len) break;
        // Tallenna merkki.
        buf[pos] = c;
        // Siirry eteenpäin.
        pos += 1;
    }
    // Palauta uusi offset.
    return pos;
}

// Kirjoita desimaaliluku puskuriin — palauttaa uusi offset.
fn appendDecimal(buf: []u8, offset: usize, val: u64) usize {
    // Nollatapaus erikseen.
    if (val == 0) {
        // Yksi nollamerkki jos mahtuu.
        if (offset < buf.len) buf[offset] = '0';
        // Palauta offset + 1 tai sama jos täynnä.
        return if (offset < buf.len) offset + 1 else offset;
    }
    // Väliaikainen numeropuskuri käänteisessä järjestyksessä.
    var digits: [20]u8 = undefined;
    // Montako numeroa kerätty.
    var dlen: usize = 0;
    // Jäännös jakoa varten.
    var n = val;
    // Kerää numerot.
    while (n > 0) : (n /= 10) {
        // ASCII-numero jäännöksestä.
        digits[dlen] = @truncate('0' + (n % 10));
        // Kasvata pituus.
        dlen += 1;
    }
    // Nykyinen offset.
    var pos = offset;
    // Tulosta numerot oikeassa järjestyksessä.
    while (dlen > 0) {
        // Vähennä ennen tulostusta.
        dlen -= 1;
        // Puskuri täynnä — lopeta.
        if (pos >= buf.len) break;
        // Kopioi numero.
        buf[pos] = digits[dlen];
        // Siirry eteenpäin.
        pos += 1;
    }
    // Palauta uusi offset.
    return pos;
}

// Muotoile yksi prosessirivi: "    PID  name\n".
fn appendProcessLine(buf: []u8, offset: usize, pid: u64, name: []const u8) usize {
    // Neljä välilyöntiä ennen pid:tä (stub-tyyli).
    var pos = appendLiteral(buf, offset, "    ");
    // Prosessitunniste desimaalina.
    pos = appendDecimal(buf, pos, pid);
    // Kaksi välilyöntiä ennen nimeä.
    pos = appendLiteral(buf, pos, "  ");
    // Prosessin lyhyt nimi.
    pos = appendLiteral(buf, pos, name);
    // Rivinvaihto.
    pos = appendLiteral(buf, pos, "\n");
    // Palauta uusi offset.
    return pos;
}

// Muotoile prosessilista puskuriin — palauttaa kirjoitettujen tavujen määrä.
pub fn formatListing(
    process_count: usize,
    pid_at: *const fn (usize) ?u64,
    loaded_at: *const fn (u64) bool,
    buf: []u8,
) usize {
    // Otsikkorivi kuten aiempi stub.
    var pos = appendLiteral(buf, 0, "  PID  NAME\n");
    // Käy rekisteröidyt prosessit indeksijärjestyksessä.
    var i: usize = 0;
    while (i < process_count) : (i += 1) {
        // Hae pid callbackilla — ohita tyhjät.
        const pid = pid_at(i) orelse continue;
        // Hae loaded-tila callbackilla.
        const loaded = loaded_at(pid);
        // Prosessin lyhyt nimi.
        const name = processName(pid, loaded);
        // Lisää yksi rivi listaukseen.
        pos = appendProcessLine(buf, pos, pid, name);
    }
    // Palauta kokonaispituus.
    return pos;
}

// Etsi desimaalinen pid merkkijonosta — yksinkertainen osumahaku.
pub fn listingContainsPid(listing: []const u8, pid: u64) bool {
    // Muunna pid tekstiksi pienessä puskurissa.
    var needle: [24]u8 = undefined;
    // Kirjoita pid numerot.
    const nlen = appendDecimal(&needle, 0, pid);
    // Tyhjä pid (ei pitäisi tapahtua).
    if (nlen == 0) return false;
    // Etsi osajonoa listauksesta (ei täydellinen sanarajaus — riittää boot-testiin).
    var i: usize = 0;
    while (i + nlen <= listing.len) : (i += 1) {
        // Vertaa nlen tavua.
        var j: usize = 0;
        var match = true;
        while (j < nlen) : (j += 1) {
            // Jos tavu ei täsmää.
            if (listing[i + j] != needle[j]) {
                // Ei osuma tässä kohdassa.
                match = false;
                // Lopeta sisäinen silmukka.
                break;
            }
        }
        // Kaikki tavut täsmäsivät.
        if (match) return true;
    }
    // Pid:ä ei löytynyt listauksesta.
    return false;
}
