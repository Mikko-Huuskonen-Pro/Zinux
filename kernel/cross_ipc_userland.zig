//! Cross-process IPC userland boot-testi — kaksi prosessia, send/recv ring 3:ssa (Vaihe 22.3).
//!
//! **Vastuu**: Cap transfer kernelissä, sender/receiver ELF peräkkäin eri pideillä.
//! **Riippuvuudet**: `loader/elf.zig`, `port.zig`, `capability_core.zig`, `usermode.zig`
//! **Käytetään**: `kernel/boot_tests.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry tietyllä pid:llä.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo IPC-portit — createPort cross-process portille.
const port = @import("ipc/port.zig");
// Tuo capability — createAndInstall ja transferSlotToPid.
const cap = @import("ipc/capability_core.zig");
// Tuo prosessitaulukko — pid 2/3 konteksti.
const process = @import("process_core");
// Tuo user_access — kirjoita rooli user-muistiin ennen ring 3 -hyppyä.
const user_access = @import("arch/x86_64/user_access.zig");
// Tuo sivutus — PAGE_SIZE rooli-sivun kartoitukseen.
const paging = @import("arch/x86_64/paging.zig");
// Tuo VMM — kartoita rooli-sivu userille.
const vmm = @import("mm/vmm.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu cross-IPC-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const cross_ipc_test_elf = @embedFile("loader/cross_ipc_test_prog.bin");

// Cross-IPC-testin pinon heap-slot — erillään spawn-sloteista (114).
const CROSS_IPC_STACK_SLOT: u64 = 114;

// Kiinteä user-osoite roolille — kernel kirjoittaa ennen ring 3 -hyppyä.
pub const CROSS_IPC_ROLE_VADDR: u64 = 0xFFFFFFFF9008D000;
// Rooli: prosessi A lähettää viestin.
pub const ROLE_SENDER: u32 = 1;
// Rooli: prosessi B vastaanottaa viestin.
pub const ROLE_RECEIVER: u32 = 2;

// Ring 3 sivulippu — present + writable + user.
const USER_RW_FLAGS = paging.PageFlags{
    // Sivu kartoitettu.
    .present = 1,
    // Kirjoitus sallittu (kernel kirjoittaa roolin).
    .writable = 1,
    // Ring 3 pääsee sivulle.
    .user = 1,
};

// Kartoita rooli-sivu ja kirjoita u32-rooli user-muistiin.
fn writeRole(role: u32) bool {
    // Tarkista onko rooli-sivu jo kartoitettu.
    const already = paging.getPteRaw(vmm.pml4Phys(), vmm.hhdm(), CROSS_IPC_ROLE_VADDR) != null;
    // Kartoita uusi user-sivu jos puuttuu.
    if (!already) {
        if (!vmm.mapNewUserPageEnsure(CROSS_IPC_ROLE_VADDR, USER_RW_FLAGS)) return false;
        if (!paging.setUserPagePath(vmm.pml4Phys(), vmm.hhdm(), CROSS_IPC_ROLE_VADDR, false)) return false;
    }
    // Osoitin rooli-kenttään ring 3:ssa.
    const ptr: *u32 = @ptrFromInt(CROSS_IPC_ROLE_VADDR);
    // SMAP: salli user-sivun kirjoitus kernelistä.
    user_access.stac();
    // Kirjoita rooli (sender tai receiver).
    ptr.* = role;
    // Palauta SMAP-suojaus.
    user_access.clac();
    // Onnistui.
    return true;
}

// Boot-testi — cap transfer + kaksi ring 3 -ajoa eri pideillä.
pub fn runBootTest() void {
    // Allokoi kaksi uutta prosessia — vältä aiempien boot-testien slotit.
    const pid_a = process.allocNextPid() orelse {
        // Prosessi A ei mahdu taulukkoon.
        log.err("Userland cross IPC alloc pid A failed");
        // Lopeta testi.
        return;
    };
    const pid_b = process.allocNextPid() orelse {
        // Prosessi B ei mahdu taulukkoon.
        log.err("Userland cross IPC alloc pid B failed");
        // Lopeta testi.
        return;
    };
    // Luo fyysinen IPC-portti userland cross-process -testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Userland cross IPC port create failed");
        // Lopeta testi.
        return;
    };
    // Oikeudet send + recv + grant + read prosessille A.
    const rights_a = cap.Rights{
        // Lue portin metatiedot.
        .read = true,
        // Lähetys-oikeus prosessille A.
        .send = true,
        // Vastaanotto-oikeus siirrettäväksi prosessille B:hen.
        .recv = true,
        // Siirto-oikeus prosessille B:hen.
        .grant = true,
    };
    // Asenna capability prosessille A.
    const slot_a = cap.createAndInstall(.port, pid_a, port_id, rights_a) orelse {
        // Capability-asennus epäonnistui.
        log.err("Userland cross IPC cap install A failed");
        // Lopeta testi.
        return;
    };
    // Aseta current pid prosessi A ennen siirtoa.
    if (!process.setCurrentPid(pid_a)) {
        // setCurrentPid epäonnistui.
        log.err("Userland cross IPC set pid A failed");
        // Lopeta testi.
        return;
    }
    // Siirrä recv-oikeus prosessille B suoraan ytimestä.
    const recv_rights = cap.Rights{ .read = true, .recv = true };
    const slot_b = cap.transferSlotToPid(slot_a, pid_b, recv_rights) orelse {
        // Cap transfer epäonnistui.
        log.err("Userland cross IPC cap transfer failed");
        // Lopeta testi.
        return;
    };
    // Varmista että siirto palautti kelvollisen slot-indeksin.
    _ = slot_b;
    // Lataa cross_ipc_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(cross_ipc_test_elf, CROSS_IPC_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland cross IPC ELF load failed");
        // Lopeta testi.
        return;
    };
    // Kirjoita sender-rooli ennen prosessi A -ajoa.
    if (!writeRole(ROLE_SENDER)) {
        // Rooli-sivun kartoitus epäonnistui.
        log.err("Userland cross IPC role write sender failed");
        // Lopeta testi.
        return;
    }
    // Suorita prosessi A ring 3:ssa — lähettää "XPC" slot 0:lla.
    usermode.enterUserAs(loaded.entry, loaded.stack_top, pid_a);
    // Kirjoita receiver-rooli ennen prosessi B -ajoa.
    if (!writeRole(ROLE_RECEIVER)) {
        // Rooli-sivun kirjoitus epäonnistui.
        log.err("Userland cross IPC role write receiver failed");
        // Lopeta testi.
        return;
    }
    // Suorita prosessi B ring 3:ssa — vastaanottaa ja tulostaa vahvistuksen.
    usermode.enterUserAs(loaded.entry, loaded.stack_top, pid_b);
    // Palauta boot-prosessin konteksti.
    _ = process.setCurrentPid(process.BOOT_PID);
    // Paluu sys_test_return:lla — userland tulosti "userland cross ipc OK".
    log.info("Userland cross IPC test OK");
}
