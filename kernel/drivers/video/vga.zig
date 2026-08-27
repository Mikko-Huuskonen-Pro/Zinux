//! VGA text mode -ajuri (80×25 @ 0xB8000).
//!
//! **Vastuu**: Tulosta tekstiä VGA-näytön tekstipuskuriin.
//! **Riippuvuudet**: ei (suora MMIO 0xB8000)
//! **Käytetään**: `lib/log.zig`

// VGA text mode -puskurin osoite — jokainen solu on u16 (merkki + attribuutti).
pub const VGA_BUFFER: [*]volatile u16 = @ptrFromInt(0xB8000);
// Näytön leveys merkkejä (legacy VGA text mode).
pub const VGA_WIDTH: usize = 80;
// Näytön korkeus riveinä.
pub const VGA_HEIGHT: usize = 25;

// 16 VGA-väriä (4 bittiä) — etu- ja taustaväri attribuutissa.
pub const Color = enum(u4) {
    black,
    blue,
    green,
    cyan,
    red,
    magenta,
    brown,
    light_grey,
    dark_grey,
    light_blue,
    light_green,
    light_cyan,
    light_red,
    pink,
    yellow,
    white,
};

// Muodosta u16 VGA-solu merkistä ja väreistä (fg alinibble, bg ylinibble).
fn makeEntry(ch: u8, fg: Color, bg: Color) u16 {
    return @as(u16, ch) | (@as(u16, @intFromEnum(fg)) << 0) | (@as(u16, @intFromEnum(bg)) << 4);
}

// Nykyinen kursorin rivi (0 = ylin).
var cursor_row: usize = 0;
// Nykyinen kursorin sarake (0 = vasen).
var cursor_col: usize = 0;
// Oletusattribuutti: valkoinen etu, musta tausta (0x0F).
const default_attr: u8 = 0x0F;

// Tyhjennä koko VGA-näyttö ja nollaa kursori.
pub fn clear() void {
    // Tyhjä solu: välilyönti valkoisella mustalla taustalla.
    const entry = makeEntry(' ', .white, .black);
    // Kirjoita tyhjä solu jokaiseen 80×25 ruutuun.
    for (0..VGA_WIDTH * VGA_HEIGHT) |i| VGA_BUFFER[i] = entry;
    // Palauta kursori näytön alkuun.
    cursor_row = 0;
    cursor_col = 0;
}

// Tulosta yksi merkki VGA-näytölle — käsittelee \n ja \r.
pub fn putc(ch: u8) void {
    switch (ch) {
        // Rivinvaihto: siirry seuraavalle riville, sarake alkuun.
        '\n' => {
            cursor_col = 0;
            cursor_row += 1;
        },
        // Carriage return: sarake alkuun, rivi sama.
        '\r' => cursor_col = 0,
        // Tulostettava merkki.
        else => {
            // Jos sarake täynnä, rivinvaihto automaattisesti.
            if (cursor_col >= VGA_WIDTH) {
                cursor_col = 0;
                cursor_row += 1;
            }
            // Jos rivi täynnä, scrollaa ylös.
            if (cursor_row >= VGA_HEIGHT) scroll();
            // Laske solun indeksi: rivi * leveys + sarake.
            const idx = cursor_row * VGA_WIDTH + cursor_col;
            // Kirjoita merkki + attribuutti VGA-puskuriin.
            VGA_BUFFER[idx] = @as(u16, ch) | (@as(u16, default_attr) << 8);
            // Siirrä kursoria oikealle yhdellä.
            cursor_col += 1;
        },
    }
}

// Scrollaa näyttö ylös yhdellä rivillä kun viimeinen rivi täyttyy.
fn scroll() void {
    // Kopioi rivit 1..24 rivien 0..23 päälle.
    for (0..(VGA_HEIGHT - 1) * VGA_WIDTH) |i| {
        VGA_BUFFER[i] = VGA_BUFFER[i + VGA_WIDTH];
    }
    // Tyhjennä alin rivi välilyönneillä.
    const blank = makeEntry(' ', .white, .black);
    for ((VGA_HEIGHT - 1) * VGA_WIDTH..VGA_HEIGHT * VGA_WIDTH) |i| {
        VGA_BUFFER[i] = blank;
    }
    // Pidä kursori alimmalla rivillä.
    cursor_row = VGA_HEIGHT - 1;
}

// Tulosta merkkijono merkki kerrallaan.
pub fn write(msg: []const u8) void {
    for (msg) |b| putc(b);
}
