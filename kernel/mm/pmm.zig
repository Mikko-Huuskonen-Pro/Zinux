//! Fyysinen muistinhallinta (PMM) — bitmap-pohjainen 4 KiB kehysallokaattori.
//!
//! **Vastuu**: Varata ja vapauttaa fyysisiä 4 KiB muistikehyksiä.
//! **Riippuvuudet**: `../boot/limine_protocol.zig` (MemoryMap tuleva)
//! **Käytetään**: VMM, heap (Vaihe 2)

// Yhden fyysisen kehyksen koko tavuina (x86 sivukoko).
pub const FRAME_SIZE: usize = 4096;

// Bitmap-taulukko — 1 bitti per kehys (1=varattu, 0=vapaa).
var bitmap: []u8 = undefined;
// Kehysten kokonaismäärä bitmapissa.
var frame_count: usize = 0;
// Indeksi josta seuraava allokaatio etsitään (round-robin).
var next_free: usize = 0;

// Alusta PMM annetulla bitmap-puskurilla ja kehysmäärällä.
pub fn init(bitmap_buffer: []u8, total_frames: usize) void {
    // Tallenna bitmap-osoitin ja kehysten lukumäärä.
    bitmap = bitmap_buffer;
    frame_count = total_frames;
    // Nollaa seuraava vapaa indeksi.
    next_free = 0;
    // Merkitse kaikki kehykset vapaaksi (nollaa bitmap).
    @memset(bitmap, 0);
}

// Etsii seuraavan vapaan kehyksen bitmapista — palauttaa indeksin tai null.
pub fn allocFrame() ?usize {
    // Jos ei kehyksiä, palauta heti null.
    if (frame_count == 0) return null;
    // Aloita etsintä viimeisestä löydetystä paikasta ( vähentää fragmentaatiota ).
    var i: usize = 0;
    while (i < frame_count) : (i += 1) {
        // Laske tarkasteltava indeksi kiertävästi.
        const idx = (next_free + i) % frame_count;
        // Laske bitmap-tavun ja bitin sijainti.
        const byte_i = idx / 8;
        const bit_i = idx % 8;
        // Tarkista onko bitti 0 (vapaa kehys).
        if ((bitmap[byte_i] & (@as(u8, 1) << @intCast(bit_i))) == 0) {
            // Merkitse kehys varatuksi asettamalla bitti 1:ksi.
            bitmap[byte_i] |= @as(u8, 1) << @intCast(bit_i);
            // Päivitä seuraava etsintäkohta.
            next_free = (idx + 1) % frame_count;
            return idx;
        }
    }
    // Ei vapaita kehyksiä.
    return null;
}

// Vapauttaa aiemmin varatun kehyksen indeksin perusteella.
pub fn freeFrame(frame_index: usize) void {
    // Hylkää virheelliset indeksit hiljaa.
    if (frame_index >= frame_count) return;
    // Laske bitmap-tavu ja bittipaikka.
    const byte_i = frame_index / 8;
    const bit_i = frame_index % 8;
    // Aseta bitti nollaksi = kehys vapaa.
    bitmap[byte_i] &= ~(@as(u8, 1) << @intCast(bit_i));
}

// Palauttaa kehysindeksin fyysisen osoitteen (tarvitsee mem_base).
pub fn frameToPhys(frame_index: usize, mem_base: u64) u64 {
    return mem_base + @as(u64, frame_index) * FRAME_SIZE;
}
