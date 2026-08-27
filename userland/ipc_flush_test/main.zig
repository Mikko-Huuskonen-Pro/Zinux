//! IPC flush userland boot-testi — ipc.flush send/pending/flush/empty.
//!
//! **Vastuu**: Testaa portin jonon tyhjennys ring 3:ssa.
//! **Riippuvuudet**: `cap`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → ipcFlushMain

// Tuo userland capability-kirjasto — createPort.
const cap = @import("cap");
// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Ipc flush -testin sisäänkäynti — start.S kutsuu tätä.
export fn ipcFlushMain() void {
    // Oikeudet send + recv uudelle portille.
    const rights = cap.MASK_SEND | cap.MASK_RECV;
    // Luo uusi portti-capability ring 3:ssa.
    const slot = cap.createPort(rights) catch {
        // Luonti epäonnistui.
        sc.print("ipc flush create failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Lähetettävä testiviesti.
    const msg = "FLU";
    // Lähetä viesti porttiin.
    _ = ipc.send(slot, msg) catch {
        // Send epäonnistui.
        sc.print("ipc flush send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy jonon pituus ennen flushia — pitää olla 1.
    const pending = ipc.pending(slot) catch {
        // Pending-kysely epäonnistui.
        sc.print("ipc flush pending query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista yksi odottava viesti.
    if (pending != 1) {
        // Odotettiin yhtä odottavaa viestiä.
        sc.print("ipc flush pending should be 1\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Tyhjennä jono flush-syscallilla — pitää palauttaa 1.
    const flushed = ipc.flush(slot) catch {
        // Flush epäonnistui.
        sc.print("ipc flush failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista poistettujen viestien määrä.
    if (flushed != 1) {
        // Flush ei poistanut yhtä viestiä.
        sc.print("ipc flush count should be 1\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kysy jonon pituus flushin jälkeen — pitää olla 0.
    const after = ipc.pending(slot) catch {
        // Pending-kysely epäonnistui.
        sc.print("ipc flush after query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista tyhjä jono.
    if (after != 0) {
        // Odotettiin nollaa flushin jälkeen.
        sc.print("ipc flush after should be 0\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Yritä vastaanottaa tyhjältä portilta — pitää epäonnistua WouldBlock.
    _ = ipc.tryRecv(slot, &buf) catch {
        // Odotettu virhe — jono tyhjä flushin jälkeen.
        sc.print("userland ipc flush OK\n");
        // Palaa kerneliin — kernel lokittaa "Userland IPC flush test OK".
        sc.sysTestReturn();
    };
    // tryRecv onnistui flushin jälkeen — virhe.
    sc.print("ipc flush try recv should fail\n");
    // Palaa kerneliin.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään ipcFlushMain.
pub export fn ipcFlushAnchor() void {}
