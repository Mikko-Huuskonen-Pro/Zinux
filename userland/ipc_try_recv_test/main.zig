//! IPC try recv userland boot-testi — ipc.tryRecv empty/send/recv/empty.
//!
//! **Vastuu**: Testaa non-blocking recv tyhjään porttiin ring 3:ssa.
//! **Riippuvuudet**: `cap`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → ipcTryRecvMain

// Tuo userland capability-kirjasto — createPort.
const cap = @import("cap");
// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Ipc try recv -testin sisäänkäynti — start.S kutsuu tätä.
export fn ipcTryRecvMain() void {
    // Oikeudet send + recv uudelle portille.
    const rights = cap.MASK_SEND | cap.MASK_RECV;
    // Luo uusi portti-capability ring 3:ssa.
    const slot = cap.createPort(rights) catch {
        // Luonti epäonnistui.
        sc.print("ipc try recv create failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Yritä recv tyhjään jonoon — pitää palauttaa WouldBlock.
    const empty_result = ipc.tryRecv(slot, &buf);
    // Onnistunut recv tyhjällä jonolla on virhe.
    if (empty_result) |_| {
        // Recv onnistui tyhjällä jonolla — virhe.
        sc.print("ipc try recv empty should block\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    } else |err| {
        // Odotettu WouldBlock tyhjällä jonolla.
        if (err != error.WouldBlock) {
            // Väärä virhe tyhjälle jonolle.
            sc.print("ipc try recv empty wrong err\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Lähetettävä testiviesti.
    const msg = "TRY";
    // Lähetä viesti porttiin.
    _ = ipc.send(slot, msg) catch {
        // Send epäonnistui.
        sc.print("ipc try recv send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Yritä recv viestillä täytetyllä jonolla — pitää onnistua.
    const got = ipc.tryRecv(slot, &buf) catch {
        // Recv epäonnistui vaikka viesti jonossa.
        sc.print("ipc try recv got failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista pituus.
    if (got != msg.len) {
        // Väärä vastaanotettu pituus.
        sc.print("ipc try recv len mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vertaa sisältö tavu kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            sc.print("ipc try recv payload mismatch\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Yritä recv uudelleen tyhjään jonoon — pitää palauttaa WouldBlock.
    const empty2_result = ipc.tryRecv(slot, &buf);
    // Onnistunut recv tyhjällä jonolla on virhe.
    if (empty2_result) |_| {
        // Recv onnistui tyhjällä jonolla — virhe.
        sc.print("ipc try recv empty2 should block\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    } else |err| {
        // Odotettu WouldBlock tyhjän jonon jälkeen.
        if (err != error.WouldBlock) {
            // Väärä virhe.
            sc.print("ipc try recv empty2 wrong err\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland ipc try recv OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland IPC try recv test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään ipcTryRecvMain.
pub export fn ipcTryRecvAnchor() void {}
