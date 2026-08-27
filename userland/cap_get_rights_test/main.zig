//! Capability get rights userland boot-testi — cap.getRights parent/derived.
//!
//! **Vastuu**: Testaa oikeusmaskin kysely delegoinnin jälkeen ring 3:ssa.
//! **Riippuvuudet**: `cap`, `syscall.zig`
//! **Käytetään**: start.S → capGetRightsMain

// Tuo userland capability-kirjasto.
const cap = @import("cap");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Boot-info — kernel kirjoittaa ennen ring 3 -hyppyä (.capboot user.ld).
const CAP_GET_RIGHTS_SLOT_VADDR: u64 = 0xFFFFFFFF90085000;
// Boot-info — odotettu parent-maski heti slotin jälkeen (+4).
const CAP_GET_RIGHTS_MASK_VADDR: u64 = 0xFFFFFFFF90085004;

// Cap get rights -testin sisäänkäynti — start.S kutsuu tätä.
export fn capGetRightsMain() void {
    // Parent capability-slotti kernelin boot-info-osoitteesta.
    const slot = @as(*const u32, @ptrFromInt(CAP_GET_RIGHTS_SLOT_VADDR)).*;
    // Osoitin odotettuun parent-maskiin kernelin boot-info-osoitteessa.
    const parent_rights_ptr = @as(*const u32, @ptrFromInt(CAP_GET_RIGHTS_MASK_VADDR));
    // Jos boot-info puuttuu, getRights epäonnistuu varmasti.
    if (slot == 0 or parent_rights_ptr.* == 0) {
        // Boot-info puuttuu.
        sc.print("cap get rights boot info missing\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kysy parent-slotin oikeudet — pitää täsmätä kernel-maskiin.
    const parent_mask = cap.getRights(slot) catch {
        // getRights epäonnistui.
        sc.print("cap get rights parent query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista parent-maski täsmää.
    if (parent_mask != parent_rights_ptr.*) {
        // Parent-oikeudet eivät täsmää.
        sc.print("cap get rights parent mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Delegoi vain recv-oikeus uuteen slottiin.
    const derived = cap.delegate(slot, cap.MASK_RECV) catch {
        // Delegointi epäonnistui.
        sc.print("cap get rights delegate failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy derived-slotin oikeudet — pitää olla recv-only.
    const derived_mask = cap.getRights(derived) catch {
        // getRights epäonnistui.
        sc.print("cap get rights derived query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista derived-maski on recv-only.
    if (derived_mask != cap.MASK_RECV) {
        // Derived-oikeudet eivät täsmää.
        sc.print("cap get rights derived mismatch\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kysy parent uudelleen — oikeudet säilyvät delegoinnin jälkeen.
    const parent_again = cap.getRights(slot) catch {
        // getRights epäonnistui.
        sc.print("cap get rights parent again failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista parent-maski ei muuttunut.
    if (parent_again != parent_rights_ptr.*) {
        // Parent-oikeudet muuttuivat delegoinnin jälkeen.
        sc.print("cap get rights parent changed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland cap get rights OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland cap get rights test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään capGetRightsMain.
pub export fn capGetRightsAnchor() void {}
