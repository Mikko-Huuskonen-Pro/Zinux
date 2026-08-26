//! Interrupt Descriptor Table (IDT) x86_64:lle.
//!
//! **Vastuu**: Aseta keskeytyskäsittelijät ja lataa IDT CPU:hen.
//! **Riippuvuudet**: ei
//! **Käytetään**: `kernel/main.zig` kmain-alustuksessa (Vaihe 2)

const gdt = @import("gdt.zig");

// IDT-kuvaus: offset, segment, flags, higher offset.
const IdtEntry = packed struct {
    offset_low: u16,
    selector: u16,
    ist: u8,
    type_attr: u8,
    offset_mid: u16,
    offset_high: u32,
    zero: u32,

    // Muodosta 64-bit IDT-merkintä handler-osoitteesta.
    fn init(handler: u64, selector: u16, type_attr: u8) IdtEntry {
        return .{
            .offset_low = @truncate(handler & 0xFFFF),
            .selector = selector,
            .ist = 0,
            .type_attr = type_attr,
            .offset_mid = @truncate((handler >> 16) & 0xFFFF),
            .offset_high = @truncate(handler >> 32),
            .zero = 0,
        };
    }
};

// IDTR-rekisteriin ladattava kuvaus.
const IdtPointer = packed struct {
    limit: u16,
    base: u64,
};

// 256 keskeytysvektoria — riittää x86_64 IRQ + CPU poikkeuksiin.
var idt: [256]IdtEntry = undefined;
var idt_ptr: IdtPointer = undefined;

// Yleinen keskeytyskäsittelijä — tulostaa '!' ja palaa (stub Vaihe 2).
export fn isrStub() callconv(.naked) noreturn {
    // Palauta stack ja IRETQ — yksinkertaistettu stub (ei oikeaa kontekstia vielä).
    asm volatile (
        \\cli
        \\hlt
    );
}

// Alusta IDT: kaikki vektorit osoittavat stub-käsittelijään toistaiseksi.
pub fn init() void {
    // Handler-osoite stub-funktiosta.
    const handler_addr: u64 = @intFromPtr(&isrStub);
    // IDT-tyyppi: present, DPL0, interrupt gate (0x8E).
    const attr: u8 = 0x8E;
    // Täytä jokainen IDT-merkintä samalla stub-käsittelijällä.
    for (&idt, 0..) |*entry, i| {
        _ = i;
        entry.* = IdtEntry.init(handler_addr, gdt.KERNEL_CODE_SEL, attr);
    }
    // IDTR.limit = taulukon koko - 1.
    idt_ptr.limit = @sizeOf(@TypeOf(idt)) - 1;
    // IDTR.base = IDT-taulukon osoite.
    idt_ptr.base = @intFromPtr(&idt);
    // Lataa IDT CPU:hen.
    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (&idt_ptr),
    );
}
