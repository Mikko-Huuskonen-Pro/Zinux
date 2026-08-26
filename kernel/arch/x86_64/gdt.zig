//! Global Descriptor Table (GDT) x86_64:lle.
//!
//! **Vastuu**: Luo kernel-segmentit ja lataa GDT CPU:hen.
//! **Riippuvuudet**: ei
//! **Käytetään**: `kernel/main.zig` kmain-alustuksessa (Vaihe 2)

// GDT-kuvaus: limit (16b) + base (24b) alaosat.
const GdtEntry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_mid: u8,
    access: u8,
    granularity: u8,
    base_high: u8,

    // Muodosta GDT-merkintä annetuista kentistä.
    fn init(base: u32, limit: u32, access: u8, gran: u8) GdtEntry {
        return .{
            .limit_low = @truncate(limit & 0xFFFF),
            .base_low = @truncate(base & 0xFFFF),
            .base_mid = @truncate((base >> 16) & 0xFF),
            .access = access,
            .granularity = @truncate(((limit >> 16) & 0x0F) | (gran & 0xF0)),
            .base_high = @truncate((base >> 24) & 0xFF),
        };
    }
};

// GDTR-rekisteriin ladattava kuvaus (limit + osoite).
const GdtPointer = packed struct {
    limit: u16,
    base: u64,
};

// GDT-taulukko — 5 merkintää: null, kernel code, kernel data, user code, user data.
var gdt: [5]GdtEntry = undefined;

// GDT-kuvaus jota lgdt-komento käyttää.
var gdt_ptr: GdtPointer = undefined;

// Segmenttivalitsimet (offsetit GDT:ssä * 8).
pub const KERNEL_CODE_SEL: u16 = 0x08;
pub const KERNEL_DATA_SEL: u16 = 0x10;
pub const USER_CODE_SEL: u16 = 0x18;
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
    // Lataa kernel data -segmentti SS:ään ja DS/ES/FS/GS:ään.
    asm volatile (
        \\mov $0x10, %%ax
        \\mov %%ax, %%ds
        \\mov %%ax, %%es
        \\mov %%ax, %%ss
        :
        :
        : .{ .ax = true });
}
