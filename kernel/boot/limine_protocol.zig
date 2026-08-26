//! Limine bootloader -protokollan tyypit (vendoroitu limine-zig:stä).
//!
//! **Vastuu**: Request/response -rakenteet joita Limine täyttää bootissa.
//! **Riippuvuudet**: ei
//! **Käytetään**: `boot/requests.zig`, `boot/limine.zig`
//!
//! Vendoroitu jotta emme riipu limine-zig -paketin Zig-versiosta.

// Limine request ID -avain (kaikissa requesteissa yhteinen prefix).
fn id(a: u64, b: u64) [4]u64 {
    return .{ 0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, a, b };
}

// Limine request -taulukon alkumerkki.
pub const RequestsStartMarker = extern struct {
    marker: [4]u64 = .{
        0xf6b8f4b39de7d1ae,
        0xfab91a6940fcb9cf,
        0x785c6ed015d3e316,
        0x181e920a7852b9d9,
    },
};

// Limine request -taulukon loppumerkki.
pub const RequestsEndMarker = extern struct {
    marker: [2]u64 = .{ 0xadc0e0531bb10d03, 0x9572709f31764c62 },
};

// Perusprotokollaversio — kernel pyytää vähintään tätä revisiota.
pub const BaseRevision = extern struct {
    magic: [2]u64 = .{ 0xf9562b2d5c95a6c8, 0x6a7b384944536bdc },
    revision: u64,

    pub fn init(revision: u64) @This() {
        return .{ .revision = revision };
    }

    pub fn isValid(self: @This()) bool {
        return self.magic[1] != 0x6a7b384944536bdc;
    }
};

// HHDM-vastaus — higher-half direct map offset.
pub const HhdmResponse = extern struct {
    revision: u64,
    offset: u64,
};

// HHDM-pyyntö — kernel tarvitsee offsetin fys→virt muunnokseen.
pub const HhdmRequest = extern struct {
    id: [4]u64 = id(0x48dcf1cb8ad2b852, 0x63984e959a98244b),
    revision: u64 = 0,
    response: ?*HhdmResponse = null,
};

// Framebufferin muistimalli (RGB).
pub const FramebufferMemoryModel = enum(u8) {
    rgb = 1,
    _,
};

// Yksittäinen framebuffer Liminen antamana.
pub const Framebuffer = extern struct {
    address: *anyopaque,
    width: u64,
    height: u64,
    pitch: u64,
    bpp: u16,
    memory_model: FramebufferMemoryModel,
    red_mask_size: u8,
    red_mask_shift: u8,
    green_mask_size: u8,
    green_mask_shift: u8,
    blue_mask_size: u8,
    blue_mask_shift: u8,
    edid_size: u64,
    edid: ?*anyopaque,
    mode_count: u64,
    modes: [*]*VideoMode,
};

// Videotila (Limine response revision 1+).
pub const VideoMode = extern struct {
    pitch: u64,
    width: u64,
    height: u64,
    bpp: u16,
    memory_model: FramebufferMemoryModel,
    red_mask_size: u8,
    red_mask_shift: u8,
    green_mask_size: u8,
    green_mask_shift: u8,
    blue_mask_size: u8,
    blue_mask_shift: u8,
};

// Framebuffer-vastaus — taulukko framebuffer-osoittimia.
pub const FramebufferResponse = extern struct {
    revision: u64,
    framebuffer_count: u64,
    framebuffers: ?[*]*Framebuffer,

    pub fn getFramebuffers(self: @This()) []*Framebuffer {
        if (self.framebuffer_count == 0 or self.framebuffers == null) {
            return &.{};
        }
        return self.framebuffers.?[0..self.framebuffer_count];
    }
};

// Framebuffer-pyyntö — valinnainen graafinen ulostulo.
pub const FramebufferRequest = extern struct {
    id: [4]u64 = id(0x9d5827dcd881dd75, 0xa3148604f6fab11b),
    revision: u64 = 1,
    response: ?*FramebufferResponse = null,
};
