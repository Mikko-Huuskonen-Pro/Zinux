//! IPC pending userland boot-testi — ipc.pending empty/send/recv/empty.
//!
//! **Vastuu**: Testaa jonon pituuden kysely ring 3:ssa.
//! **Riippuvuudet**: `cap`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → ipcPendingMain

// Tuo userland capability-kirjasto — createPort.
const cap = @import("cap");
// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Ipc pending -testin sisäänkäynti — start.S kutsuu tätä.
export fn ipcPendingMain() void {
    // Oikeudet send + recv uudelle portille.
    const rights = cap.MASK_SEND | cap.MASK_RECV;
    // Luo uusi portti-capability ring 3:ssa.
    const slot = cap.createPort(rights) catch {
        // Luonti epäonnistui.
        sc.print("ipc pending create failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy jonon pituus tyhjällä portilla — pitää olla 0.
    const empty = ipc.pending(slot) catch {
        // Pending-kysely epäonnistui.
        sc.print("ipc pending empty query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista tyhjä jono.
    if (empty != 0) {
        // Odotettiin nollaa odottavia viestejä.
        sc.print("ipc pending empty should be 0\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Lähetettävä testiviesti.
    const msg = "PND";
    // Lähetä viesti porttiin.
    _ = ipc.send(slot, msg) catch {
        // Send epäonnistui.
        sc.print("ipc pending send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy jonon pituus viestin jälkeen — pitää olla 1.
    const pending = ipc.pending(slot) catch {
        // Pending-kysely epäonnistui.
        sc.print("ipc pending after send query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista yksi odottava viesti.
    if (pending != 1) {
        // Odotettiin yhtä odottavaa viestiä.
        sc.print("ipc pending after send should be 1\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota viesti tryRecv:llä (non-blocking).
    const got = ipc.tryRecv(slot, &buf) catch {
        // Recv epäonnistui.
        sc.print("ipc pending recv failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista pituus.
    if (got != msg.len) {
        // Väärä vastaanotettu pituus.
        sc.print("ipc pending len mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kysy jonon pituus recv:n jälkeen — pitää olla 0.
    const after = ipc.pending(slot) catch {
        // Pending-kysely epäonnistui.
        sc.print("ipc pending after recv query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista tyhjä jono uudelleen.
    if (after != 0) {
        // Odotettiin nollaa recv:n jälkeen.
        sc.print("ipc pending after recv should be 0\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland ipc pending OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland IPC pending test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään ipcPendingMain.
pub export fn ipcPendingAnchor() void {}
