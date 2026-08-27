//! Userland capability boot-testi — lataa cap_test-ELF, ring 3 delegate-demo.
//!
//! **Vastuu**: Luo portti+cap slot 5, pre-send viesti, aja cap delegate + ipc test.
//! **Riippuvuudet**: `loader/elf.zig`, `ipc/port.zig`, `capability_core.zig`, `usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo IPC-portit — createPort sendViaSlot.
const port = @import("ipc/port.zig");
// Tuo capability — createAndInstall slotille.
const cap = @import("ipc/capability_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");
// Tuo user_access — SMAP-yhteensopiva kirjoitus user-sivulle.
const user_access = @import("arch/x86_64/user_access.zig");

// Upotettu cap-testi-ELF — build.zig kopioi userland/cap_test ennen kernel-käännöstä.
const cap_test_elf = @embedFile("loader/cap_test_prog.bin");

// Cap-testin pinon heap-slot — erillään ipc (99) ja driver (83) sloteista.
const CAP_TEST_STACK_SLOT: u64 = 101;
// Cap boot-info — kernel kirjoittaa parent-slotin ennen ring 3 (user.ld .capboot).
const CAP_PARENT_SLOT_VADDR: u64 = 0xFFFFFFFF90071000;

// Boot-testi — luo portti+cap, lähetä viesti, hyppää ring 3:een.
pub fn runBootTest() void {
    // Luo fyysinen IPC-portti userland-delegointitestille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Userland cap port create failed");
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
    // Asenna capability portille boot-prosessille.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("Userland cap cap install failed");
        // Lopeta testi.
        return;
    };
    // Lähetä viesti parent-slotilla ennen ring 3 -testiä.
    const msg = "CAP";
    // Jonota viesti porttiin parent-slotin kautta.
    const sent = port.sendViaSlot(slot, msg) catch {
        // Send epäonnistui.
        log.err("Userland cap pre-send failed");
        // Lopeta testi.
        return;
    };
    // Varmista lähetyksen pituus.
    if (sent != msg.len) {
        // Väärä lähetetty määrä.
        log.err("Userland cap pre-send length mismatch");
        // Lopeta testi.
        return;
    }
    // Lataa cap_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(cap_test_elf, CAP_TEST_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland cap ELF load failed");
        // Lopeta testi.
        return;
    };
    // Kirjoita parent-slot userland .capboot-osoitteeseen.
    const slot_ptr: *u32 = @ptrFromInt(CAP_PARENT_SLOT_VADDR);
    // SMAP: salli user-sivun kirjoitus kernelistä.
    user_access.stac();
    // Tallenna parent capability-slotti ring 3 -testiä varten.
    slot_ptr.* = slot;
    // Palauta SMAP-suojaus.
    user_access.clac();
    // Siirry ring 3:een capMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland cap OK".
    log.info("Userland cap test OK");
}
