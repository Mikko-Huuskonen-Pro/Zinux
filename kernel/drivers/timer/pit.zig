//! Intel 8254 PIT — ohjelmoitava intervaliajastin (IRQ0).
//!
//! **Vastuu**: Aseta timer taajuus ja käynnistä IRQ0.
//! **Riippuvuudet**: ei
//! **Käytetään**: `scheduler.zig`, `main.zig`

// PIT I/O-portit kanavalle 0.
const PIT_CMD: u16 = 0x43;
const PIT_CH0: u16 = 0x40;

// PIT peruskellotaajuus Hz — klassinen PC-arvo.
const PIT_FREQUENCY: u32 = 1193182;

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

// Alusta PIT kanava 0 — mode 3 square wave annetulla Hz-taajuudella.
pub fn init(hz: u32) void {
    // Laske jakaja halutulle taajuudelle.
    const divisor: u16 = @intCast(PIT_FREQUENCY / hz);
    // Command byte: kanava 0, lobyte/hibyte, mode 3, binary.
    outb(PIT_CMD, 0x36);
    // Jakajan alitavu.
    outb(PIT_CH0, @truncate(divisor & 0xFF));
    // Jakajan ylitavu.
    outb(PIT_CH0, @truncate(divisor >> 8));
    // Estä unused-varoitus inb:lle tulevaisuudessa.
    _ = inb;
}
