//! SMEP/SMAP-ydin — CPUID-tunnistus ja CR4-bitit (host-testattava).
//!
//! **Vastuu**: Puhdas logiikka SMEP/SMAP-tuelle ilman inline asm.
//! **Riippuvuudet**: ei
//! **Käytetään**: `hardening.zig`, host-testit

// CR4.SMEP — bit 20, estää user-sivujen suoritus kernel-tilassa.
pub const CR4_SMEP: u64 = 1 << 20;
// CR4.SMAP — bit 21, estää user-sivujen datan käytön kernel-tilassa.
pub const CR4_SMAP: u64 = 1 << 21;
// CPUID leaf 7 — strukturoidut laajennetut ominaisuudet (EBX).
pub const CPUID_LEAF_EXT_FEATURES: u32 = 7;
// EBX bit 7 — SMEP tuettu.
pub const EBX_SMEP_BIT: u5 = 7;
// EBX bit 20 — SMAP tuettu.
pub const EBX_SMAP_BIT: u5 = 20;

// Aktivoinnin tulos boot-logia varten.
pub const HardeningState = struct {
    // CPU tukee SMEP:ää (CPUID.7:EBX bit 7).
    smep_supported: bool,
    // CPU tukee SMAP:ia (CPUID.7:EBX bit 20).
    smap_supported: bool,
    // CR4.SMEP asetettu.
    smep_enabled: bool,
    // CR4.SMAP asetettu.
    smap_enabled: bool,
};

// Tarkista SMEP-tuki extended features EBX:stä.
pub fn smepSupported(ext_features_ebx: u32) bool {
    // Bit 7 asetettu → SMEP tuettu.
    return (ext_features_ebx & (@as(u32, 1) << EBX_SMEP_BIT)) != 0;
}

// Tarkista SMAP-tuki extended features EBX:stä.
pub fn smapSupported(ext_features_ebx: u32) bool {
    // Bit 20 asetettu → SMAP tuettu.
    return (ext_features_ebx & (@as(u32, 1) << EBX_SMAP_BIT)) != 0;
}

// Laske uusi CR4 OR-aten SMEP/SMAP-bitit jos tuettu.
pub fn cr4WithHardening(current: u64, ext_features_ebx: u32) u64 {
    // Aloita nykyisestä CR4:stä.
    var next = current;
    // Aseta SMEP jos tuettu.
    if (smepSupported(ext_features_ebx)) next |= CR4_SMEP;
    // Aseta SMAP jos tuettu.
    if (smapSupported(ext_features_ebx)) next |= CR4_SMAP;
    // Palauta ehdotettu CR4.
    return next;
}

// Muodosta HardeningState CPUID EBX:stä ja CR4:stä aktivoinnin jälkeen.
pub fn makeState(ext_features_ebx: u32, cr4_after: u64) HardeningState {
    // CPUID-tuki.
    const smep_sup = smepSupported(ext_features_ebx);
    const smap_sup = smapSupported(ext_features_ebx);
    // Palauta tila vertaamalla CR4-bittejä.
    return .{
        .smep_supported = smep_sup,
        .smap_supported = smap_sup,
        .smep_enabled = smep_sup and (cr4_after & CR4_SMEP) != 0,
        .smap_enabled = smap_sup and (cr4_after & CR4_SMAP) != 0,
    };
}

// Onko aktivointi onnistunut (tuettu → myös enabled)?
pub fn activationOk(state: HardeningState) bool {
    // SMEP tuettu vaatii enabled.
    if (state.smep_supported and !state.smep_enabled) return false;
    // SMAP tuettu vaatii enabled.
    if (state.smap_supported and !state.smap_enabled) return false;
    // OK — ei tuettuja tai kaikki enabled.
    return true;
}
