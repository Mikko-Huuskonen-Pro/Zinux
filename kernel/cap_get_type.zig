//! Capability get type boot-testi — invoke + userland ring 3 yhdellä slotilla.
//!
//! **Vastuu**: sys_cap_get_type, revoke vapauttaa portin, cap.getType ring 3:ssa.
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
// Tuo capability-syscall-ydin — CAP_TYPE_PORT vakio.
const cap_core = @import("syscall/cap_syscall_core.zig");
// Tuo user_access — SMAP-yhteensopiva kirjoitus user-sivulle.
const user_access = @import("arch/x86_64/user_access.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu cap_get_type-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const cap_get_type_test_elf = @embedFile("loader/cap_get_type_test_prog.bin");

// Cap get type -testin pinon heap-slot — erillään muista user-ELF:istä.
const CAP_GET_TYPE_STACK_SLOT: u64 = 108;
// Boot-info — kernel kirjoittaa slot ennen ring 3 -hyppyä (.capboot user.ld).
const CAP_GET_TYPE_SLOT_VADDR: u64 = 0xFFFFFFFF90087000;
// Boot-info — odotettu tyyppi (portti = 1) slotin jälkeen (+4).
const CAP_GET_TYPE_EXPECT_VADDR: u64 = 0xFFFFFFFF90087004;

// Boot-testi — invoke get_type + revoke port cleanup + userland ELF.
pub fn runBootTest() void {
    // Luo uusi IPC-portti get-type-testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Cap get type port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet send + recv boot-prosessille (pid 1 stub).
    const rights = cap.Rights{
        // Lue portin metatiedot (stub).
        .read = true,
        // send-oikeus.
        .send = true,
        // recv-oikeus.
        .recv = true,
    };
    // Asenna capability portille.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("Cap get type cap install failed");
        // Lopeta testi.
        return;
    };
    // Kysy slotin tyyppi invoke()-kautta — pitää olla portti.
    const typ = dispatch.invoke(abi.SYS_cap_get_type, slot, 0, 0, 0, 0, 0);
    // Varmista portti-tyyppi.
    if (typ != @as(i64, @intCast(cap_core.CAP_TYPE_PORT))) {
        // Väärä capability-tyyppi.
        log.err("Cap get type wrong type");
        // Lopeta testi.
        return;
    }
    // Peruuta capability — pitää vapauttaa IPC-portti.
    const revoked = dispatch.invoke(abi.SYS_cap_revoke, slot, 0, 0, 0, 0, 0);
    // Varmista peruutus onnistui.
    if (revoked != 0) {
        // Revoke epäonnistui.
        log.err("Cap get type revoke failed");
        // Lopeta testi.
        return;
    }
    // Kysy tyyppi peruutetusta slotista — pitää palauttaa EBADF.
    const bad_typ = dispatch.invoke(abi.SYS_cap_get_type, slot, 0, 0, 0, 0, 0);
    // Varmista mitätöity slotti.
    if (bad_typ != abi.EBADF) {
        // Odotettiin EBADF peruutetulle slotille.
        log.err("Cap get type revoked should EBADF");
        // Lopeta testi.
        return;
    }
    // Luo uusi portti — portin pitää olla vapautunut peruutuksessa.
    if (port.createPort() == null) {
        // Portin uudelleenluonti epäonnistui — cleanup puuttuu.
        log.err("Cap get type port reuse failed");
        // Lopeta testi.
        return;
    }
    // Kernel invoke-testi OK.
    log.info("Cap get type syscall OK");
    // Luo erillinen portti+cap userland ring 3 -testille.
    const ul_port_id = port.createPort() orelse {
        // Portin luonti userland-testille epäonnistui.
        log.err("Cap get type userland port create failed");
        // Lopeta testi.
        return;
    };
    // Asenna capability userland-testin portille.
    const ul_slot = cap.createAndInstall(.port, 1, ul_port_id, rights) orelse {
        // Capability-asennus userland-testille epäonnistui.
        log.err("Cap get type userland cap install failed");
        // Lopeta testi.
        return;
    };
    // Lataa cap_get_type_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(cap_get_type_test_elf, CAP_GET_TYPE_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland cap get type ELF load failed");
        // Lopeta testi.
        return;
    };
    // Kirjoita slot boot-info-osoitteeseen.
    const slot_ptr: *u32 = @ptrFromInt(CAP_GET_TYPE_SLOT_VADDR);
    // Kirjoita odotettu tyyppi boot-info-osoitteeseen.
    const expect_ptr: *u32 = @ptrFromInt(CAP_GET_TYPE_EXPECT_VADDR);
    // SMAP: salli user-sivujen kirjoitus kernelistä.
    user_access.stac();
    // Tallenna capability-slotti ring 3 -testiä varten.
    slot_ptr.* = ul_slot;
    // Tallenna odotettu portti-tyyppi ring 3 -testiä varten.
    expect_ptr.* = cap_core.CAP_TYPE_PORT;
    // Palauta SMAP-suojaus.
    user_access.clac();
    // Siirry ring 3:een capGetTypeMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland cap get type OK".
    log.info("Userland cap get type test OK");
}
