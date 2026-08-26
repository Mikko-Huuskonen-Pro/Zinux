//! Kernel-lokitus — serial (UART) ja VGA text mode -tulostus.
//!
//! **Vastuu**: Muotoile ja tulosta lokiviestit debuggausta varten.
//! **Riippuvuudet**: `../boot/limine.zig` (BootInfo)
//! **Käytetään**: Kaikki kernel-moduulit

// Tuo BootInfo-tyyppi limine-moduulista.
const limine = @import("../boot/limine.zig");

// Sisäinen tila — onko lokitus alustettu.
var initialized: bool = false;
// Tallennettu boot-info alustuksen jälkeen (tuleva: valitse UART vs VGA).
var stored_boot_info: limine.BootInfo = undefined;

// Alusta lokitusmoduuli boot-tiedoilla.
pub fn init(boot_info: limine.BootInfo) void {
    // Tallenna boot-info myöhempää ajurivalintaa varten.
    stored_boot_info = boot_info;
    // Merkitse lokitus valmiiksi — info/kwarn/error voivat tulostaa.
    initialized = true;
    // Vältä unused-varoitus kunnes UART/VGA ajurit toteutetaan Vaihe 1:ssä.
    _ = stored_boot_info;
}

// Tulosta informatiivinen lokiviesti (taso: INFO).
pub fn info(comptime msg: []const u8) void {
    // Varmista että init() on kutsuttu ennen tulostusta.
    if (!initialized) return;
    // Tuleva Vaihe 1: kirjoita msg UART/VGA:han sellaisenaan.
    // Toistaiseksi: comptime-varmistus että viesti on olemassa compile-time.
    _ = msg;
    // Placeholder — oikea tulostus tulee kun uart.zig / vga.zig on valmis.
}

// Tulosta varoitusviesti (taso: WARN).
pub fn warn(comptime msg: []const u8) void {
    // Sama kuin info mutta eri etuliite tulevaisuudessa.
    if (!initialized) return;
    _ = msg;
}

// Tulosta virheviesti (taso: ERROR).
pub fn err(comptime msg: []const u8) void {
    // Sama kuin info mutta eri etuliite tulevaisuudessa.
    if (!initialized) return;
    _ = msg;
}
