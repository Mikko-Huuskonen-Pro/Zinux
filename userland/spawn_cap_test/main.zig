//! Spawn + cap.transfer userland-demo — luo portti, spawnaa lapsi, siirtää recv-cap (Vaihe 27.1).
//!
//! **Vastuu**: spawnEmbedded + cap.transfer ilman kernel-orchestraatiota.
//! **Riippuvuudet**: `cap`, `spawn`, `syscall.zig`
//! **Käytetään**: start.S → spawnCapMain

// Tuo capability-kirjasto — createPort ja transfer.
const cap = @import("cap");
// Tuo spawn-kirjasto — sys_spawn wrapper.
const spawn = @import("spawn");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Capability-slotti 0 — ensimmäinen createPort-asennus.
const CAP_SLOT: u32 = 0;

// Spawn cap -testin sisäänkäynti — start.S kutsuu tätä.
export fn spawnCapMain() void {
    // Oikeusmaski: read + send + recv + grant (recv siirrettävissä lapselle).
    const mask = cap.MASK_READ | cap.MASK_SEND | cap.MASK_RECV | cap.MASK_GRANT;
    // Luo IPC-portti capability slot 0:een.
    _ = cap.createPort(mask) catch {
        // Portin luonti epäonnistui.
        sc.print("spawn cap create failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Spawnaa cross-spawn IPC -lapsi kernelin upotetusta ELF:stä.
    const child_pid = spawn.spawnEmbedded(spawn.SPAWN_ID_CROSS_SPAWN_CHILD) catch {
        // sys_spawn epäonnistui.
        sc.print("spawn cap spawn failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Siirrä recv-oikeus lapselle — dedup palauttaa slot 0 lapsessa.
    const xfer_mask = cap.MASK_READ | cap.MASK_RECV;
    _ = cap.transfer(CAP_SLOT, child_pid, xfer_mask) catch {
        // cap_transfer epäonnistui.
        sc.print("spawn cap transfer failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Vahvistus serialiin — kernel lokittaa "Userland spawn cap OK" boot-testissä.
    sc.print("userland spawn cap OK\n");
    // Palaa kerneliin — spawn_cap_userland jatkaa.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään spawnCapMain.
pub export fn spawnCapAnchor() void {}
