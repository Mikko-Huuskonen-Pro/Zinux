//! Capability revoke userland boot-testi — cap.revoke + ipc send epäonnistuu.
//!
//! **Vastuu**: Testaa cap.revoke ja varmista että ipc.send palauttaa BadSlot.
//! **Riippuvuudet**: `cap`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → capRevokeMain

// Tuo userland capability-kirjasto.
const cap = @import("cap");
// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Cap revoke -testin sisäänkäynti — start.S kutsuu tätä.
export fn capRevokeMain() void {
    // Oikeudet send + recv uudelle portille.
    const rights = cap.MASK_SEND | cap.MASK_RECV;
    // Luo uusi portti-capability ring 3:ssa.
    const slot = cap.createPort(rights) catch {
        // Luonti epäonnistui.
        sc.print("cap revoke create failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Lähetettävä testiviesti ennen peruutusta.
    const msg = "RVK";
    // Lähetä ipc-kirjaston send()-funktiolla — pitää onnistua.
    _ = ipc.send(slot, msg) catch {
        // Send epäonnistui ennen peruutusta.
        sc.print("cap revoke pre-send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Peruuta capability-slotti ring 3:ssa.
    cap.revoke(slot) catch {
        // Revoke epäonnistui.
        sc.print("cap revoke failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Yritä lähettää peruutetun slotin kautta — pitää epäonnistua.
    _ = ipc.send(slot, msg) catch {
        // Odotettu virhe — peruutus toimi.
        sc.print("userland cap revoke OK\n");
        // Palaa kerneliin — kernel lokittaa "Userland cap revoke test OK".
        sc.sysTestReturn();
    };
    // Send onnistui peruutuksen jälkeen — virhe.
    sc.print("cap revoke post-send should fail\n");
    // Palaa kerneliin.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään capRevokeMain.
pub export fn capRevokeAnchor() void {}
