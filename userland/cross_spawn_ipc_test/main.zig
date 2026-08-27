//! Cross-spawn IPC parent — spawn + cap.transfer + send ilman kernel-orchestraatiota (Vaihe 27.2).
//!
//! **Vastuu**: Luo portti, spawnaa lapsi, siirtää recv-cap, lähettää viestin.
//! **Riippuvuudet**: `cap`, `spawn`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → crossSpawnIpcMain

// Tuo capability-kirjasto — createPort ja transfer.
const cap = @import("cap");
// Tuo spawn-kirjasto — sys_spawn wrapper.
const spawn = @import("spawn");
// Tuo IPC-kirjasto — send viestille.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Capability-slotti 0 — ensimmäinen createPort-asennus.
const CAP_SLOT: u32 = 0;
// Lähetettävä testiviesti lapselle (3 tavua).
const MSG = "XSP";

// Cross-spawn IPC parent -sisäänkäynti — start.S kutsuu tätä.
export fn crossSpawnIpcMain() void {
    // Oikeusmaski: read + send + recv + grant.
    const mask = cap.MASK_READ | cap.MASK_SEND | cap.MASK_RECV | cap.MASK_GRANT;
    // Luo IPC-portti capability slot 0:een.
    _ = cap.createPort(mask) catch {
        // Portin luonti epäonnistui.
        sc.print("cross spawn ipc create failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Spawnaa cross-spawn IPC -lapsi.
    const child_pid = spawn.spawnEmbedded(spawn.SPAWN_ID_CROSS_SPAWN_CHILD) catch {
        // sys_spawn epäonnistui.
        sc.print("cross spawn ipc spawn failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Siirrä recv-oikeus lapselle ennen sendiä.
    const xfer_mask = cap.MASK_READ | cap.MASK_RECV;
    _ = cap.transfer(CAP_SLOT, child_pid, xfer_mask) catch {
        // cap_transfer epäonnistui.
        sc.print("cross spawn ipc transfer failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Lähetä viesti portille — lapsi vastaanottaa recv-slotillaan myöhemmin.
    _ = ipc.send(CAP_SLOT, MSG) catch {
        // ipc_send epäonnistui.
        sc.print("cross spawn ipc send failed\n");
        // Palaa kerneliin virhetilassa.
        sc.sysTestReturn();
    };
    // Parent valmis — kernel ajaa lapsen runProcess:llä.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään crossSpawnIpcMain.
pub export fn crossSpawnIpcAnchor() void {}
