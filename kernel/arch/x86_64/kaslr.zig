//! KASLR — satunnainen kernel heap -base bootissa.
//!
//! **Vastuu**: Laske slide RDTSC+HHDM:stä, kartoita heap slidattuun osoitteeseen.
//! **Riippuvuudet**: `kaslr_core.zig`, Limine, log
//! **Käytetään**: `heap.zig`, `main.zig`

// Tuo KASLR-ydin — slide-laskenta ja osoitekorjaus.
const core = @import("kaslr_core.zig");
// Tuo Limine boot-tiedot — executable virtual_base.
const limine_boot = @import("../../boot/limine.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../../lib/log.zig");

// Aktiivinen slide tavuina (0 ennen init():ää).
var active_slide: u64 = 0;
// Kernel heapin runtime-alkuosoite (slidattu).
var active_heap_base: u64 = core.USER_REGION_ORIGIN;
// Liminen raportoima kernel virtual_base (link- tai slidattu).
var kernel_virtual_base: u64 = core.LINK_BASE;

// Lue RDTSC — 64-bit aikaleima entropialähteeksi (freestanding: muistitulokset).
fn readRdtsc() u64 {
    // Ala- ja yläosat erillisissä muuttujissa.
    var lo: u32 = undefined;
    var hi: u32 = undefined;
    // RDTSC → EAX:EDX, tallenna muistiin mov:lla.
    asm volatile (
        \\rdtsc
        \\mov %%eax, %[l]
        \\mov %%edx, %[h]
        : [l] "=m" (lo),
          [h] "=m" (hi),
        :
        : .{ .rax = true, .rdx = true, .memory = true });
    // Yhdistä yhdeksi u64:ksi.
    return (@as(u64, hi) << 32) | lo;
}

// Hae Limine executable address -vastaus tai link-osoite oletuksena.
fn readKernelVirtualBase() u64 {
    // Delegoi limine.zig — oletus LINK_BASE jos vastaus puuttuu.
    return limine_boot.getExecutableVirtualBase(core.LINK_BASE);
}

// Alusta KASLR — kutsutaan ennen heap.init():ia (VMM valmiina).
pub fn init(hhdm_offset: u64) void {
    // Liminen kernel virtual_base (tulevaisuuden PIE-tuki).
    kernel_virtual_base = readKernelVirtualBase();
    // Sekoita RDTSC, HHDM ja exe_virt → slide.
    const entropy = core.mixEntropy(readRdtsc(), hhdm_offset, kernel_virtual_base);
    // Laske 2 MiB -tasaus slide (ei koskaan 0).
    active_slide = core.computeSlide(entropy);
    // Päivitä kernel heap -alueen runtime-alku.
    active_heap_base = core.heapBase(active_slide);
}

// Palauta aktiivinen slide.
pub fn slide() u64 {
    // Palauta tallennettu slide.
    return active_slide;
}

// Palauta kernel heapin runtime-alku (heap.init käyttää).
pub fn heapBase() u64 {
    // Palauta slidattu heap-alku.
    return active_heap_base;
}

// Siirrä linkitys-virt-osoite runtime-osoitteeksi.
pub fn relocUserVirt(fixed: u64) u64 {
    // Delegoi ytimelle aktiivisella slidella.
    return core.relocUserVirt(fixed, active_slide);
}

// Palauta Liminen kernel virtual_base (debug / tuleva PIE).
pub fn kernelBase() u64 {
    // Palauta tallennettu exe_virt.
    return kernel_virtual_base;
}

// Boot-testi — vahvista slide aktivoitu.
pub fn runBootTest() void {
    // Slide puuttuu tai väärä tasaus → virhe.
    if (!core.slideOk(active_slide)) {
        // KASLR ei aktivoitunut.
        log.err("KASLR slide invalid");
        // Lopeta testi.
        return;
    }
    // Slide voimassa — boot onnistui.
    log.info("KASLR OK");
}
