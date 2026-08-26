//! Limine boot-tietojen luku — käärii Limine-vastaukset BootInfo-rakenteeksi.
//!
//! **Vastuu**: Validoi Limine-vastaukset, tarjoa yksinkertainen BootInfo-API.
//! **Riippuvuudet**: `limine_protocol.zig`, `requests.zig`
//! **Käytetään**: `boot/entry.zig`, ajurit

const limine = @import("limine_protocol.zig");
const requests = @import("requests.zig");

// Viittaa requests.zig:ssä exportattuun structiin — Limine täyttää response-kentät.
extern var limine_requests: requests.LimineRequests;

// Yksinkertaistettu boot-info jota muu kernel käyttää.
pub const BootInfo = struct {
    valid: bool,
    hhdm_offset: u64,
    framebuffer_addr: u64,
    framebuffer_width: u64,
    framebuffer_height: u64,
};

// Palauta true jos Limine boot on kelvollinen ja kernel voi jatkaa.
pub fn isBootValid() bool {
    // Limine on kirjoittanut base_revision-magicin — tarkista validius.
    if (!limine_requests.base.isValid()) return false;
    // HHDM on pakollinen higher-half kernelille.
    if (limine_requests.hhdm.response == null) return false;
    return true;
}

// Kerää BootInfo-rakenne Limine-vastauksista.
pub fn getBootInfo() BootInfo {
    var info: BootInfo = .{
        .valid = false,
        .hhdm_offset = 0,
        .framebuffer_addr = 0,
        .framebuffer_width = 0,
        .framebuffer_height = 0,
    };
    if (!isBootValid()) return info;
    info.hhdm_offset = limine_requests.hhdm.response.?.offset;
    if (limine_requests.fb.response) |fb_resp| {
        const fbs = fb_resp.getFramebuffers();
        if (fbs.len > 0) {
            info.framebuffer_addr = @intFromPtr(fbs[0].address);
            info.framebuffer_width = fbs[0].width;
            info.framebuffer_height = fbs[0].height;
        }
    }
    info.valid = true;
    return info;
}
