//! 8259 PIC — keskeytysohjaimen uudelleenmapitus x86_64:ssa.
//!
//! **Vastuu**: Remapaa IRQ 0..15 vektoreihin 32..47, EOI.
//! **Riippuvuudet**: ei
//! **Käytetään**: `idt.zig`, `pit.zig`, `scheduler.zig`

// Master PIC command/data -portit.
const PIC1_CMD: u16 = 0x20;
const PIC1_DATA: u16 = 0x21;
// Slave PIC command/data -portit.
const PIC2_CMD: u16 = 0xA0;
const PIC2_DATA: u16 = 0xA1;

// ICW1: aloita alustussekvenssi.
const ICW1_INIT: u8 = 0x11;
// ICW4: 8086/88 -tila (ei MCS-85).
const ICW4_8086: u8 = 0x01;

// Lue yksi tavu I/O-portista.
inline fn inb(port: u16) u8 {
    // inb dx → al.
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

// Kirjoita yksi tavu I/O-porttiin.
inline fn outb(port: u16, value: u8) void {
    // outb al → dx.
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

// Odota lyhyesti PIC:n välissä (vanhat laitteet vaativat).
fn ioWait() void {
    // Tyhjä I/O outb porttiin 0x80 — klassinen delay.
    outb(0x80, 0);
}

// Remapaa PIC master/slave IRQ:t vektoreihin offset..offset+15.
pub fn remap(offset: u8) void {
    // Tallenna nykyiset maskit — palautetaan remappingin jälkeen.
    const mask1 = inb(PIC1_DATA);
    // Slave PIC maski.
    const mask2 = inb(PIC2_DATA);

    // Master ICW1: aloita alustus.
    outb(PIC1_CMD, ICW1_INIT);
    // Slave ICW1: aloita alustus.
    outb(PIC2_CMD, ICW1_INIT);
    // Odota PIC:n sisäistä alustusta.
    ioWait();
    // Master ICW2: IRQ 0..7 → offset..offset+7.
    outb(PIC1_DATA, offset);
    // Slave ICW2: IRQ 8..15 → offset+8..offset+15.
    outb(PIC2_DATA, offset + 8);
    // Odota.
    ioWait();
    // Master ICW3: slave on kytketty linjaan 2 (bit 2).
    outb(PIC1_DATA, 0x04);
    // Slave ICW3: cascade identity 2.
    outb(PIC2_DATA, 0x02);
    // Odota.
    ioWait();
    // Master ICW4: 8086-tila.
    outb(PIC1_CMD, ICW4_8086);
    // Slave ICW4: 8086-tila.
    outb(PIC2_CMD, ICW4_8086);

    // Palauta alkuperäiset maskit (käytössä remappingin jälkeen).
    outb(PIC1_DATA, mask1);
    // Slave maski.
    outb(PIC2_DATA, mask2);
}

// Salli yksittäinen IRQ (0..15) poistamalla maski.
pub fn unmaskIrq(irq: u8) void {
    // Master PIC hoitaa IRQ 0..7.
    if (irq < 8) {
        // Lue nykyinen master maski.
        const mask = inb(PIC1_DATA);
        // Poista maski bitistä irq (0 = sallittu).
        outb(PIC1_DATA, mask & ~(@as(u8, 1) << @intCast(irq)));
    } else {
        // Slave PIC hoitaa IRQ 8..15.
        const slave_irq = irq - 8;
        // Lue slave maski.
        const mask = inb(PIC2_DATA);
        // Poista maski.
        outb(PIC2_DATA, mask & ~(@as(u8, 1) << @intCast(slave_irq)));
    }
}

// Lähetä End Of Interrupt — pakollinen IRQ-käsittelijän lopussa.
pub fn sendEoi(irq: u8) void {
    // Slave PIC tarvitsee EOI:n jos IRQ >= 8.
    if (irq >= 8) {
        // EOI slave PIC:lle.
        outb(PIC2_CMD, 0x20);
    }
    // EOI master PIC:lle aina.
    outb(PIC1_CMD, 0x20);
}

// Timer IRQ 0 vektori remappingin jälkeen (offset 32 + IRQ 0).
pub const TIMER_VECTOR: u8 = 32;
