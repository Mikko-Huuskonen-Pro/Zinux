//! Capability get resource userland boot-testi — cap.getResource parent/derived.
//!
//! **Vastuu**: Testaa resurssitunnisteen kysely read-oikeudella ring 3:ssa.
//! **Riippuvuudet**: `cap`, `syscall.zig`
//! **Käytetään**: start.S → capGetResourceMain

// Tuo userland capability-kirjasto.
const cap = @import("cap");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Boot-info — kernel kirjoittaa ennen ring 3 -hyppyä (.capboot user.ld).
const CAP_GET_RESOURCE_SLOT_VADDR: u64 = 0xFFFFFFFF9008A000;
// Boot-info — odotettu port_id heti slotin jälkeen (+4).
const CAP_GET_RESOURCE_EXPECT_VADDR: u64 = 0xFFFFFFFF9008A004;

// Cap get resource -testin sisäänkäynti — start.S kutsuu tätä.
export fn capGetResourceMain() void {
    // Parent capability-slotti kernelin boot-info-osoitteesta.
    const slot = @as(*const u32, @ptrFromInt(CAP_GET_RESOURCE_SLOT_VADDR)).*;
    // Osoitin odotettuun port_id:hen kernelin boot-info-osoitteessa.
    const expect_ptr = @as(*const u32, @ptrFromInt(CAP_GET_RESOURCE_EXPECT_VADDR));
    // Jos boot-info puuttuu, getResource epäonnistuu varmasti.
    if (slot == 0 or expect_ptr.* == 0) {
        // Boot-info puuttuu.
        sc.print("cap get resource boot info missing\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kysy parent-slotin resurssitunniste — pitää täsmätä port_id:hen.
    const parent_resource = cap.getResource(slot) catch {
        // getResource epäonnistui.
        sc.print("cap get resource parent query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista parent port_id täsmää.
    if (parent_resource != expect_ptr.*) {
        // Parent-resurssitunniste ei täsmää.
        sc.print("cap get resource parent mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Delegoi vain send-oikeus ilman read:ia uuteen slottiin.
    const derived = cap.delegate(slot, cap.MASK_SEND) catch {
        // Delegointi epäonnistui.
        sc.print("cap get resource delegate failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy derived-slotin resurssitunniste — pitää epäonnistua PermissionDenied.
    _ = cap.getResource(derived) catch |err| {
        // Varmista read-oikeuden puute aiheuttaa PermissionDenied.
        if (err != error.PermissionDenied) {
            // Väärä virhe derived-slotille ilman read-oikeutta.
            sc.print("cap get resource derived wrong error\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
        // Kysy parent uudelleen — resurssitunniste säilyy.
        const parent_again = cap.getResource(slot) catch {
            // getResource epäonnistui.
            sc.print("cap get resource parent again failed\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        };
        // Varmista parent port_id ei muuttunut.
        if (parent_again != expect_ptr.*) {
            // Parent-resurssitunniste muuttui delegoinnin jälkeen.
            sc.print("cap get resource parent changed\n");
            // Palaa kerneliin.
            sc.sysTestReturn();
        }
        // Vahvistus serialiin ennen paluuta.
        sc.print("userland cap get resource OK\n");
        // Palaa kerneliin — kernel lokittaa "Userland cap get resource test OK".
        sc.sysTestReturn();
    };
    // getResource onnistui derived-slotilla ilman read-oikeutta — virhe.
    sc.print("cap get resource derived should fail\n");
    // Palaa kerneliin.
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään capGetResourceMain.
pub export fn capGetResourceAnchor() void {}
