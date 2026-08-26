//! PCI-väylän skannaus — x86 I/O-portit 0xCF8/0xCFC.
//!
//! **Vastuu**: Lue konfiguraatioavaruus, kerää laitelista, boot-testi.
//! **Riippuvuudet**: `../../lib/log.zig`, inline port I/O
//! **Käytetään**: `kernel/main.zig`, tuleva VirtIO-ajuri (6.2)

// Tuo lokitus boot-viesteihin.
const log = @import("../../lib/log.zig");
// Tuo UART suoraan heksadesimaalitulostukseen.
const uart = @import("../char/uart.zig");

// PCI CONFIG_ADDRESS -portti — valitsee konfiguraatioavaruuden osoitteen.
const PCI_CONFIG_ADDRESS: u16 = 0xCF8;
// PCI CONFIG_DATA -portti — 32-bittinen luku/kirjoitus valittuun offsetiin.
const PCI_CONFIG_DATA: u16 = 0xCFC;

// Tyhjä väylä / ei laitetta — vendor ID 0xFFFF.
const VENDOR_NONE: u16 = 0xFFFF;
// VirtIO PCI -vendor (QEMU block/net) — tunnistetaan boot-logissa.
const VENDOR_VIRTIO: u16 = 0x1AF4;

// Montako PCI-laitetta tallennetaan (riittää QEMU boot-scanille).
pub const MAX_DEVICES: usize = 32;
// Skannattavien väylänumeroiden yläraja (exclusive) — ei kaikkia 256.
const MAX_BUS: u8 = 8;

// PCI-laitteen osoite väylällä (bus, device, function).
pub const PciAddress = struct {
    // Väylänumero (0..255).
    bus: u8,
    // Laite slot 0..31.
    device: u8,
    // Funktio 0..7 (multi-function laitteet).
    function: u8,
};

// Yksi löydetty PCI-laite konfiguraatioavaruudesta.
pub const PciDevice = struct {
    // Osoite väylällä.
    addr: PciAddress,
    // Vendor ID (offset 0x00).
    vendor_id: u16,
    // Device ID (offset 0x02).
    device_id: u16,
    // Luokkakoodi (offset 0x0B).
    class_code: u8,
    // Aliluokka (offset 0x0A).
    subclass: u8,
    // Programming interface (offset 0x09).
    prog_if: u8,
};

// Löydettyjen laitteiden taulukko boot-scanista.
var devices: [MAX_DEVICES]PciDevice = undefined;
// Montako laitetta devices-taulukossa.
var device_count: usize = 0;

