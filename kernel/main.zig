//! Zinux kernel — pääsisäänkäynti.
//!
//! **Vastuu**: `_start` → early boot → kmain-alustus → idle loop.
//! **Riippuvuudet**: boot, arch, mm, lib
//! **Käytetään**: Limine lataa tämän ELF-binäärin

// Tuo early boot -alustus (UART ennen Limine-validointia).
const boot = @import("boot/entry.zig");
// Tuo Limine request -ankkuri (linksection .limine_requests).
const requests = @import("boot/requests.zig");
// Tuo Limine boot-info ja muistikartan luku.
const limine_boot = @import("boot/limine.zig");
// Tuo Limine → PMM muunnos ja alustus.
const mem_init = @import("boot/mem.zig");
// Tuo lokitusmoduuli (UART + VGA).
const log = @import("lib/log.zig");
// Tuo GDT — segmenttien alustus (Vaihe 2).
const gdt = @import("arch/x86_64/gdt.zig");
// Tuo IDT — keskeytykset ja page fault (Vaihe 2).
const idt = @import("arch/x86_64/idt.zig");
// Tuo PMM — fyysisten kehysten bitmap-allokaattori (Vaihe 2).
const pmm = @import("mm/pmm.zig");
// Tuo VMM — virtuaalimuistin hallinta (Vaihe 2).
const vmm = @import("mm/vmm.zig");
// Tuo kernel heap — first-fit allokaattori (Vaihe 2).
const heap = @import("mm/heap.zig");
// Tuo muistitestit — 100 kehystä + heap smoke test.
const memtest = @import("mm/memtest.zig");
// Tuo PIC — keskeytysohjaimen remap ja EOI (Vaihe 3).
const pic = @import("arch/x86_64/pic.zig");
// Tuo PIT — timer IRQ0 aikataulutusta varten (Vaihe 3).
const pit = @import("drivers/timer/pit.zig");
// Tuo scheduler — kaksi säiettä coop-yield (Vaihe 3).
const scheduler = @import("sched/scheduler.zig");
// Tuo SMP stub — Limine CPU-määrä (Vaihe 3).
const smp = @import("boot/smp.zig");
// Tuo PIT ticks — linkittää timerOnIrqC timer_irq.S:lle.
const pit_ticks = @import("lib/pit_ticks.zig");
// Tuo SYSCALL MSR-alustus (Vaihe 4.1).
const syscall = @import("arch/x86_64/syscall.zig");
// Tuo syscall dispatch — handler-taulukko (Vaihe 4.2).
const dispatch = @import("syscall/dispatch.zig");
// Tuo capability-hallinta (Vaihe 4.3).
const capability = @import("ipc/capability.zig");
// Tuo IPC-portit (Vaihe 4.4).
const port = @import("ipc/port.zig");
// Tuo ring 3 usermode (Vaihe 4.5).
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo SMEP/SMAP kovennus (Vaihe 7.1).
const hardening = @import("arch/x86_64/hardening.zig");
// Tuo pinon canaryt (Vaihe 7.2).
const stack_canary = @import("arch/x86_64/stack_canary.zig");
// Tuo KASLR — satunnainen user/heap-slide (Vaihe 7.3).
const kaslr = @import("arch/x86_64/kaslr.zig");

// Early boot -pino — 16 KiB, 16-tavun aligned (x86_64 vaatimus).
extern var early_stack: [16 * 1024]u8 align(16);

// Limine siirtyy tähän — aseta pino ja kutsu kmain.
pub export fn _start() callconv(.c) noreturn {
    // Laske pinon yläreuna (kasvaa alaspäin x86_64:ssä).
    const stack_top = @intFromPtr(&early_stack) + early_stack.len;
    // Aseta RSP inline ennen mitään call-operaatiota (return address vaatii oikean pinon).
    asm volatile ("mov %[stack], %%rsp"
        :
        : [stack] "r" (stack_top),
    );
    // Pakota linkittäjän säilyttämään Limine request -osio.
    requests.anchor();
    // Early init: UART + Limine validointi + VGA log init.
    boot.earlyInit();
    // Siirry pääalustukseen — ei palaa takaisin.
    kmain();
}

