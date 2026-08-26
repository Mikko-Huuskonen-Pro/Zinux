//! Fyysinen muistinhallinta (PMM) — bitmap-allokaattori.

pub const FRAME_SIZE: usize = 4096;

// Yksinkertaistettu muistikarta-entry (ei riipu Liminestä — host-testit OK).
pub const MapEntry = struct {
    base: u64,
    length: u64,
    usable: bool,
};

// Bitmap-tallennus — 32 KiB = ~128M kehystä (512 GiB max teoreettinen).
var bitmap_storage: [32768]u8 align(4096) linksection(".bss") = undefined;
var bitmap: []u8 = undefined;
var frame_count: usize = 0;
var next_free: usize = 0;
var mem_base: u64 = 0;

// Merkitse kehys varatuksi indeksin perusteella.
fn markUsed(frame_index: usize) void {
    if (frame_index >= frame_count) return;
    const byte_i = frame_index / 8;
    const bit_i = frame_index % 8;
    bitmap[byte_i] |= @as(u8, 1) << @intCast(bit_i);
}

// Merkitse kehys vapaaksi indeksin perusteella.
fn markFree(frame_index: usize) void {
    if (frame_index >= frame_count) return;
    const byte_i = frame_index / 8;
    const bit_i = frame_index % 8;
    bitmap[byte_i] &= ~(@as(u8, 1) << @intCast(bit_i));
}

// Merkitse fyysinen osoitealue varatuksi (kernel, ACPI, jne.).
fn reservePhysRange(base: u64, length: u64) void {
    if (length == 0) return;
    const start = base / FRAME_SIZE;
    const end = (base + length + FRAME_SIZE - 1) / FRAME_SIZE;
    var i = start;
    while (i < end and i < frame_count) : (i += 1) {
        markUsed(i);
    }
}

// Merkitse fyysinen osoitealue vapaaksi (usable RAM).
fn freePhysRange(base: u64, length: u64) void {
    if (length == 0) return;
    const start = base / FRAME_SIZE;
    const end = (base + length + FRAME_SIZE - 1) / FRAME_SIZE;
    var i = start;
    while (i < end and i < frame_count) : (i += 1) {
        markFree(i);
    }
}

// Alusta PMM muistikartasta (Limine-entryt konvertoidaan main.zig:ssä).
pub fn initFromMap(entries: []const MapEntry) void {
    var max_addr: u64 = 0;
    for (entries) |entry| {
        const end = entry.base + entry.length;
        if (end > max_addr) max_addr = end;
    }
    frame_count = @intCast((max_addr + FRAME_SIZE - 1) / FRAME_SIZE);
    const bitmap_bytes = (frame_count + 7) / 8;
    if (bitmap_bytes > bitmap_storage.len) {
        frame_count = bitmap_storage.len * 8;
    }
    bitmap = bitmap_storage[0 .. (frame_count + 7) / 8];
    mem_base = 0;
    next_free = 0;
    @memset(bitmap, 0xFF);
    for (entries) |entry| {
        if (entry.usable) {
            freePhysRange(entry.base, entry.length);
        } else {
            reservePhysRange(entry.base, entry.length);
        }
    }
    reservePhysRange(@intFromPtr(&bitmap_storage), bitmap_storage.len);
}

// Fallback ilman muistikarttaa — oletus 256 MiB RAM.
pub fn initFallback(total_bytes: u64) void {
    frame_count = @intCast((total_bytes + FRAME_SIZE - 1) / FRAME_SIZE);
    if (frame_count > bitmap_storage.len * 8) {
        frame_count = bitmap_storage.len * 8;
    }
    bitmap = bitmap_storage[0 .. (frame_count + 7) / 8];
    mem_base = 0;
    next_free = 0;
    @memset(bitmap, 0);
    reservePhysRange(@intFromPtr(&bitmap_storage), bitmap_storage.len);
}

pub fn allocFrame() ?usize {
    if (frame_count == 0) return null;
    var i: usize = 0;
    while (i < frame_count) : (i += 1) {
        const idx = (next_free + i) % frame_count;
        const byte_i = idx / 8;
        const bit_i = idx % 8;
        if ((bitmap[byte_i] & (@as(u8, 1) << @intCast(bit_i))) == 0) {
            markUsed(idx);
            next_free = (idx + 1) % frame_count;
            return idx;
        }
    }
    return null;
}

pub fn freeFrame(frame_index: usize) void {
    markFree(frame_index);
}

pub fn frameToPhys(frame_index: usize) u64 {
    return mem_base + @as(u64, frame_index) * FRAME_SIZE;
}

pub fn totalFrames() usize {
    return frame_count;
}

// Host-testejä varten: suora bitmap-alustus.
pub fn init(bitmap_buffer: []u8, total: usize) void {
    bitmap = bitmap_buffer;
    frame_count = total;
    next_free = 0;
    mem_base = 0;
    @memset(bitmap, 0);
}
