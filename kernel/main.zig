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
    // Alusta kernel heap — kartoittaa INITIAL_PAGES sivua HEAP_START:iin.
    heap.init();
    // Vahvista heap-alustus onnistui.
    log.info("Heap initialized");
    // Aja Vaihe 2 integraatiotestit (100 kehystä + heap smoke test).
    memtest.runAll();
    // Boot on valmis — CI etsii tämän merkkijonon serialista.
    log.info("Zinux boot OK");
    // --- Vaihe 3: aikataulutus ---
    // Remapaa PIC IRQ:t vektoreihin 32..47.
    pic.remap(32);
    // Alusta PIT ~100 Hz — timer IRQ taustalle.
    pit.init(100);
    // Salli timer IRQ0 (PIC mask pois).
    pic.unmaskIrq(0);
    // Rekisteröi timer-käsittelijä IDT vektoriin 32.
    idt.registerHandler(pic.TIMER_VECTOR, @intFromPtr(&idt.timerIrqHandler));
    // Vahvista Vaihe 3 timer-infrastruktuuri.
    log.info("Phase 3 timer OK");
    // Käynnistä scheduler — coop-yield tuottaa ABAB... serialissa.
    scheduler.start();
}
