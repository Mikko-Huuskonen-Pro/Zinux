//! Capability userland boot-testi — cap.zig delegate + ipc recv ring 3:ssa.
//!
//! **Vastuu**: Testaa cap.delegate recv-only ja ipc send/recv derived-slotilla.
//! **Riippuvuudet**: `cap`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → capMain

// Tuo userland capability-kirjasto.
const cap = @import("cap");
// Tuo userland IPC-kirjasto — send/recv testiin.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Kiinteä .capboot-osoite — kernel kirjoittaa parent-slotin ennen ring 3 -hyppyä.
const CAP_PARENT_SLOT_VADDR: u64 = 0xFFFFFFFF90071000;

// Cap-testin sisäänkäynti — start.S kutsuu tätä.
export fn capMain() void {
    // Parent capability-slotti — kernel cap_userland kirjoittaa .capboot:iin.
    const parent_slot = @as(*const u32, @ptrFromInt(CAP_PARENT_SLOT_VADDR)).*;
    // Jos slotti puuttuu, delegointi epäonnistuu varmasti.
    if (parent_slot == 0) {
        // Boot-info puuttuu.
        sc.print("cap boot slot missing\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Delegoi vain recv-oikeus uuteen slottiin.
    const derived = cap.delegate(parent_slot, cap.MASK_RECV) catch {
        // Delegointi epäonnistui.
        sc.print("cap delegate failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Yritä lähettää derived-slotilla — pitäisi epäonnistua.
    const send_result = ipc.send(derived, "X");
    // Jos send onnistui vaikka ei pitäisi.
    if (send_result) |_| {
        // Send vuoti derived-slotista.
        sc.print("cap send leak\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    } else |err| {
        // Odotetaan BadSlot koska send-oikeus puuttuu.
        if (err != error.BadSlot) {
            // Väärä virhetyyppi.
            sc.print("cap send leak\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Vastaanottopuskuri pinossa.
    var buf: [ipc.MAX_MSG_SIZE]u8 = undefined;
    // Vastaanota kernelin pre-send viesti derived-slotilla.
    const got = ipc.recv(derived, &buf) catch {
        // Recv epäonnistui.
        sc.print("cap recv failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Odotettu viesti "CAP" (3 tavua).
    if (got != 3) {
        // Väärä pituus.
        sc.print("cap len mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vertaa sisältö tavu kerrallaan.
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        // Jos tavu ei täsmää "CAP".
        if (buf[i] != "CAP"[i]) {
            // Sisältövirhe.
            sc.print("cap payload mismatch\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland cap OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland cap test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään capMain.
pub export fn capAnchor() void {}
