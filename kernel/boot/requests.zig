//! Limine bootloader -pyynnöt — yksi struct varmistaa oikean muistijärjestyksen.
//!
//! **Vastuu**: Ilmoita Limineelle mitä boot-tietoja tarvitsemme.
//! **TÄRKEÄ**: base_revision PITÄÄ olla ensimmäinen request (Limine PROTOCOL.md).

const limine = @import("limine_protocol.zig");

// Kaikki Limine-pyynnöt yhdessä structissa — base on aina ensimmäinen kenttä.
pub const LimineRequests = extern struct {
    base: limine.BaseRevision,
    hhdm: limine.HhdmRequest,
    fb: limine.FramebufferRequest,
};

export var requests_start: limine.RequestsStartMarker
    linksection(".limine_requests_start") = .{};

export var limine_requests: LimineRequests
    linksection(".limine_requests") = .{
    .base = .init(0),
    .hhdm = .{},
    .fb = .{},
};

export var requests_end: limine.RequestsEndMarker
    linksection(".limine_requests_end") = .{};

pub fn anchor() void {
    _ = &requests_start;
    _ = &limine_requests;
    _ = &requests_end;
}
