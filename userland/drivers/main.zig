//! Käyttäjätilan ajuritesti — rekisteri + null-ajuri boot-demona.
//!
//! **Vastuu**: initAll → shutdownAll → sys_test_return.
//! **Riippuvuudet**: `registry.zig`, `syscall.zig`
//! **Käytetään**: start.S → driverMain

// Tuo ajurirekisteri.
const registry = @import("registry.zig");
// Tuo syscall wrapperit.
const sc = @import("syscall.zig");

// Ajuritestin sisäänkäynti — start.S kutsuu tätä.
export fn driverMain() void {
    // Alusta kaikki probatut ajurit.
    registry.initAll() catch {
        // Alustus epäonnistui — tulosta virhe ja palaa.
        sc.print("driver init failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Vähintään yksi ajuri (null) pitää probata.
    if (registry.probedCount() == 0) {
        // Tyhjä rekisteri — virhe.
        sc.print("driver registry empty\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Sammuta ajurit siististi (demo shutdown-polku).
    registry.shutdownAll();
    // Vahvistusviesti serialiin ennen paluuta.
    sc.print("userland driver OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland driver test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään driverMain (freestanding juuri).
pub export fn driverAnchor() void {}
