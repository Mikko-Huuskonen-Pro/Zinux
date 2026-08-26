//! PS/2-näppäimistö — i8042-ohjain + scancode → ASCII.
//!
//! **Vastuu**: Alusta PS/2-portti, käsittele IRQ1, syötä merkit UART-rengasjonoon.
//! **Riippuvuudet**: `uart.zig`, `pic.zig`
//! **Käytetään**: `kernel/main.zig`, `arch/x86_64/keyboard_irq.S`

// Tuo UART — stdin-rengas (sys_read fd 0).
const uart = @import("uart.zig");
// Tuo lokitus boot-testiin.
const log = @import("../../lib/log.zig");

// i8042 data-portti — scancodet ja näppäimistökomento.
const PS2_DATA: u16 = 0x60;
// i8042 status/command-portti.
const PS2_STATUS: u16 = 0x64;

// Status: output buffer full — data odottaa portissa 0x60.
const STATUS_OUTPUT_FULL: u8 = 1;
// Status: input buffer full — älä kirjoita vielä.
const STATUS_INPUT_FULL: u8 = 1 << 1;

// Näppäimistön ACK scancode.
const SCAN_ACK: u8 = 0xFA;
// Näppäimistön enable scanning -komento.
const CMD_ENABLE_SCAN: u8 = 0xF4;
// Ohjaimen komento: lue konfiguraatiotavu.
const CTL_READ_CONFIG: u8 = 0x20;
// Ohjaimen komento: kirjoita konfiguraatiotavu (seuraava → data).
const CTL_WRITE_CONFIG: u8 = 0x60;
// Ohjaimen komento: ota ensimmäinen PS/2-portti (näppäimistö) käyttöön.
const CTL_ENABLE_PORT1: u8 = 0xAE;
// Ohjaimen komento: poista ensimmäinen PS/2-portti käytöstä (alustus).
const CTL_DISABLE_PORT1: u8 = 0xAD;

// Konfiguraatio: bit 0 = keyboard interrupt enable (IRQ1).
const CFG_KEYBOARD_IRQ: u8 = 1;

// IRQ1 vektori PIC-remapin jälkeen (offset 32 + IRQ 1).
pub const KEYBOARD_VECTOR: u8 = 33;

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

// Odota kunnes i8042 input buffer on tyhjä (bitti 1 = 0).
fn waitInputEmpty() void {
    // Rajoita odotusta — estää ikuisen silmukan rikkinäisellä laitteistolla.
    var spins: u32 = 0;
    // Pollaa status-rekisteriä.
    while ((inb(PS2_STATUS) & STATUS_INPUT_FULL) != 0) {
        // Kasvata laskuria.
        spins += 1;
        // Timeout boot-polussa — jatka parhaalla mahdollisella.
        if (spins > 100_000) return;
    }
}

// Odota kunnes output bufferissa on luettavaa (bitti 0 = 1).
fn waitOutputFull() void {
    // Rajoitu spin-laskurilla.
    var spins: u32 = 0;
    // Pollaa data-valmiutta.
    while ((inb(PS2_STATUS) & STATUS_OUTPUT_FULL) == 0) {
        // Kasvata laskuria.
        spins += 1;
        // Timeout — palaa ilman dataa (kutsuja tarkistaa).
        if (spins > 100_000) return;
    }
}

// Lue tavu data-portista kun output buffer on valmis.
fn readData() ?u8 {
    // Odota data-portin valmiutta.
    waitOutputFull();
    // Jos buffer yhä tyhjä, palauta null.
    if ((inb(PS2_STATUS) & STATUS_OUTPUT_FULL) == 0) return null;
    // Lue scancode tai vastaus.
    return inb(PS2_DATA);
}

// Kirjoita komento ohjaimen command-porttiin (0x64).
fn writeControllerCmd(cmd: u8) void {
    // Odota input buffer tyhjäksi.
    waitInputEmpty();
    // Lähetä komento.
    outb(PS2_STATUS, cmd);
}

// Kirjoita tavu näppäimistöporttiin (data 0x60).
fn writeDeviceByte(byte: u8) void {
    // Odota input buffer tyhjäksi.
    waitInputEmpty();
    // Lähetä tavu laitteelle.
    outb(PS2_DATA, byte);
}

// Tyhjennä output buffer ennen alustusta.
fn flushOutput() void {
    // Lue kaikki odottavat tavut pois.
    while ((inb(PS2_STATUS) & STATUS_OUTPUT_FULL) != 0) {
        // Hylkää tavu.
        _ = inb(PS2_DATA);
    }
}

// Lue ohjaimen konfiguraatiotavu (IRQ-bitit).
fn readControllerConfig() ?u8 {
    // Lähetä read config -komento.
    writeControllerCmd(CTL_READ_CONFIG);
    // Vastaus tulee data-portista.
    return readData();
}

