//! Global Descriptor Table (GDT) x86_64:lle.
//!
//! **Vastuu**: Luo kernel-segmentit ja lataa GDT CPU:hen.
//! **Riippuvuudet**: ei
//! **Käytetään**: `kernel/main.zig` kmain-alustuksessa (Vaihe 2)

// GDT-kuvaus: limit (16b) + base (24b) alaosat.
const GdtEntry = packed struct {
    // Segmentin koko alimmat 16 bittiä (limit_low).
    limit_low: u16,
    // Base-osoitteen alimmat 16 bittiä.
    base_low: u16,
    // Base-osoitteen bitit 16..23.
    base_mid: u8,
    // Access byte — present, DPL, type (code/data).
    access: u8,
    // Granularity + limit bitit 16..19 (4 KiB granularity yleensä).
    granularity: u8,
    // Base-osoitteen bitit 24..31.
    base_high: u8,

    // Muodosta GDT-merkintä annetuista kentistä.
    fn init(base: u32, limit: u32, access: u8, gran: u8) GdtEntry {
        // Palauta täytetty GDT-merkintä limit/base/access/gran -arvoista.
        return .{
            // Limit alimmat 16 bittiä.
            .limit_low = @truncate(limit & 0xFFFF),
            // Base alimmat 16 bittiä.
            .base_low = @truncate(base & 0xFFFF),
            // Base keskimmäiset 8 bittiä.
            .base_mid = @truncate((base >> 16) & 0xFF),
            // Access byte sellaisenaan.
            .access = access,
            // Limit ylimmät 4 bittiä + granularity-bitti.
            .granularity = @truncate(((limit >> 16) & 0x0F) | (gran & 0xF0)),
            // Base ylimmät 8 bittiä.
            .base_high = @truncate((base >> 24) & 0xFF),
        };
    }
};

// GDTR-rekisteriin ladattava kuvaus (limit + osoite).
const GdtPointer = packed struct {
    // GDT-taulukon koko tavuina miinus yksi.
    limit: u16,
    // GDT-taulukon 64-bittinen virtuaalinen osoite.
    base: u64,
};

// GDT-taulukko — 5 merkintää: null, kernel code, kernel data, user code, user data.
var gdt: [5]GdtEntry = undefined;

// GDT-kuvaus jota lgdt-komento käyttää.
var gdt_ptr: GdtPointer = undefined;

// Segmenttivalitsimet (offsetit GDT:ssä * 8).
// Kernel code -segmentti (GDT indeksi 1 → 0x08).
pub const KERNEL_CODE_SEL: u16 = 0x08;
// Kernel data -segmentti (GDT indeksi 2 → 0x10).
pub const KERNEL_DATA_SEL: u16 = 0x10;
// User code -segmentti ring 3:lle (GDT indeksi 3 → 0x18).
pub const USER_CODE_SEL: u16 = 0x18;
// User data -segmentti ring 3:lle (GDT indeksi 4 → 0x20).
pub const USER_DATA_SEL: u16 = 0x20;

// Alusta GDT ja lataa se CPU:hen lgdt-komennolla.
pub fn init() void {
    // Nollamerkintä — pakollinen GDT:n ensimmäinen entry.
    gdt[0] = GdtEntry.init(0, 0, 0, 0);
    // Kernel code: present, ring 0, executable, readable (0x9A).
    gdt[1] = GdtEntry.init(0, 0, 0x9A, 0xA0);
    // Kernel data: present, ring 0, writable (0x92).
    gdt[2] = GdtEntry.init(0, 0, 0x92, 0xA0);
    // User code: present, ring 3, executable (0xFA) — tuleva user mode.
    gdt[3] = GdtEntry.init(0, 0, 0xFA, 0xA0);
    // User data: present, ring 3, writable (0xF2).
    gdt[4] = GdtEntry.init(0, 0, 0xF2, 0xA0);
    // GDTR.limit = taulukon koko tavuina - 1.
    gdt_ptr.limit = @sizeOf(@TypeOf(gdt)) - 1;
    // GDTR.base = GDT-taulukon osoite muistissa.
    gdt_ptr.base = @intFromPtr(&gdt);
    // Lataa uusi GDT CPU:hen — aktivoi segmenttirekisterit seuraavalla far jump:lla tarvittaessa.
    asm volatile ("lgdt (%[ptr])"
        :
        : [ptr] "r" (&gdt_ptr),
    );
    // Lataa kernel data -segmentti SS:ään ja DS/ES:ään (FS/GS jätetään myöhemmin).
    asm volatile (
        \\mov $0x10, %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%ss
        :
        :
        : .{ .ax = true });
}
