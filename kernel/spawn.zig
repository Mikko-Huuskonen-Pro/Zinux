//! Prosessin luonti — upotetut spawn-ELF:t ja runProcess (Vaihe 21).
//!
//! **Vastuu**: Lataa embedded user-ELF uudelle pid:lle, siirry ring 3:een.
//! **Riippuvuudet**: `loader/elf.zig`, `process_core`, `usermode.zig`
//! **Käytetään**: `syscall/spawn_syscall.zig`, `syscall/dispatch.zig`

// Tuo ELF-loader — PT_LOAD + erillinen pinokartoitus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq tietyllä pid:llä.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo prosessitaulukko — pid-allokaatio ja ladatut kentät.
const process = @import("process_core");
// Tuo VMM — prosessikohtainen PML4 (Vaihe 25).
const vmm = @import("mm/vmm.zig");

// Upotettu spawn-lapsi A — build.zig kopioi ennen kernel-käännöstä.
const spawn_child_a_elf = @embedFile("loader/spawn_child_a_prog.bin");
// Upotettu spawn-lapsi B — eri load-osoite ja pinokartoitus.
const spawn_child_b_elf = @embedFile("loader/spawn_child_b_prog.bin");
// Upotettu spawn-lapsi exit — sys_exit(42) (Vaihe 24).
const spawn_child_exit_elf = @embedFile("loader/spawn_child_exit_prog.bin");
// Upotettu address space A — sama VA kuin B (Vaihe 25).
const address_space_a_elf = @embedFile("loader/address_space_a_prog.bin");
// Upotettu address space B — sama VA kuin A (Vaihe 25).
const address_space_b_elf = @embedFile("loader/address_space_b_prog.bin");
// Upotettu preempt A — timer-preempt demo (Vaihe 26).
const preempt_a_elf = @embedFile("loader/preempt_a_prog.bin");
// Upotettu preempt B — timer-preempt demo (Vaihe 26).
const preempt_b_elf = @embedFile("loader/preempt_b_prog.bin");
// Upotettu cross-spawn IPC lapsi — recv ring 3:ssa (Vaihe 27).
const cross_spawn_ipc_child_elf = @embedFile("loader/cross_spawn_ipc_child_prog.bin");

// Embedded ELF -tunniste: spawn-lapsi A.
pub const SPAWN_ID_CHILD_A: u64 = 0;
// Embedded ELF -tunniste: spawn-lapsi B.
pub const SPAWN_ID_CHILD_B: u64 = 1;
// Embedded ELF -tunniste: spawn-lapsi exit (sys_exit).
pub const SPAWN_ID_EXIT: u64 = 2;
// Embedded ELF -tunniste: address space demo A (Vaihe 25).
pub const SPAWN_ID_ASPACE_A: u64 = 3;
// Embedded ELF -tunniste: address space demo B (Vaihe 25).
pub const SPAWN_ID_ASPACE_B: u64 = 4;
// Embedded ELF -tunniste: preempt demo A (Vaihe 26).
pub const SPAWN_ID_PREEMPT_A: u64 = 5;
// Embedded ELF -tunniste: preempt demo B (Vaihe 26).
pub const SPAWN_ID_PREEMPT_B: u64 = 6;
// Embedded ELF -tunniste: cross-spawn IPC lapsi (Vaihe 27).
pub const SPAWN_ID_CROSS_SPAWN_CHILD: u64 = 7;
// Sama virtuaalinen latausosoite molemmille address space -lapsille.
pub const ADDRESS_SPACE_LOAD_VADDR: u64 = 0xFFFFFFFF90090000;

// Pinon heap-slot lapsi A:lle — erillään muista user-ELF:istä (slot 112).
const SPAWN_CHILD_A_STACK_SLOT: u64 = 112;
// Pinon heap-slot lapsi B:lle — seuraava vapaa sivu (slot 113).
const SPAWN_CHILD_B_STACK_SLOT: u64 = 113;
// Pinon heap-slot exit-lapselle — erillinen sivu (slot 115).
const SPAWN_CHILD_EXIT_STACK_SLOT: u64 = 115;
// Pinon heap-slot address space A (slot 116).
const SPAWN_ASPACE_A_STACK_SLOT: u64 = 116;
// Pinon heap-slot address space B (slot 117).
const SPAWN_ASPACE_B_STACK_SLOT: u64 = 117;
// Pinon heap-slot preempt A (slot 118).
const SPAWN_PREEMPT_A_STACK_SLOT: u64 = 118;
// Pinon heap-slot preempt B (slot 119).
const SPAWN_PREEMPT_B_STACK_SLOT: u64 = 119;
// Pinon heap-slot cross-spawn IPC lapsi (slot 121).
const SPAWN_CROSS_SPAWN_CHILD_STACK_SLOT: u64 = 121;

