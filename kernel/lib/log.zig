//! Kernel-lokitus — serial (UART) ja VGA text mode -tulostus.
//!
//! **Vastuu**: Muotoile ja tulosta lokiviestit debuggausta varten.
//! **Riippuvuudet**: `../boot/limine.zig`, `../drivers/char/uart.zig`, `../drivers/video/vga.zig`
//! **Käytetään**: Kaikki kernel-moduulit

// Tuo BootInfo boot-tiedoille (käytetään tulevaisuudessa framebuffer-logiikkaan).
const limine = @import("../boot/limine.zig");
// Tuo COM1 UART -ajuri serial-tulostusta varten.
const uart = @import("../drivers/char/uart.zig");
// Tuo VGA text mode -ajuri näyttötulostusta varten.
const vga = @import("../drivers/video/vga.zig");

// Sisäinen tila — onko lokitus alustettu.
var initialized: bool = false;
// Tallennettu boot-info (framebuffer vs VGA -valinta tulevaisuudessa).
var stored_boot_info: limine.BootInfo = undefined;

// Alusta lokitus: UART 115200 baud + VGA tyhjennys.
pub fn init(boot_info: limine.BootInfo) void {
    // Tallenna boot-info myöhempää ajurivalintaa varten.
    stored_boot_info = boot_info;
    // Alusta COM1 sarjaportti 115200 baud -nopeudella (QEMU -serial stdio).
    uart.init(115200);
    // Tyhjennä VGA text mode -näyttö ennen ensimmäistä tulostusta.
    vga.clear();
    // Merkitse lokitus valmiiksi.
    initialized = true;
    // Vältä unused-varoitus — framebuffer_addr käytetään Vaiheessa 6.
    _ = stored_boot_info;
}

// Tulosta informatiivinen lokiviesti serialiin ja VGA:han.
pub fn info(comptime msg: []const u8) void {
    // Älä tulosta ennen init():ia.
    if (!initialized) return;
    // Kirjoita viesti COM1:een.
    uart.write(msg);
    // Rivinvaihto serialissa.
    uart.putc('\n');
    // Kirjoita sama viesti VGA-näytölle.
    vga.write(msg);
    // Rivinvaihto VGA:ssa.
    vga.putc('\n');
}

// Tulosta varoitusviesti (sama kanava kuin info, etuliite tulevaisuudessa).
pub fn warn(comptime msg: []const u8) void {
    if (!initialized) return;
    uart.write("[WARN] ");
    uart.write(msg);
    uart.putc('\n');
    vga.write("[WARN] ");
    vga.write(msg);
    vga.putc('\n');
}

// Tulosta virheviesti (sama kanava kuin info, etuliite tulevaisuudessa).
pub fn err(comptime msg: []const u8) void {
    if (!initialized) return;
    uart.write("[ERR] ");
    uart.write(msg);
    uart.putc('\n');
    vga.write("[ERR] ");
    vga.write(msg);
    vga.putc('\n');
}
