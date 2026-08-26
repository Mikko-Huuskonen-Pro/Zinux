//! Limine bootloader -protokollan sidonta.
//!
//! **Vastuu**: Lue Limine request/response -rakenteet, tarjoa boot-info API.
//! **Riippuvuudet**: ei (vain freestanding tyypit)
//! **Käytetään**: `boot/entry.zig`, ajurit (framebuffer, SMP)
//!
//! ## Huomio
//! Täysi Limine-sidonta tulee Vaihe 1:ssä. Tämä on placeholder joka
//! palauttaa stub-arvoja kunnes `limine-zig`-kirjasto tai oma sidonta lisätään.

// Boot-tiedot joita Limine antaa kernelille — yksinkertaistettu rakenne.
pub const BootInfo = struct {
    // Onko Limine vastannut kaikkiin requesteihin onnistuneesti.
    valid: bool,
    // Higher-half direct map -offset: fysinen → virtuaalinen osoitemuunnos.
    hhdm_offset: u64,
    // Framebuffer-osoite (0 jos ei saatavilla).
    framebuffer_addr: u64,
    // Framebuffer leveys pikseleinä.
    framebuffer_width: u64,
    // Framebuffer korkeus pikseleinä.
    framebuffer_height: u64,
};

// Staattinen boot-info stub — korvataan oikealla Limine-vastauksella Vaihe 1:ssä.
var boot_info: BootInfo = .{
    .valid = true,
    .hhdm_offset = 0,
    .framebuffer_addr = 0,
    .framebuffer_width = 0,
    .framebuffer_height = 0,
};

// Palauta true jos Limine boot on validi ja kernel voi jatkaa.
pub fn isBootValid() bool {
    // Lue valid-lippu boot_info-rakenteesta.
    return boot_info.valid;
}

// Palauta kopio boot-tiedoista — caller saa omistetun arvon (POD-tyyppi).
pub fn getBootInfo() BootInfo {
    // Palauta koko BootInfo-rakenne arvona (ei osoitinta — turvallisempi early bootissa).
    return boot_info;
}
