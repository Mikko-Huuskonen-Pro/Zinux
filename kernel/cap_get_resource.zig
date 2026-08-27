//! Capability get resource boot-testi — invoke + userland ring 3 yhdellä slotilla.
//!
//! **Vastuu**: sys_cap_get_resource, read-oikeus, cap.getResource ring 3:ssa.
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

// Upotettu cap_get_resource-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const cap_get_resource_test_elf = @embedFile("loader/cap_get_resource_test_prog.bin");

// Cap get resource -testin pinon heap-slot — erillään muista user-ELF:istä.
const CAP_GET_RESOURCE_STACK_SLOT: u64 = 110;
// Boot-info — kernel kirjoittaa slot ennen ring 3 -hyppyä (.capboot user.ld).
const CAP_GET_RESOURCE_SLOT_VADDR: u64 = 0xFFFFFFFF9008A000;
// Boot-info — odotettu port_id slotin jälkeen (+4).
const CAP_GET_RESOURCE_EXPECT_VADDR: u64 = 0xFFFFFFFF9008A004;

// Boot-testi — invoke get_resource + read-oikeus + userland ELF.
pub fn runBootTest() void {
    // Luo uusi IPC-portti get-resource-testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Cap get resource port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet read + grant + send + recv boot-prosessille (pid 1 stub).
    const rights = cap.Rights{
        // Lue resurssitunniste (port_id).
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
        log.err("Cap get resource cap install failed");
        // Lopeta testi.
        return;
    };
    // Kysy parent-slotin resurssitunniste invoke()-kautta — pitää olla port_id.
    const resource = dispatch.invoke(abi.SYS_cap_get_resource, slot, 0, 0, 0, 0, 0);
    // Varmista port_id täsmää.
    if (resource != @as(i64, @intCast(port_id))) {
        // Resurssitunniste ei täsmää port_id:hen.
        log.err("Cap get resource parent mismatch");
        // Lopeta testi.
        return;
    }
    // Delegoi vain send-oikeus ilman read:ia uuteen slottiin.
    const derived = dispatch.invoke(abi.SYS_cap_delegate, slot, cap_core.MASK_SEND, 0, 0, 0, 0);
    // Varmista että uusi slot-indeksi palautui.
    if (derived < 0) {
        // Delegointi epäonnistui.
        log.err("Cap get resource delegate failed");
        // Lopeta testi.
        return;
    }
    // Kysy derived-slotin resurssitunniste — pitää palauttaa EPERM (ei read-oikeutta).
    const derived_resource = dispatch.invoke(abi.SYS_cap_get_resource, @intCast(derived), 0, 0, 0, 0, 0);
    // Varmista read-oikeuden puute estää kyselyn.
    if (derived_resource != abi.EPERM) {
        // Odotettiin EPERM derived-slotille ilman read-oikeutta.
        log.err("Cap get resource derived should EPERM");
        // Lopeta testi.
        return;
    }
    // Kysy parent uudelleen — resurssitunniste säilyy.
    const parent_again = dispatch.invoke(abi.SYS_cap_get_resource, slot, 0, 0, 0, 0, 0);
    // Varmista parent port_id ei muuttunut.
    if (parent_again != @as(i64, @intCast(port_id))) {
        // Parent-resurssitunniste muuttui delegoinnin jälkeen.
        log.err("Cap get resource parent changed");
        // Lopeta testi.
        return;
    }
    // Kernel invoke-testi OK.
    log.info("Cap get resource syscall OK");
    // Lataa cap_get_resource_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(cap_get_resource_test_elf, CAP_GET_RESOURCE_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland cap get resource ELF load failed");
        // Lopeta testi.
        return;
    };
    // Kirjoita slot boot-info-osoitteeseen.
    const slot_ptr: *u32 = @ptrFromInt(CAP_GET_RESOURCE_SLOT_VADDR);
    // Kirjoita odotettu port_id boot-info-osoitteeseen.
    const expect_ptr: *u32 = @ptrFromInt(CAP_GET_RESOURCE_EXPECT_VADDR);
    // SMAP: salli user-sivujen kirjoitus kernelistä.
    user_access.stac();
    // Tallenna parent capability-slotti ring 3 -testiä varten.
    slot_ptr.* = slot;
    // Tallenna odotettu port_id ring 3 -testiä varten.
    expect_ptr.* = @intCast(port_id);
    // Palauta SMAP-suojaus.
    user_access.clac();
    // Siirry ring 3:een capGetResourceMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland cap get resource OK".
    log.info("Userland cap get resource test OK");
}
