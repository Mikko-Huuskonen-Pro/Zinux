//! Cross-process IPC userland boot-testi — sender/receiver rooli boot_info:sta.
//!
//! **Vastuu**: Lähetä tai vastaanota slot 0:lla riippuen kernelin kirjoittamasta roolista.
//! **Riippuvuudet**: `ipc`, `syscall.zig`
//! **Käytetään**: start.S → crossIpcMain

// Tuo userland IPC-kirjasto — send/recv capability-slotilla.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Kiinteä .crossipc-osoite — kernel kirjoittaa roolin ennen ring 3 -hyppyä.
const CROSS_IPC_ROLE_VADDR: u64 = 0xFFFFFFFF9008D000;
// Rooli: prosessi A lähettää viestin.
const ROLE_SENDER: u32 = 1;
// Rooli: prosessi B vastaanottaa viestin.
const ROLE_RECEIVER: u32 = 2;
// Capability-slotti 0 — kernel asentaa send/recv eri prosesseille.
const IPC_SLOT: u32 = 0;

// Cross-IPC-testin sisäänkäynti — start.S kutsuu tätä.
export fn crossIpcMain() void {
    // Lue rooli kernelin kirjoittamasta user-muistista.
    const role = @as(*const u32, @ptrFromInt(CROSS_IPC_ROLE_VADDR)).*;
    // Sender: lähetä testiviesti toiselle prosessille.
    if (role == ROLE_SENDER) {
        // Lähetettävä viesti (3 tavua).
        const msg = "XPC";
        // Lähetä ipc-kirjaston send()-funktiolla slot 0:lla.
        _ = ipc.send(IPC_SLOT, msg) catch {
            // Send epäonnistui.
            sc.print("cross ipc send failed\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        };
        // Palaa kerneliin — receiver ajetaan seuraavaksi.
        sc.sysTestReturn();
    }
    // Receiver: vastaanota viesti ja vahvista serialiin.
    if (role == ROLE_RECEIVER) {
        // Vastaanottopuskuri pinossa.
        var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
        // Vastaanota ipc-kirjaston recv()-funktiolla slot 0:lla.
        const got = ipc.recv(IPC_SLOT, &buf) catch {
            // Recv epäonnistui.
            sc.print("cross ipc recv failed\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        };
        // Odotettu viesti "XPC" (3 tavua).
        if (got != 3) {
            // Väärä pituus.
            sc.print("cross ipc len mismatch\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
        // Vertaa sisältö tavu kerrallaan.
        var i: usize = 0;
        while (i < 3) : (i += 1) {
            // Jos tavu ei täsmää "XPC".
            if (buf[i] != "XPC"[i]) {
                // Sisältövirhe.
                sc.print("cross ipc payload mismatch\n");
                // Palaa kerneliin.
                sc.sysTestReturn();
            }
        }
        // Vahvistus serialiin ennen paluuta.
        sc.print("userland cross ipc OK\n");
        // Palaa kerneliin — kernel lokittaa "Userland cross IPC test OK".
        sc.sysTestReturn();
    }
    // Tuntematon rooli — kernel setup virhe.
    sc.print("cross ipc bad role\n");
    // Palaa kerneliin virhetilassa.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään crossIpcMain.
pub export fn crossIpcAnchor() void {}
