//! Limine boot-tietojen luku — käärii limine-zig vastaukset BootInfo-rakenteeksi.
//!
//! **Vastuu**: Validoi Limine-vastaukset, tarjoa yksinkertainen BootInfo-API.
//! **Riippuvuudet**: `limine`-paketti, `requests.zig` exportit
//! **Käytetään**: `boot/entry.zig`, ajurit

// Tuo vendoroitu Limine-protokolla.
const limine = @import("limine_protocol.zig");

// Viittaa requests.zig:ssä exportattuihin globaaleihin — Limine täyttää ne.
extern var base_revision: limine.BaseRevision;
extern var hhdm_request: limine.HhdmRequest;
extern var framebuffer_request: limine.FramebufferRequest;

// Yksinkertaistettu boot-info jota muu kernel käyttää.
pub const BootInfo = struct {
    // Onko kaikki pakolliset Limine-vastaukset saatu.
    valid: bool,
    // HHDM-offset: virtuaali = fysinen + offset.
    hhdm_offset: u64,
    // Framebufferin virtuaaliosoite (0 jos ei saatavilla).
    framebuffer_addr: u64,
    // Framebuffer leveys pikseleinä.
    framebuffer_width: u64,
    // Framebuffer korkeus pikseleinä.
    framebuffer_height: u64,
};

// Palauta true jos Limine boot on kelvollinen ja kernel voi jatkaa.
pub fn isBootValid() bool {
    // Limine on kirjoittanut base_revision-magicin — tarkista validius.
    if (!base_revision.isValid()) return false;
    // HHDM on pakollinen higher-half kernelille — response pitää olla olemassa.
    if (hhdm_request.response == null) return false;
    // Kaikki pakolliset tarkistukset läpi.
    return true;
}

// Kerää BootInfo-rakenne Limine-vastauksista.
pub fn getBootInfo() BootInfo {
    // Alusta oletusarvoilla — valid=false kunnes kaikki tiedot kerätty.
    var info: BootInfo = .{
        .valid = false,
        .hhdm_offset = 0,
        .framebuffer_addr = 0,
        .framebuffer_width = 0,
        .framebuffer_height = 0,
    };
    // Jos boot ei ole validi, palauta tyhjä info heti.
    if (!isBootValid()) return info;
    // Lue HHDM-offset vastauksesta — unwrap turvallinen isBootValid():n jälkeen.
    info.hhdm_offset = hhdm_request.response.?.offset;
    // Framebuffer on valinnainen — tarkista onko Limine antanut sen.
    if (framebuffer_request.response) |fb_resp| {
        // Hae framebuffer-taulukko Limine-vastauksesta.
        const fbs = fb_resp.getFramebuffers();
        // Jos vähintään yksi framebuffer on saatavilla, tallenna ensimmäisen tiedot.
        if (fbs.len > 0) {
            info.framebuffer_addr = @intFromPtr(fbs[0].address);
            info.framebuffer_width = fbs[0].width;
            info.framebuffer_height = fbs[0].height;
        }
    }
    // Merkitse boot kelvolliseksi — kaikki pakolliset tiedot kerätty.
    info.valid = true;
    return info;
}
