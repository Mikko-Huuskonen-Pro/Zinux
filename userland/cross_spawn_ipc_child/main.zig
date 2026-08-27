//! Cross-spawn IPC child — vastaanottaa siirretyn recv-capabilityn (Vaihe 27.2).
//!
//! **Vastuu**: ipc.recv slot 0:lla parentin lähettämään viestiin.
//! **Riippuvuudet**: `ipc`, `syscall.zig`
//! **Käytetään**: sys_spawn(SPAWN_ID_CROSS_SPAWN_CHILD) → runProcess

// Tuo IPC-kirjasto — recv capability-slotilla.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Capability-slotti 0 — parent siirsi recv-cap tähän.
const RECV_SLOT: u32 = 0;
// Odotettu viesti parentilta (3 tavua).
const EXPECTED = "XSP";

// Cross-spawn IPC child -sisäänkäynti — start.S kutsuu tätä.
export fn crossSpawnChildMain() void {
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota parentin lähettämä viesti.
    const got = ipc.recv(RECV_SLOT, &buf) catch {
        // ipc_recv epäonnistui.
        sc.print("cross spawn ipc recv failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Tarkista viestin pituus.
    if (got != EXPECTED.len) {
        // Väärä pituus.
        sc.print("cross spawn ipc len mismatch\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    }
    // Vertaa sisältö tavu kerrallaan.
    var i: usize = 0;
    while (i < EXPECTED.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != EXPECTED[i]) {
            // Sisältövirhe.
            sc.print("cross spawn ipc payload mismatch\n");
            // Palaa kerneliin virhetilassa.
            sc.sysTestReturn();
        }
    }
    // Vahvistus serialiin — kernel lokittaa cross-spawn IPC test OK.
    sc.print("userland cross spawn ipc OK\n");
    // Palaa kerneliin spawn.runProcess jälkeen.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään crossSpawnChildMain.
pub export fn crossSpawnChildAnchor() void {}
