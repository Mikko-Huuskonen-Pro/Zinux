//! Userland IPC boot-testi — lataa ipc_test-ELF, ring 3 ipc.zig-demo.
//!
//! **Vastuu**: Luo portti+cap slot 4, aja userland ipc send/recv roundtrip.
//! **Riippuvuudet**: `loader/elf.zig`, `ipc/port.zig`, `capability_core.zig`, `usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo IPC-portit — createPort boot-testiportille.
const port = @import("ipc/port.zig");
// Tuo capability — createAndInstall slotille.
const cap = @import("ipc/capability_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu IPC-testi-ELF — build.zig kopioi userland/ipc_test ennen kernel-käännöstä.
const ipc_test_elf = @embedFile("loader/ipc_test_prog.bin");

// IPC-testin pinon heap-slot — erillään driver (83) ja shell (67) sloteista.
const IPC_TEST_STACK_SLOT: u64 = 99;

// Boot-testi — luo portti+cap, lataa ipc_test-ELF, hyppää ring 3:een.
pub fn runBootTest() void {
    // Luo fyysinen IPC-portti userland-testille.
    const port_id = port.createPort() orelse {
        // Portin luonti epäonnistui.
        log.err("Userland IPC port create failed");
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
    // Asenna capability portille — slot 4 kun aiemmat testit käyttävät 0–3.
    const slot = cap.createAndInstall(.port, 1, port_id, rights) orelse {
        // Capability-asennus epäonnistui.
        log.err("Userland IPC cap install failed");
        // Lopeta testi.
        return;
    };
    // Varmista odotettu slotti — boot-testi olettaa slot 4.
    if (slot != 4) {
        // Slot-indeksi muuttunut — boot-testi ei luotettava.
        log.err("Userland IPC unexpected slot");
        // Lopeta testi.
        return;
    }
    // Lataa ipc_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(ipc_test_elf, IPC_TEST_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland IPC ELF load failed");
        // Lopeta testi.
        return;
    };
    // Siirry ring 3:een ipcMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland ipc OK".
    log.info("Userland IPC test OK");
}
