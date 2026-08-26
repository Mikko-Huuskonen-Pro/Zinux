//! Limine bootloader -protokollan tyypit (vendoroitu limine-zig:stä).
//!
//! **Vastuu**: Request/response -rakenteet joita Limine täyttää bootissa.
//! **Riippuvuudet**: ei
//! **Käytetään**: `boot/requests.zig`, `boot/limine.zig`

fn id(a: u64, b: u64) [4]u64 {
    return .{ 0xc7b1dd30df4c8b88, 0x0a82e883a194f07b, a, b };
}

pub const RequestsStartMarker = extern struct {
    marker: [4]u64 = .{
        0xf6b8f4b39de7d1ae,
        0xfab91a6940fcb9cf,
        0x785c6ed015d3e316,
        0x181e920a7852b9d9,
    },
};

pub const RequestsEndMarker = extern struct {
    marker: [2]u64 = .{ 0xadc0e0531bb10d03, 0x9572709f31764c62 },
};

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

pub const HhdmResponse = extern struct {
    revision: u64,
    offset: u64,
};

pub const HhdmRequest = extern struct {
    id: [4]u64 = id(0x48dcf1cb8ad2b852, 0x63984e959a98244b),
    revision: u64 = 0,
    response: ?*HhdmResponse = null,
};

pub const FramebufferMemoryModel = enum(u8) {
    rgb = 1,
    _,
};

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

pub const FramebufferResponse = extern struct {
    revision: u64,
    framebuffer_count: u64,
    framebuffers: ?[*]*Framebuffer,

    pub fn getFramebuffers(self: @This()) []*Framebuffer {
        if (self.framebuffer_count == 0 or self.framebuffers == null) return &.{};
        return self.framebuffers.?[0..self.framebuffer_count];
    }
};

pub const FramebufferRequest = extern struct {
    id: [4]u64 = id(0x9d5827dcd881dd75, 0xa3148604f6fab11b),
    revision: u64 = 1,
    response: ?*FramebufferResponse = null,
};

// Muistikartan tyyppi — Limine MemoryMapEntry.type (v2).
pub const MemoryMapType = enum(u64) {
    usable = 0,
    reserved = 1,
    acpi_reclaimable = 2,
    acpi_nvs = 3,
    bad_memory = 4,
    bootloader_reclaimable = 5,
    executable_and_modules = 6,
    framebuffer = 7,
    _,
};

pub const MemoryMapEntry = extern struct {
    base: u64,
    length: u64,
    type: MemoryMapType,
};

pub const MemoryMapResponse = extern struct {
    revision: u64,
    entry_count: u64,
    entries: ?[*]*MemoryMapEntry,

    pub fn getEntries(self: @This()) []*MemoryMapEntry {
        if (self.entry_count == 0 or self.entries == null) return &.{};
        return self.entries.?[0..self.entry_count];
    }
};

pub const MemoryMapRequest = extern struct {
    id: [4]u64 = id(0x67cf3d9d378a806f, 0xe304acdfc50c3c62),
    revision: u64 = 0,
    response: ?*MemoryMapResponse = null,
};

// SMP CPU -kuvaus Limine-vastauksessa (AP-käynnistys myöhemmin).
pub const SmpCpu = extern struct {
    // Limine-processor-id (ei x2APIC id).
    processor_id: u32,
    // Local APIC id.
    lapic_id: u32,
    // Varattu — pitää olla nolla.
    reserved: u64,
    // AP goto-osoite (Limine asettaa).
    goto_address: u64,
    // Extra-argumentti AP:lle.
    extra_argument: u64,
};

// SMP-vastaus — CPU-määrä ja taulukko SmpCpu-rakenteita.
pub const SmpResponse = extern struct {
    // Vastauksen revisio.
    revision: u64,
    // SMP flags (Limine määrittelee).
    flags: u32,
    // BSP:n LAPIC id.
    bsp_lapic_id: u32,
    // CPU:iden kokonaismäärä (BSP mukaan lukien).
    cpu_count: u64,
    // Osoitin cpu_count kpl SmpCpu-rakenteita.
    cpus: ?[*]SmpCpu,
};

// SMP-pyyntö — Limine täyttää cpu_count bootissa.
pub const SmpRequest = extern struct {
    id: [4]u64 = id(0x95a67b819a1b857e, 0xa0b61b723b6a73e0),
    revision: u64 = 0,
    response: ?*SmpResponse = null,
    // SMP flags (esim. X2APIC) — 0 oletuksena.
    flags: u64 = 0,
};
