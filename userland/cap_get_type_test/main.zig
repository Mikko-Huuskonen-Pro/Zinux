//! Capability get type userland boot-testi — cap.getType + revoke + createPort.
//!
//! **Vastuu**: Testaa capability-tyypin kysely ja portin vapautus ring 3:ssa.
//! **Riippuvuudet**: `cap`, `syscall.zig`
//! **Käytetään**: start.S → capGetTypeMain

// Tuo userland capability-kirjasto.
const cap = @import("cap");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Boot-info — kernel kirjoittaa slot ennen ring 3 -hyppyä (.capboot user.ld).
const CAP_GET_TYPE_SLOT_VADDR: u64 = 0xFFFFFFFF90087000;
// Boot-info — odotettu portti-tyyppi slotin jälkeen (+4).
const CAP_GET_TYPE_EXPECT_VADDR: u64 = 0xFFFFFFFF90087004;

// Cap get type -testin sisäänkäynti — start.S kutsuu tätä.
export fn capGetTypeMain() void {
    // Capability-slotti kernelin boot-info-osoitteesta.
    const slot = @as(*const u32, @ptrFromInt(CAP_GET_TYPE_SLOT_VADDR)).*;
    // Odotettu portti-tyyppi kernelin boot-info-osoitteesta.
    const expect_ptr = @as(*const u32, @ptrFromInt(CAP_GET_TYPE_EXPECT_VADDR));
    // Jos boot-info puuttuu, getType epäonnistuu varmasti.
    if (slot == 0 or expect_ptr.* == 0) {
        // Boot-info puuttuu.
        sc.print("cap get type boot info missing\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kysy slotin tyyppi — pitää olla portti.
    const typ = cap.getType(slot) catch {
        // getType epäonnistui.
        sc.print("cap get type query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista portti-tyyppi täsmää.
    if (typ != expect_ptr.*) {
        // Väärä capability-tyyppi.
        sc.print("cap get type mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Peruuta capability — vapauttaa IPC-portin.
    cap.revoke(slot) catch {
        // Revoke epäonnistui.
        sc.print("cap get type revoke failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy tyyppi peruutetusta slotista — pitää epäonnistua.
    _ = cap.getType(slot) catch {
        // Odotettu virhe — slotti mitätöity.
        sc.print("userland cap get type OK\n");
        // Palaa kerneliin — kernel lokittaa "Userland cap get type test OK".
        sc.sysTestReturn();
    };
    // getType onnistui peruutuksen jälkeen — virhe.
    sc.print("cap get type revoked should fail\n");
    // Palaa kerneliin.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään capGetTypeMain.
pub export fn capGetTypeAnchor() void {}
