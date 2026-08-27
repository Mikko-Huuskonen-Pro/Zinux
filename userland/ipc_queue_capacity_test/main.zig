//! IPC queue capacity userland boot-testi — ipc.queueCapacity + pending ≤ capacity.
//!
//! **Vastuu**: Testaa jonon maksimisyvyyden kysely ring 3:ssa.
//! **Riippuvuudet**: `cap`, `ipc`, `syscall.zig`
//! **Käytetään**: start.S → ipcQueueCapacityMain

// Tuo userland capability-kirjasto — createPort.
const cap = @import("cap");
// Tuo userland IPC-kirjasto.
const ipc = @import("ipc");
// Tuo syscall wrapperit tulostukseen ja paluuseen.
const sc = @import("syscall.zig");

// Ipc queue capacity -testin sisäänkäynti — start.S kutsuu tätä.
export fn ipcQueueCapacityMain() void {
    // Oikeudet send + recv uudelle portille.
    const rights = cap.MASK_SEND | cap.MASK_RECV;
    // Luo uusi portti-capability ring 3:ssa.
    const slot = cap.createPort(rights) catch {
        // Luonti epäonnistui.
        sc.print("ipc queue capacity create failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy jonon maksimisyvyys — pitää olla ipc.MAX_QUEUE.
    const capacity = ipc.queueCapacity(slot) catch {
        // Capacity-kysely epäonnistui.
        sc.print("ipc queue capacity query failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista maksimijonon syvyys.
    if (capacity != ipc.MAX_QUEUE) {
        // Odotettiin MAX_QUEUE.
        sc.print("ipc queue capacity wrong max\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kysy pending tyhjällä jonolla — pitää olla 0.
    const empty = ipc.pending(slot) catch {
        // Pending-kysely epäonnistui.
        sc.print("ipc queue capacity pending empty failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista tyhjä jono.
    if (empty != 0) {
        // Odotettiin nollaa odottavia viestejä.
        sc.print("ipc queue capacity pending empty should be 0\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Lähetä yksi viesti — pending kasvaa mutta pysyy ≤ capacity.
    const msg = "QCP";
    // Lähetä viesti porttiin.
    _ = ipc.send(slot, msg) catch {
        // Send epäonnistui.
        sc.print("ipc queue capacity send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Kysy pending viestin jälkeen — pitää olla 1.
    const pending = ipc.pending(slot) catch {
        // Pending-kysely epäonnistui.
        sc.print("ipc queue capacity pending after send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista yksi odottava viesti.
    if (pending != 1) {
        // Odotettiin yhtä odottavaa viestiä.
        sc.print("ipc queue capacity pending after send should be 1\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Kapasiteetti ei muutu lähetyksen jälkeen.
    const capacity2 = ipc.queueCapacity(slot) catch {
        // Capacity-kysely epäonnistui.
        sc.print("ipc queue capacity query after send failed\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    };
    // Varmista maksimisyvyys edelleen MAX_QUEUE.
    if (capacity2 != ipc.MAX_QUEUE) {
        // Kapasiteetti muuttui — ei pitäisi tapahtua.
        sc.print("ipc queue capacity changed after send\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Varmista pending ≤ capacity.
    if (pending > capacity2) {
        // Pending ylitti kapasiteetin — virhetila.
        sc.print("ipc queue capacity pending exceeds max\n");
        // Palaa kerneliin.
        sc.sysTestReturn();
    }
    // Vahvistus serialiin ennen paluuta.
    sc.print("userland ipc queue capacity OK\n");
    // Palaa kerneliin — kernel lokittaa "Userland IPC queue capacity test OK".
    sc.sysTestReturn();
}

// Pakota linkittäjän säilyttämään ipcQueueCapacityMain.
pub export fn ipcQueueCapacityAnchor() void {}
