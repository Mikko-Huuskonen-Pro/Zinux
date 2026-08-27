//! IPC block userland boot-testi — blocking ipc.recv odottaa timer-viestiä.
//!
//! **Vastuu**: Testaa blocking recv tyhjään porttiin ring 3:ssa.
//! **Riippuvuudet**: `ipc`, `syscall.zig`
//! **Käytetään**: start.S → ipcBlockMain

// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Boot-info — kernel kirjoittaa capability-slotin ennen ring 3 -hyppyä.
const IPC_BLOCK_SLOT_VADDR: u64 = 0xFFFFFFFF90091000;

// Ipc block -testin sisäänkäynti — start.S kutsuu tätä.
export fn ipcBlockMain() void {
    // Capability-slotti kernelin .ipcboot-osoitteesta.
    const slot = @as(*const u32, @ptrFromInt(IPC_BLOCK_SLOT_VADDR)).*;
    // Jos slotti puuttuu, recv epäonnistuu varmasti.
    if (slot == 0) {
        // Boot-info puuttuu.
        sc.print("ipc block slot missing\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Blocking recv — odottaa kunnes timer lähettää BLK.
    const got = ipc.recv(slot, &buf) catch {
        // Recv epäonnistui.
        sc.print("ipc block recv failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Odotettu viesti "BLK" (3 tavua).
    if (got != 3) {
        // Väärä pituus.
        sc.print("ipc block len mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vertaa sisältö tavu kerrallaan.
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        // Jos tavu ei täsmää "BLK".
        if (buf[i] != "BLK"[i]) {
            // Sisältövirhe.
            sc.print("ipc block payload mismatch\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland ipc block OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland IPC block test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään ipcBlockMain.
pub export fn ipcBlockAnchor() void {}