// Kernel pääfunktio — alustaa alijärjestelmät järjestyksessä.
fn kmain() noreturn {
    // Tulosta boot-viesti serialiin ja VGA:han.
    log.info("Zinux kernel starting...");
    // Tulosta kohdealusta debug-lokitusta varten.
    log.info("Target: x86_64 freestanding");
    // Alusta GDT — kernel code/data segmentit.
    gdt.init();
    // Vahvista GDT-alustus onnistui.
    log.info("GDT initialized");
    // Alusta IDT — page fault #14 oikea handler, muut stub.
    idt.init();
    // Vahvista IDT-alustus onnistui.
    log.info("IDT initialized");
    // Alusta SYSCALL MSRs (STAR/LSTAR/SFMASK + EFER.SCE) — IDT:n jälkeen.
    syscall.init();
    // Vahvista syscall entry -osoite on asetettu.
    log.info("Syscall MSRs initialized");
    // Hae Limine boot-info (HHDM offset jne.).
    const boot_info = limine_boot.getBootInfo();
    // Alusta PMM Limine-muistikartasta tai fallback 256 MiB.
    if (limine_boot.getMemoryMapEntries()) |entries| {
        // Muunna Limine map → PMM bitmap.
        mem_init.initPmmFromLimine(entries);
        // Vahvista PMM Limine-kartasta.
        log.info("PMM initialized (Limine map)");
    } else {
        // Fallback jos muistikartta puuttuu (ei pitäisi tapahtua Liminessä).
        pmm.initFallback(256 * 1024 * 1024);
        // Vahvista PMM fallback-tilassa.
        log.info("PMM initialized (fallback 256MiB)");
    }
    // Testaa PMM — allokoi ja vapauta yksi kehys boot-vaiheessa.
    if (pmm.allocFrame()) |frame| {
        // Vapauta kehys heti — boot-testi että bitmap toimii.
        pmm.freeFrame(frame);
        // Vahvista PMM allokoi/vapauttaa kehyksiä.
        log.info("PMM alloc test OK");
    }
    // Alusta VMM — tallenna HHDM ja Liminen CR3 (PML4).
    vmm.init(boot_info.hhdm_offset);
    // Vahvista VMM-alustus onnistui.
    log.info("VMM initialized");
    // Laske KASLR-slide ennen heap/user-kartoitusta (Vaihe 7.3).
    kaslr.init(boot_info.hhdm_offset);
    // Alusta kernel heap — kartoittaa INITIAL_PAGES sivua slidattuun alkuun.
    heap.init();
    // Vahvista KASLR-slide aktivoitunut.
    kaslr.runBootTest();
    // Vahvista heap-alustus onnistui.
    log.info("Heap initialized");
    // Aja Vaihe 2 integraatiotestit (100 kehystä + heap smoke test).
    memtest.runAll();
    // Boot on valmis — CI etsii tämän merkkijonon serialista.
    log.info("Zinux boot OK");
    // Vaihe 4.2 — dispatch boot-testi (sys_write → serial "SY").
    dispatch.runBootTest();
    // Vaihe 4.3 — capability boot-testi (create + delegate).
    capability.runBootTest();
    // Vaihe 4.4 — IPC-portti boot-testi (send/recv capability-slotin kautta).
    port.runBootTest();
    // Vaihe 7.4 — capability-audit-loki (create/delegate rengaspuskuri).
    const cap_audit = @import("ipc/cap_audit.zig");
    cap_audit.runBootTest();
    // Ota SMEP/SMAP käyttöön ennen ring 3 -testejä (Vaihe 7.1).
    hardening.init();
    // Vahvista SMEP/SMAP aktivointi.
    hardening.runBootTest();
    // Maalaa canaryt kernel-pinoihin (early, syscall, TSS) — Vaihe 7.2.
    stack_canary.init();
    // Vahvista canaryt ennen ring 3 -testejä.
    stack_canary.runBootTest();
    // Vaihe 4.5 — ring 3 sys_write("hello") SYSCALL:lla.
    usermode.runBootTest();
    // Vaihe 5.1 — ELF-loader: lataa upotettu user-ELF ja aja "elf".
    const elf_loader = @import("loader/elf.zig");
    elf_loader.runBootTest();
    // Vaihe 5.2 — init-prosessi ELF-loaderilla (sys_write "init\n").
    const init_proc = @import("init.zig");
    init_proc.launch();
    // Vaihe 5.3/5.5 — shell-komennot (help, meminfo, ps) boot-testinä.
    const shell_proc = @import("shell.zig");
    shell_proc.runBootTest();
    // --- Vaihe 3: aikataulutus ---
    // Remapaa PIC IRQ:t vektoreihin 32..47.
    pic.remap(32);
    // Vaihe 5.4 — PS/2-näppäimistö (i8042 + IRQ1 → UART-syöttörengas).
    const keyboard = @import("drivers/char/keyboard.zig");
    keyboard.init();
    // Salli keyboard IRQ1 (PIC master linja 1).
    pic.unmaskIrq(1);
    // Rekisteröi keyboard-käsittelijä IDT vektoriin 33.
    idt.registerHandler(keyboard.KEYBOARD_VECTOR, idt.keyboardHandlerAddr());
    // Boot-testi: simuloi scancodet (CI ilman fyysistä näppäimistöä).
    keyboard.runBootTest();
    // Vaihe 6.1 — PCI-väylän skannaus (config space 0xCF8/0xCFC).
    const pci = @import("drivers/bus/pci.zig");
    pci.runBootTest();
    // Vaihe 6.2 — VirtIO block -ajuri (PCI common cfg + sektori 0).
    const virtio_blk = @import("drivers/block/virtio_blk.zig");
    virtio_blk.runBootTest();
    // Vaihe 6.3 — VFS-rajapinta (mount + open/read/close).
    const vfs = @import("fs/vfs.zig");
    vfs.runBootTest();
    // Vaihe 6.4 — tmpfs RAM-tiedostojärjestelmä mount /tmp.
    const tmpfs = @import("fs/tmpfs.zig");
    tmpfs.runBootTest();
    // Vaihe 6.5 — käyttäjätilan ajurimalli (registry + null driver).
    const userland_driver = @import("userland_driver.zig");
    userland_driver.runBootTest();
    // Alusta PIT ~100 Hz — timer IRQ taustalle.
    pit.init(100);
    // Salli timer IRQ0 (PIC mask pois).
    pic.unmaskIrq(0);
    // Rekisteröi timer-käsittelijä IDT vektoriin 32 (assembly timer_irq.S).
    idt.registerHandler(pic.TIMER_VECTOR, idt.timerHandlerAddr());
    // Vahvista Vaihe 3 timer-infrastruktuuri.
    log.info("Phase 3 timer OK");
    // Logita SMP CPU-määrä Limine-vastauksesta (stub).
    smp.initAndLog();
    // Pakota pit_ticks linkitys (timerOnIrqC).
    _ = pit_ticks.count();
    // Käynnistä scheduler — coop-yield tuottaa ABAB... serialissa.
    scheduler.start();
}
