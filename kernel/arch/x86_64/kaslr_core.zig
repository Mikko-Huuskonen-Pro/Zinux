//! KASLR-ydin — kernel heap -slide laskenta (host-testattava).
//!
//! **Vastuu**: Satunnainen 2 MiB -slide kernel heap -alueelle linkki-originiin.
//! **Riippuvuudet**: ei
//! **Käytetään**: `kaslr.zig`, host-testit

// Kernelin linkitysosoite linker.ld:stä (Limine higher-half).
pub const LINK_BASE: u64 = 0xFFFFFFFF80000000;
// User/heap-alueen kiinteä linkitysalku (user-ELF:ien abs-osoitteet).
pub const USER_REGION_ORIGIN: u64 = 0xFFFFFFFF90000000;
// Minimi slide — 2 MiB pitää kernel heapin user-ELF-alueen yläpuolella.
pub const MIN_SLIDE: u64 = SLIDE_ALIGN;
// Slide tasaus — 2 MiB vastaa Liminen huge-page -käytäntöä.
pub const SLIDE_ALIGN: u64 = 2 * 1024 * 1024;
// Montako 2 MiB askelta (max slide = (SLOTS-1) * ALIGN = 510 MiB).
pub const SLIDE_SLOTS: u64 = 256;

// Sekoita boot-entropia (RDTSC + HHDM + Limine virtual_base).
pub fn mixEntropy(rdtsc: u64, hhdm: u64, exe_virt: u64) u64 {
    // Aloita kolmen lähteen XOR:lla.
    var x = rdtsc ^ hhdm ^ exe_virt;
    // SplitMix64-tyylinen sekoitus — levittää bitit.
    x ^= x >> 33;
    // Kerro suurella parittomalla luvulla.
    x = x *% 0xff51afd7ed558ccd;
    // Toinen sekoituskierros.
    x ^= x >> 33;
    // Toinen kerroin.
    x = x *% 0xc4ceb9fe1a85ec53;
    // Lopullinen sekoitus.
    x ^= x >> 33;
    // Palauta sekoitettu entropia.
    return x;
}

// Laske slide entropiasta — aina vähintään yksi 2 MiB askel.
pub fn computeSlide(entropy: u64) u64 {
    // Slot 1..SLIDE_SLOTS-1 — ei nollaslidea (KASLR vaatii siirron).
    const slot = (entropy % (SLIDE_SLOTS - 1)) + 1;
    // Palauta tasaus × slot.
    return slot * SLIDE_ALIGN;
}

// Kernel heapin runtime-alku slide:n jälkeen.
pub fn heapBase(slide: u64) u64 {
    // Kiinteä origin + satunnainen slide.
    return USER_REGION_ORIGIN + slide;
}

// Siirrä linkitys-vaddr runtime-osoitteeksi slide:lla.
pub fn relocUserVirt(fixed: u64, slide: u64) u64 {
    // Osoitteet user-alueen alapuolella pysyvät (kernel higher-half).
    if (fixed < USER_REGION_ORIGIN) return fixed;
    // User-alueen osoitteet siirtyvät slide:n verran.
    return fixed + slide;
}

// Onko slide kelvollinen KASLR:ia varten?
pub fn slideOk(slide: u64) bool {
    // Ei nollaa, tasaus 2 MiB.
    return slide > 0 and slide % SLIDE_ALIGN == 0;
}
