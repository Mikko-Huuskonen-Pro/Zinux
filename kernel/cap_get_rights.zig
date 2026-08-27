//! Capability get rights boot-testi — invoke + userland ring 3 yhdellä slotilla.
//!
//! **Vastuu**: sys_cap_get_rights invoke, delegoi, cap.getRights ring 3:ssa.
//! **Riippuvuudet**: `dispatch.zig`, `loader/elf.zig`, `usermode.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo jaettu ABI — syscall-numerot.
const abi = @import("zinuxabi");
// Tuo dispatch — invoke() suoraan ilman ring 3.
const dispatch = @import("syscall/dispatch.zig");
// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo IPC-portit — createPort boot-portille.
const port = @import("ipc/port.zig");
// Tuo capability — createAndInstall slotille.
const cap = @import("ipc/capability_core.zig");
// Tuo capability-syscall-ydin — oikeusmaskit.
const cap_core = @import("syscall/cap_syscall_core.zig");
// Tuo user_access — SMAP-yhteensopiva kirjoitus user-sivulle.
const user_access = @import("arch/x86_64/user_access.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu cap_get_rights-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const cap_get_rights_test_elf = @embedFile("loader/cap_get_rights_test_prog.bin");

// Cap get rights -testin pinon heap-slot — erillään muista user-ELF:istä.
const CAP_GET_RIGHTS_STACK_SLOT: u64 = 107;
// Boot-info — kernel kirjoittaa ennen ring 3 -hyppyä (.capboot user.ld).
const CAP_GET_RIGHTS_SLOT_VADDR: u64 = 0xFFFFFFFF90085000;
// Boot-info — odotettu parent-maski heti slotin jälkeen (+4).
const CAP_GET_RIGHTS_MASK_VADDR: u64 = 0xFFFFFFFF90085004;

// Boot-testi — invoke get_rights + userland ELF samalla slotilla.
pub fn runBootTest() void {
    // Luo uusi IPC-portti get-rights-testille (yksi portti molemmille testeille).
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Cap get rights port create failed");
        // Lopeta testi.
        return;
    };
    // Täydet oikeudet mukaan grant delegointiin.
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus viestin jonoon.
        .send = true,
        // recv-oikeus viestin lukemiseen.
        .recv = true,
        // grant-oikeus delegointiin.
        .grant = true,
    };
    // Asenna capability portille.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("Cap get rights cap install failed");
        // Lopeta testi.
        return;
    };
    // Odotettu parent-maski (read + send + recv + grant).
    const parent_expected = cap_core.MASK_READ | cap_core.MASK_SEND | cap_core.MASK_RECV | cap_core.MASK_GRANT;
    // Kysy parent-slotin oikeudet invoke()-kautta.
    const parent_mask = dispatch.invoke(abi.SYS_cap_get_rights, slot, 0, 0, 0, 0, 0);
    // Varmista parent-maski täsmää.
    if (parent_mask != @as(i64, @intCast(parent_expected))) {
        // Parent-oikeudet eivät täsmää.
        log.err("Cap get rights parent mismatch");
        // Lopeta testi.
        return;
    }
    // Delegoi vain recv-oikeus uuteen slottiin invoke()-kautta.
    const derived = dispatch.invoke(abi.SYS_cap_delegate, slot, cap_core.MASK_RECV, 0, 0, 0, 0);
    // Varmista että uusi slot-indeksi palautui.
    if (derived < 0) {
        // Delegointi epäonnistui.
        log.err("Cap get rights delegate failed");
        // Lopeta testi.
        return;
    }
    // Kysy derived-slotin oikeudet — pitää olla recv-only.
    const derived_mask = dispatch.invoke(abi.SYS_cap_get_rights, @intCast(derived), 0, 0, 0, 0, 0);
    // Varmista derived-maski on recv-only.
    if (derived_mask != @as(i64, @intCast(cap_core.MASK_RECV))) {
        // Derived-oikeudet eivät täsmää.
        log.err("Cap get rights derived mismatch");
        // Lopeta testi.
        return;
    }
    // Kysy parent uudelleen — oikeudet säilyvät delegoinnin jälkeen.
    const parent_again = dispatch.invoke(abi.SYS_cap_get_rights, slot, 0, 0, 0, 0, 0);
    // Varmista parent-maski ei muuttunut.
    if (parent_again != @as(i64, @intCast(parent_expected))) {
        // Parent-oikeudet muuttuivat delegoinnin jälkeen.
        log.err("Cap get rights parent changed");
        // Lopeta testi.
        return;
    }
    // Kernel invoke-testi OK.
    log.info("Cap get rights syscall OK");
    // Lataa cap_get_rights_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(cap_get_rights_test_elf, CAP_GET_RIGHTS_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland cap get rights ELF load failed");
        // Lopeta testi.
        return;
    };
    // Kirjoita parent-slot boot-info-osoitteeseen.
    const slot_ptr: *u32 = @ptrFromInt(CAP_GET_RIGHTS_SLOT_VADDR);
    // Kirjoita odotettu maski boot-info-osoitteeseen.
    const mask_ptr: *u32 = @ptrFromInt(CAP_GET_RIGHTS_MASK_VADDR);
    // SMAP: salli user-sivujen kirjoitus kernelistä.
    user_access.stac();
    // Tallenna parent capability-slotti ring 3 -testiä varten.
    slot_ptr.* = slot;
    // Tallenna odotettu parent-maski ring 3 -testiä varten.
    mask_ptr.* = parent_expected;
    // Palauta SMAP-suojaus.
    user_access.clac();
    // Siirry ring 3:een capGetRightsMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland cap get rights OK".
    log.info("Userland cap get rights test OK");
}
