//! Limine bootloader -pyynnöt — yksi struct varmistaa oikean muistijärjestyksen.

const limine = @import("limine_protocol.zig");

pub const LimineRequests = extern struct {
    base: limine.BaseRevision,
    hhdm: limine.HhdmRequest,
    memmap: limine.MemoryMapRequest,
    fb: limine.FramebufferRequest,
    smp: limine.SmpRequest,
};

export var requests_start: limine.RequestsStartMarker
    linksection(".limine_requests_start") = .{};

export var limine_requests: LimineRequests
    linksection(".limine_requests") = .{
    .base = .init(0),
    .hhdm = .{},
    .memmap = .{},
    .fb = .{},
    .smp = .{},
};

export var requests_end: limine.RequestsEndMarker
    linksection(".limine_requests_end") = .{};

pub fn anchor() void {
    _ = &requests_start;
    _ = &limine_requests;
    _ = &requests_end;
}