// Lue 32-bittinen arvo I/O-portista.
inline fn inl(port: u16) u32 {
    // inl dx → eax.
    return asm volatile ("inl %[port], %[ret]"
        : [ret] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}

// Kirjoita 32-bittinen arvo I/O-porttiin.
inline fn outl(port: u16, value: u32) void {
    // outl eax → dx.
    asm volatile ("outl %[value], %[port]"
        :
        : [value] "{eax}" (value),
          [port] "{dx}" (port),
    );
}

// Muodosta CONFIG_ADDRESS-arvo annetulle offsetille (tasattu 4 tavuun).
fn makeConfigAddress(addr: PciAddress, offset: u8) u32 {
    // Bit 31 = enable, bus/dev/func, offset & 0xFC.
    return 0x80000000 |
        (@as(u32, addr.bus) << 16) |
        (@as(u32, addr.device) << 11) |
        (@as(u32, addr.function) << 8) |
        (@as(u32, offset) & 0xFC);
}

// Lue 32-bittinen konfiguraatioavaruuden sana.
fn readConfigDword(addr: PciAddress, offset: u8) u32 {
    // Valitse osoite CONFIG_ADDRESS-porttiin.
    outl(PCI_CONFIG_ADDRESS, makeConfigAddress(addr, offset));
    // Lue data CONFIG_DATA-portista.
    return inl(PCI_CONFIG_DATA);
}

// Lue 16-bittinen konfiguraatioavaruuden sana (vendor/device ID).
fn readConfigWord(addr: PciAddress, offset: u8) u16 {
    // Lue aligned 32-bit sana joka sisältää halutun 16-bit kentän.
    const dword = readConfigDword(addr, offset);
    // Siirrä oikea puoliword offsetin mukaan (0 tai 2).
    const shift: u5 = @intCast((offset & 2) * 8);
    // Palauta 16-bittinen kenttä.
    return @truncate(dword >> shift);
}

// Lue 8-bittinen konfiguraatioavaruuden tavu.
fn readConfigByte(addr: PciAddress, offset: u8) u8 {
    // Lue aligned 32-bit sana joka sisältää halutun tavun.
    const dword = readConfigDword(addr, offset);
    // Siirrä oikea tavu offsetin mukaan (0..3).
    const shift: u5 = @intCast((offset & 3) * 8);
    // Palauta 8-bittinen kenttä.
    return @truncate(dword >> shift);
}

// Onko header type -tavun bit 7 asetettu (multi-function laite)?
fn isMultifunction(addr: PciAddress) bool {
    // Header type offset 0x0E, bit 7 = multi-function.
    const ht = readConfigByte(addr, 0x0E);
    // Palauta MF-bit.
    return (ht & 0x80) != 0;
}

// Lisää laite devices-taulukkoon jos tilaa.
fn addDevice(entry: PciDevice) void {
    // Taulukko täynnä — ohita ylimääräiset laitteet.
    if (device_count >= MAX_DEVICES) return;
    // Tallenna merkintä.
    devices[device_count] = entry;
    // Kasvata laskuria.
    device_count += 1;
}

// Heksadesimaalimerkit yhden nibble-tulostukseen.
const HEX_DIGITS = "0123456789ABCDEF";

// Tulosta 16-bittinen arvo muodossa 0xXXXX UART:iin.
fn writeHex16(val: u16) void {
    // Etuliite.
    uart.write("0x");
    // Neljä nibbleä MSB ensin.
    var shift: u4 = 12;
    while (true) : (shift -%= 4) {
        // Poimi nibble.
        const nibble: u4 = @truncate(val >> shift);
        // Tulosta heksamerkki.
        uart.putc(HEX_DIGITS[nibble]);
        // Viimeinen nibble.
        if (shift == 0) break;
    }
}

// Tulosta desimaaliluku UART:iin (lyhyet luvut boot-logissa).
fn writeDecimal(val: usize) void {
    // Nollatapaus.
    if (val == 0) {
        // Tulosta yksi nolla.
        uart.putc('0');
        // Valmis.
        return;
    }
    // Käänteinen numeropuskuri.
    var buf: [10]u8 = undefined;
    // Kerättyjen numeroiden määrä.
    var len: usize = 0;
    // Jäännösjakoa varten.
    var n = val;
    // Kerää numerot.
    while (n > 0) : (n /= 10) {
        // ASCII-numero.
        buf[len] = @truncate('0' + (n % 10));
        // Kasvata pituus.
        len += 1;
    }
    // Tulosta oikeassa järjestyksessä.
    while (len > 0) {
        // Vähennä ennen tulostusta.
        len -= 1;
        // Yksi numero.
        uart.putc(buf[len]);
    }
}

// Skannaa yksi PCI-väylä (bus) — palauttaa löydettyjen laitteiden määrä väylältä.
fn scanBus(bus: u8) usize {
    // Laskuri tälle väylälle.
    var found: usize = 0;
    // Laite-indeksi 0..31.
    var dev: u8 = 0;
    // Käy jokainen laite-slot.
    while (dev < 32) : (dev += 1) {
        // Multi-function tunnistetaan function 0 headerista.
        var multifunction = false;
        // Funktio-indeksi 0..7.
        var func: u8 = 0;
        // Käy funktiot.
        while (func < 8) : (func += 1) {
            // Yksifunktioinen laite — vain function 0.
            if (func > 0 and !multifunction) break;
            // Muodosta osoite.
            const addr = PciAddress{ .bus = bus, .device = dev, .function = func };
            // Lue vendor ID — 0xFFFF = ei laitetta.
            const vendor = readConfigWord(addr, 0x00);
            // Tyhjä slot — seuraava funktio/slot.
            if (vendor == VENDOR_NONE) continue;
            // Function 0: tarkista multi-function -bitti.
            if (func == 0) multifunction = isMultifunction(addr);
            // Lue device ID.
            const device_id = readConfigWord(addr, 0x02);
            // Lue class / subclass / prog IF.
            const prog_if = readConfigByte(addr, 0x09);
            const subclass = readConfigByte(addr, 0x0A);
            const class_code = readConfigByte(addr, 0x0B);
            // Lisää laitelistaan.
            addDevice(.{
                .addr = addr,
                .vendor_id = vendor,
                .device_id = device_id,
                .class_code = class_code,
                .subclass = subclass,
                .prog_if = prog_if,
            });
            // Kasvata väylän laskuria.
            found += 1;
        }
    }
    // Palauta väylältä löydettyjen määrä.
    return found;
}

// Skannaa PCI-väylät 0..MAX_BUS-1 ja täytä laitelista.
pub fn scan() void {
    // Nollaa edellinen skannaus.
    device_count = 0;
    // Skannaa jokainen väylä rajattuun MAX_BUS:iin.
    var bus: u8 = 0;
    // Käy väylät.
    while (bus < MAX_BUS) : (bus += 1) {
        // Skannaa yksi väylä — tulos tallentuu devices-taulukkoon.
        _ = scanBus(bus);
    }
}

// Palauta viimeisimmän skannauksen laitemäärä.
pub fn deviceCount() usize {
    // Palauta globaalin laskurin arvo.
    return device_count;
}

// Palauta viittaus laitteisiin (slice device_count pituudella).
pub fn devicesSlice() []const PciDevice {
    // Palauta aktiivinen osuus taulukosta.
    return devices[0..device_count];
}

// Etsi ensimmäinen laite vendor ID:llä (esim. VirtIO 0x1AF4).
pub fn findByVendor(vendor_id: u16) ?PciDevice {
    // Käy kaikki löydetyt laitteet.
    for (devicesSlice()) |dev| {
        // Täsmää vendor → palauta kopio.
        if (dev.vendor_id == vendor_id) return dev;
    }
    // Ei löytynyt.
    return null;
}

// Tulosta yksi PCI-laite UART:iin (debug boot-scan).
fn logDevice(dev: PciDevice) void {
    // Otsikko riville.
    uart.write("PCI ");
    // Bus numero.
    writeDecimal(dev.addr.bus);
    // Erotin.
    uart.putc(':');
    // Device numero.
    writeDecimal(dev.addr.device);
    // Erotin.
    uart.putc('.');
    // Function numero.
    writeDecimal(dev.addr.function);
    // Vendor prefix.
    uart.write(" vid=");
    // Vendor heksana.
    writeHex16(dev.vendor_id);
    // Device prefix.
    uart.write(" did=");
    // Device heksana.
    writeHex16(dev.device_id);
    // Rivinvaihto.
    uart.putc('\n');
}

// Boot-testi — skannaa väylä, lokita laitteet, vahvista löytyi ≥1.
pub fn runBootTest() void {
    // Suorita täysi skannaus.
    scan();
    // Vähintään yksi laite vaaditaan (QEMU q35).
    if (device_count == 0) {
        // Skannaus epäonnistui tai ei laitteita.
        log.err("PCI scan found no devices");
        // Lopeta testi.
        return;
    }
    // Tulosta löydettyjen laitteiden määrä.
    log.info("PCI devices:");
    // Desimaaliluku perässä (log.info ei tulosta numeroa — UART suoraan).
    writeDecimal(device_count);
    // Rivinvaihto luvun jälkeen.
    uart.putc('\n');
    // Tulosta jokainen laite lyhyesti (max MAX_DEVICES).
    for (devicesSlice()) |dev| {
        // Yksi rivi per laite.
        logDevice(dev);
    }
    // VirtIO-laitteen tunnistus (valmistelu 6.2:lle).
    if (findByVendor(VENDOR_VIRTIO)) |_| {
        // VirtIO löytyi — hyödyllinen block-ajurille.
        log.info("PCI VirtIO device found");
    }
    // Vahvista skannaus onnistui.
    log.info("PCI scan OK");
}
