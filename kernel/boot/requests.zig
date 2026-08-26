//! Limine bootloader -pyynnöt (requests) joita kernel exporttaa linkkerille.
//!
//! **Vastuu**: Ilmoita Limineelle mitä boot-tietoja tarvitsemme.
//! **Riippuvuudet**: `limine`-paketti (48cf/limine-zig)
//! **Käytetään**: linkkeri sijoittaa `.limine_requests`-sectioniin

// Tuo vendoroitu Limine-protokolla (ei ulkoista pakettia).
const limine = @import("limine_protocol.zig");

// Alkumerkki — Limine etsii request-taulukon alun tästä.
export var requests_start: limine.RequestsStartMarker
    linksection(".limine_requests_start") = .{};
// Loppumerkki — Limine tietää request-taulukon päättyvän tähän.
export var requests_end: limine.RequestsEndMarker
    linksection(".limine_requests_end") = .{};
// Perusprotokollaversio 3 — nykyinen Limine API (ei vanhentunut 0–2).
export var base_revision: limine.BaseRevision
    linksection(".limine_requests") = .init(3);
// Higher-half direct map -offset: fysinen → virtuaalinen osoitemuunnos.
export var hhdm_request: limine.HhdmRequest
    linksection(".limine_requests") = .{};
// Framebuffer-tiedot (valinnainen — VGA fallback jos puuttuu).
export var framebuffer_request: limine.FramebufferRequest
    linksection(".limine_requests") = .{};

// Pakota linkkeri säilyttämään kaikki Limine-exportit (ReleaseSafe DCE).
pub fn anchor() void {
    _ = &requests_start;
    _ = &requests_end;
    _ = &base_revision;
    _ = &hhdm_request;
    _ = &framebuffer_request;
}
