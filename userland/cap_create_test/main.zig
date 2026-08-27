//! Capability create userland boot-testi — cap.createPort + ipc roundtrip.
//!
//! **Vastuu**: Testaa cap.createPort ja ipc send/recv samalla slotilla ring 3:ssa.
//! **Riippuvuudet**: `cap`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → capCreateMain

// Tuo userland capability-kirjasto.
const cap = @import("cap");
// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Cap create -testin sisäänkäynti — start.S kutsuu tätä.
export fn capCreateMain() void {
    // Oikeudet send + recv uudelle portille.
    const rights = cap.MASK_SEND | cap.MASK_RECV;
    // Luo uusi portti-capability ring 3:ssa.
    const slot = cap.createPort(rights) catch {
        // Luonti epäonnistui.
        sc.print("cap create failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Lähetettävä testiviesti.
    const msg = "PRT";
    // Lähetä ipc-kirjaston send()-funktiolla.
    _ = ipc.send(slot, msg) catch {
        // Send epäonnistui.
        sc.print("cap create send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota ipc-kirjaston recv()-funktiolla.
    const got = ipc.recv(slot, &buf) catch {
        // Recv epäonnistui.
        sc.print("cap create recv failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista pituus.
    if (got != msg.len) {
        // Väärä vastaanotettu pituus.
        sc.print("cap create len mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vertaa sisältö tavu kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            sc.print("cap create payload mismatch\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland cap create OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland cap create test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään capCreateMain.
pub export fn capCreateAnchor() void {}