// Luo uusi prosessi upotetusta ELF:stä — palauttaa pid tai null.
pub fn spawnEmbedded(id: u64) ?u64 {
    // Valitse ELF-blob tunnisteen mukaan.
    const elf_data: []const u8 = switch (id) {
        // Lapsi A — tulostaa "spa\n" serialiin.
        SPAWN_ID_CHILD_A => spawn_child_a_elf,
        // Lapsi B — tulostaa "spb\n" serialiin.
        SPAWN_ID_CHILD_B => spawn_child_b_elf,
        // Exit-lapsi — kutsuu sys_exit(42).
        SPAWN_ID_EXIT => spawn_child_exit_elf,
        // Address space A — sama VA kuin B (Vaihe 25).
        SPAWN_ID_ASPACE_A => address_space_a_elf,
        // Address space B — sama VA kuin A (Vaihe 25).
        SPAWN_ID_ASPACE_B => address_space_b_elf,
        // Preempt A — tulostaa 'A' silmukassa (Vaihe 26).
        SPAWN_ID_PREEMPT_A => preempt_a_elf,
        // Preempt B — tulostaa 'B' silmukassa (Vaihe 26).
        SPAWN_ID_PREEMPT_B => preempt_b_elf,
        // Cross-spawn IPC lapsi — vastaanottaa viestin (Vaihe 27).
        SPAWN_ID_CROSS_SPAWN_CHILD => cross_spawn_ipc_child_elf,
        // Tuntematon tunniste.
        else => return null,
    };
    // Valitse erillinen pinokartoitus per lapsi.
    const stack_slot: u64 = switch (id) {
        // Lapsi A pinosivu slot 112.
        SPAWN_ID_CHILD_A => SPAWN_CHILD_A_STACK_SLOT,
        // Lapsi B pinosivu slot 113.
        SPAWN_ID_CHILD_B => SPAWN_CHILD_B_STACK_SLOT,
        // Exit-lapsi pinosivu slot 115.
        SPAWN_ID_EXIT => SPAWN_CHILD_EXIT_STACK_SLOT,
        // Address space A pinosivu slot 116.
        SPAWN_ID_ASPACE_A => SPAWN_ASPACE_A_STACK_SLOT,
        // Address space B pinosivu slot 117.
        SPAWN_ID_ASPACE_B => SPAWN_ASPACE_B_STACK_SLOT,
        // Preempt A pinosivu slot 118.
        SPAWN_ID_PREEMPT_A => SPAWN_PREEMPT_A_STACK_SLOT,
        // Preempt B pinosivu slot 119.
        SPAWN_ID_PREEMPT_B => SPAWN_PREEMPT_B_STACK_SLOT,
        // Cross-spawn IPC lapsi pinosivu slot 121.
        SPAWN_ID_CROSS_SPAWN_CHILD => SPAWN_CROSS_SPAWN_CHILD_STACK_SLOT,
        // Tuntematon tunniste.
        else => return null,
    };
    // Allokoi seuraava vapaa pid prosessitaulukosta.
    const pid = process.allocNextPid() orelse return null;
    // Aseta vanhemmaksi nykyinen prosessi (Vaihe 24 parent/child).
    if (!process.setParentPid(pid, process.currentPid())) return null;
    // Varmista kernel CR3 ennen fork/load — ring 3 parent voi jättää CR3:n väärään tilaan.
    vmm.switchToKernel();
    // Luo prosessin oma PML4 — syväkopio kernelistä (Vaihe 25).
    const pml4 = vmm.createProcessPageTable() orelse return null;
    // Eristä sama-VA spawn-ELF (address space / preempt) — ei spawn-lapsia 0/1.
    // Cross-spawn lapsi (7) ohitetaan: prepareSpawnPageTable aiheuttaa page faultin ring 3 spawnista.
    if (id >= SPAWN_ID_ASPACE_A and id != SPAWN_ID_CROSS_SPAWN_CHILD) {
        vmm.prepareSpawnPageTable(pml4, ADDRESS_SPACE_LOAD_VADDR);
    }
    // Tallenna CR3 prosessitaulukkoon.
    if (!process.setPageTable(pid, pml4)) return null;
    // Lataa ELF segmentit + pino prosessin osoiteavaruuteen.
    const loaded = elf.loadElfWithStackInto(elf_data, stack_slot, pml4) orelse return null;
    // Tallenna entry/pino prosessitaulukkoon spawn/runProcess varten.
    if (!process.setLoaded(pid, loaded.entry, loaded.stack_top, stack_slot)) return null;
    // Palauta kernel CR3 ennen paluuta syscall-käsittelijään (Vaihe 27).
    vmm.switchToKernel();
    // Palauta uuden prosessin tunniste.
    return pid;
}

// Suorita aiemmin spawnattu prosessi ring 3:ssa — palaa sys_test_return:in jälkeen.
pub fn runProcess(pid: u64) bool {
    // Hae ladatun prosessin entry ja pino.
    const info = process.getLoadedInfo(pid) orelse return false;
    // Siirry ring 3:een annetulla pid:llä (getpid toimii oikein).
    usermode.enterUserAs(info.entry, info.stack_top, pid);
    // Paluu sys_test_return ret:llä — prosessi suoritettu.
    return true;
}
