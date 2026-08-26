//! Muistinhallinnan alustus Limine-tiedoista.
//!
//! **Vastuu**: Muunna Limine memory map → PMM MapEntry.
//! **Riippuvuudet**: `limine_protocol.zig`, `../mm/pmm.zig`
//! **Käytetään**: `kernel/main.zig` kmain-alustuksessa

// Tuo Limine-muistikartan tyypit (MemoryMapEntry, MemoryMapType).
const limine = @import("limine_protocol.zig");
// Tuo PMM-moduuli bitmap-allokaattorin alustukseen.
const pmm = @import("../mm/pmm.zig");

// Muunna Limine-muistikarta PMM:n MapEntry-muotoon (max 64 entryä).
pub fn initPmmFromLimine(entries: []*limine.MemoryMapEntry) void {
    // Paikallinen taulukko PMM:n yksinkertaistetuille kartta-entryille.
    var map: [64]pmm.MapEntry = undefined;
    // Rajaa entryjen määrä taulukon kokoon (Limine voi antaa enemmän).
    const count = @min(entries.len, map.len);
    // Käy jokainen Limine-entry ja muunna PMM-muotoon.
    for (0..count) |i| {
        // Kopioi base, length ja usable-lippu Limine-tyypistä.
        map[i] = .{
            // Fyysinen alkuosoite tälle muistialueelle.
            .base = entries[i].base,
            // Alueen pituus tavuina.
            .length = entries[i].length,
            // Merkitse usable vain jos Limine kertoo type == usable.
            .usable = entries[i].type == .usable,
        };
    }
    // Alusta PMM bitmap kaikista konvertoiduista entryistä.
    pmm.initFromMap(map[0..count]);
}
