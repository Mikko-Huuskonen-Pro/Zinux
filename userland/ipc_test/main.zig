//! IPC userland boot-testi — ipc.zig send/recv roundtrip ring 3:ssa.
//!
//! **Vastuu**: Testaa ipc.zig send ja recv capability-slotilla 4.
//! **Riippuvuudet**: `ipc`, `syscall.zig`
//! **Käytetään**: start.S → ipcMain

// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// IPC-testin sisäänkäynti — start.S kutsuu tätä.
export fn ipcMain() void {
    // Capability-slotti 4 — kernel ipc_userland luo viidennen slotin.
    const slot: u32 = 4;
    // Lähetettävä testiviesti.
    const msg = "IPC";
    // Lähetä ipc-kirjaston send()-funktiolla.
    _ = ipc.send(slot, msg) catch {
        // Send epäonnistui.
        sc.print("ipc send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota ipc-kirjaston recv()-funktiolla.
    const got = ipc.recv(slot, &buf) catch {
        // Recv epäonnistui.
        sc.print("ipc recv failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista pituus.
    if (got != msg.len) {
        // Väärä vastaanotettu pituus.
        sc.print("ipc len mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vertaa sisältö tavu kerrallaan.
    var i: usize = 0;
    while (i < msg.len) : (i += 1) {
        // Jos tavu ei täsmää.
        if (buf[i] != msg[i]) {
            // Sisältövirhe.
            sc.print("ipc payload mismatch\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland ipc OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland IPC test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään ipcMain.
pub export fn ipcAnchor() void {}
