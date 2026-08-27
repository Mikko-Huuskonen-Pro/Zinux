//! SMP-alustus Limine boot-infosta (Vaihe 3 stub).
//!
//! **Vastuu**: Lue CPU-määrä Limine SMP -vastauksesta ja logita.
//! **Riippuvuudet**: `requests.zig`, `../lib/log.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo Limine request -tyypit SMP-vastauksen lukemiseen.
const requests = @import("requests.zig");
// Tuo lokitusmoduuli CPU-määrän tulostukseen.
const log = @import("../lib/log.zig");
// Limine request -ankkuri (linksection .limine_requests).
extern var limine_requests: requests.LimineRequests;

// Lue Limine SMP -vastaus ja logita CPU-määrä (BSP + AP:t).
pub fn initAndLog() void {
    // Hae SMP-vastaus Limine-pyynnöstä.
    const resp = limine_requests.smp.response orelse {
        // Limine ei antanut SMP-tietoa — oletus yksi CPU.
        log.info("SMP unavailable (assume 1 CPU)");
        // Valmis ilman SMP-dataa.
        return;
    };
    // Yhden CPU:n tapaus — yleinen QEMU oletus.
    if (resp.cpu_count == 1) {
        // Tulosta yksiselitteinen boot-viesti serialiin.
        log.info("SMP CPUs: 1");
        // Valmis.
        return;
    }
    // Useampi CPU — yksinkertainen viesti (AP-käynnistys myöhemmin).
    if (resp.cpu_count == 2) {
        // Kaksi CPU:ta havaittu.
        log.info("SMP CPUs: 2");
        // Valmis.
        return;
    }
    // Kolme tai useampi — geneerinen viesti.
    log.info("SMP CPUs: N (multi)");
    // BSP LAPIC id tallennettu myöhempää varten.
    _ = resp.bsp_lapic_id;
}