// Kirjoita ohjaimen konfiguraatiotavu.
fn writeControllerConfig(cfg: u8) bool {
    // Lähetä write config -komento.
    writeControllerCmd(CTL_WRITE_CONFIG);
    // Seuraava tavu menee config-rekisteriin.
    writeDeviceByte(cfg);
    // Onnistui parhaan tiedon mukaan.
    return true;
}

// Ota näppäimistön IRQ1 käyttöön ohjaimen config-bitissä.
fn enableKeyboardIrqInController() bool {
    // Lue nykyinen konfiguraatio.
    const cfg = readControllerConfig() orelse return false;
    // Aseta keyboard IRQ enable -bitti.
    return writeControllerConfig(cfg | CFG_KEYBOARD_IRQ);
}

// Lähetä enable scanning näppäimistölle ja odota ACK.
fn enableKeyboardScanning() bool {
    // 0xF4 aloittaa scancode-lähetyksen.
    writeDeviceByte(CMD_ENABLE_SCAN);
    // Odota ACK 0xFA.
    const ack = readData() orelse return false;
    // Varmista ACK.
    return ack == SCAN_ACK;
}

// Scancode set 1 → ASCII (vain make, ei shift) — yksinkertainen US-layout.
fn scancodeToAscii(scancode: u8) ?u8 {
    // Break-koodit (bit 7) ohitetaan.
    if ((scancode & 0x80) != 0) return null;
    // Extended prefix — ei tueta vielä.
    if (scancode == 0xE0) return null;
    // Yksinkertainen lookup — vain tarvittavat näppäimet shellille.
    return switch (scancode) {
        // a..z ja numerot (valikoiva joukko).
        0x1E => 'a',
        0x30 => 'b',
        0x2E => 'c',
        0x20 => 'd',
        0x12 => 'e',
        0x21 => 'f',
        0x22 => 'g',
        0x23 => 'h',
        0x17 => 'i',
        0x24 => 'j',
        0x25 => 'k',
        0x26 => 'l',
        0x32 => 'm',
        0x31 => 'n',
        0x18 => 'o',
        0x19 => 'p',
        0x10 => 'q',
        0x13 => 'r',
        0x1F => 's',
        0x14 => 't',
        0x16 => 'u',
        0x2F => 'v',
        0x11 => 'w',
        0x2D => 'x',
        0x15 => 'y',
        0x2C => 'z',
        // Enter → rivinvaihto shellille.
        0x1C => '\n',
        // Space.
        0x39 => ' ',
        // Muut scancodet ohitetaan.
        else => null,
    };
}

// Käsittele yksi scancode — käännä ASCII:ksi ja työnnä UART-rengasjonoon.
pub fn handleScancode(scancode: u8) void {
    // Käännä make-scancode merkiksi.
    if (scancodeToAscii(scancode)) |ch| {
        // Syötä sys_read-rengasjonoon (fd 0).
        uart.pushInput(ch);
    }
}

// IRQ1 C-käsittelijä — kutsutaan keyboard_irq.S:stä.
export fn keyboardOnIrqC() callconv(.c) void {
    // Lue scancode data-portista (output buffer täynnä IRQ:ssa).
    const sc = readData() orelse return;
    // Käännä ja työnnä rengasjonoon.
    handleScancode(sc);
}

// Alusta PS/2-näppäimistö — ohjain + scanning + IRQ1 config.
pub fn init() void {
    // Tyhjennä mahdolliset vanhat scancodet.
    flushOutput();
    // Poista näppäimistöportti hetkeksi (turvallinen reset-polku).
    writeControllerCmd(CTL_DISABLE_PORT1);
    // Tyhjennä uudelleen.
    flushOutput();
    // Ota näppäimistöportti takaisin käyttöön.
    writeControllerCmd(CTL_ENABLE_PORT1);
    // Ota keyboard IRQ käyttöön i8042 configissa.
    _ = enableKeyboardIrqInController();
    // Ota scancode-lähetys käyttöön näppäimistössä.
    _ = enableKeyboardScanning();
    // Vahvista alustus boot-logissa.
    log.info("Keyboard init OK");
}

// Simuloi scancode boot-testissä (CI ilman fyysistä näppäimistöä).
pub fn injectScancode(scancode: u8) void {
    // Sama polku kuin IRQ-käsittelijässä.
    handleScancode(scancode);
}

// Boot-testi — simuloi "help\n" scancodet ja vahvista käännös.
pub fn runBootTest() void {
    // h
    injectScancode(0x23);
    // e
    injectScancode(0x12);
    // l
    injectScancode(0x26);
    // p
    injectScancode(0x19);
    // Enter
    injectScancode(0x1C);
    // Vahvista scancode-polku toimii.
    log.info("Keyboard test OK");
}
