//! UART COM1 -sarjaportti-ajuri (16550A-yhteensopiva).
//!
//! **Vastuu**: Alusta COM1 @ 0x3F8 ja tulosta merkkejä debug-lokitusta varten.
//! **Riippuvuudet**: ei (vain inline port I/O)
//! **Käytetään**: `lib/log.zig`, integraatiotestit ("Zinux boot OK" serialissa)

// COM1 I/O-portin kantaosoite x86_64:ssä.
pub const COM1: u16 = 0x3F8;

// Rekisteri-offsetit COM1-portista.
const REG_DATA: u16 = 0;
const REG_INTR_EN: u16 = 1;
const REG_LINE_CTRL: u16 = 3;
const REG_LINE_STAT: u16 = 5;

// Line Status Register: bitti 5 = lähetysrekisteri tyhjä (valmis uudelle tavulle).
const LSR_TX_READY: u8 = 1 << 5;
// Line Status Register: bitti 0 = vastaanotettu tavu datarekisterissä.
const LSR_DATA_READY: u8 = 1;
// Line Control Register: DLAB=1 aktivoi baud rate -jakajan rekisterit.
const LCR_DLAB: u8 = 1 << 7;

// Syöttörengas — kernel voi injektoida komentoja ennen shell-käynnistystä.
var input_ring: [256]u8 = undefined;
// Rengas lukuindeksi (vanhin tavu).
var input_head: usize = 0;
// Rengas kirjoitusindeksi (seuraava vapaa).
var input_tail: usize = 0;

// Lisää yksi tavu syöttörengaaseen (kernel → user sys_read).
pub fn pushInput(byte: u8) void {
    // Laske seuraava tail indeksi mod 256.
    const next = (input_tail + 1) % input_ring.len;
    // Rengas täynnä — pudota vanhin (head eteenpäin).
    if (next == input_head) input_head = (input_head + 1) % input_ring.len;
    // Tallenna tavu tailiin.
    input_ring[input_tail] = byte;
    // Päivitä tail.
    input_tail = next;
}

// Injektoi merkkijono syöttörengaaseen (boot-testi: "help\n").
pub fn injectInput(msg: []const u8) void {
    // Lisää jokainen tavu rengasjonoon.
    for (msg) |b| pushInput(b);
}

// Lue tavu ensin rengasjonosta, sitten laitteistosta.
fn readByte() u8 {
    // Jos rengasjonossa on dataa, palauta vanhin.
    if (input_head != input_tail) {
        // Poimi tavu headistä.
        const b = input_ring[input_head];
        // Siirrä head eteenpäin mod 256.
        input_head = (input_head + 1) % input_ring.len;
        // Palauta injektoitu tai käyttäjän tavu.
        return b;
    }
    // Odota kunnes UART datarekisterissä on tavu.
    while ((inb(COM1 + REG_LINE_STAT) & LSR_DATA_READY) == 0) {}
    // Lue tavu COM1 datarekisteristä.
    return inb(COM1 + REG_DATA);
}

// Lue yksi tavu I/O-portista — dx-rekisteri porttinumerolle (Zig 0.16).
inline fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

// Kirjoita yksi tavu I/O-porttiin — dx portti, al tavu.
inline fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

// Alusta COM1 annetulla baud rate -nopeudella (oletus 115200).
pub fn init(baud: u32) void {
    // Käytä COM1-kantaosoitetta kaikissa rekisterioperatioissa.
    const base = COM1;
    // Poista keskeytykset COM1:stä — emme käsittele UART IRQ:ta vielä.
    outb(base + REG_INTR_EN, 0);
    // Aseta DLAB=1 jotta voimme kirjoittaa baud rate -jakajan.
    outb(base + REG_LINE_CTRL, LCR_DLAB);
    // Laske jakaja: 115200 / baud (esim. 115200/115200 = 1).
    const divisor: u16 = @intCast(115200 / baud);
    // Jakajan alitavu (low byte) datarekisteriin (offset 0 DLAB=1 tilassa).
    outb(base + 0, @truncate(divisor & 0xFF));
    // Jakajan ylitavu (high byte) interrupt enable -rekisteriin.
    outb(base + 1, @truncate(divisor >> 8));
    // Palauta 8N1-moodi: 8 bittiä, ei pariteettia, 1 stop-bitti (0x03).
    outb(base + REG_LINE_CTRL, 0x03);
}

// Lähetä yksi merkki COM1:stä — odottaa kunnes lähetysrekisteri on vapaa.
pub fn putc(byte: u8) void {
    // COM1-kantaosoite.
    const base = COM1;
    // Odota kunnes LSR TX_READY -bitti on 1 (lähetys valmis).
    while ((inb(base + REG_LINE_STAT) & LSR_TX_READY) == 0) {}
    // Kirjoita tavu datarekisteriin — lähtee sarjaportista.
    outb(base + REG_DATA, byte);
}

// Lähetä merkkijono tavu kerrallaan COM1:stä.
pub fn write(msg: []const u8) void {
    // Käy jokainen merkki läpi ja lähetä putc:llä.
    for (msg) |b| putc(b);
}

// Lue yksi tavu stdin:stä (rengas + UART, blokkaava).
pub fn readc() u8 {
    // Delegoi readByte:lle.
    return readByte();
}
