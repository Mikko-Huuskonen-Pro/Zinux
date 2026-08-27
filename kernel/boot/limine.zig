//! Limine boot-tietojen luku.

const limine = @import("limine_protocol.zig");
const requests = @import("requests.zig");

extern var limine_requests: requests.LimineRequests;

pub const BootInfo = struct {
    valid: bool,
    hhdm_offset: u64,
    framebuffer_addr: u64,
    framebuffer_width: u64,
    framebuffer_height: u64,
};

pub fn isBootValid() bool {
    if (!limine_requests.base.isValid()) return false;
    if (limine_requests.hhdm.response == null) return false;
    return true;
}

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

// Palauta Limine executable virtual_base tai link-osoite jos pyyntö puuttuu.
pub fn getExecutableVirtualBase(default: u64) u64 {
    // Executable address -vastaus Limine 12.x.
    const resp = limine_requests.executable_addr.response orelse return default;
    // Bootloaderin raportoima virtual_base.
    return resp.virtual_base;
}

// Palauta Limine-muistikartta tai null jos puuttuu.
pub fn getMemoryMapEntries() ?[]*limine.MemoryMapEntry {
    const resp = limine_requests.memmap.response orelse return null;
    return resp.getEntries();
}
