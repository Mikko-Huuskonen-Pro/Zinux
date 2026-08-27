//! Host-testit KASLR-ytimelle.

const std = @import("std");
const kaslr = @import("kaslr_core");

test "compute slide is aligned and non-zero" {
    // Eri entropia-arvot.
    const s1 = kaslr.computeSlide(0x1234);
    const s2 = kaslr.computeSlide(0x5678);
    // Molemmat kelvollisia slideja.
    try std.testing.expect(kaslr.slideOk(s1));
    try std.testing.expect(kaslr.slideOk(s2));
    // Ei sama aina (todennäköisesti eri).
    try std.testing.expect(s1 != s2 or 0x5678 == 0x1234);
}

test "reloc user virt adds slide above origin" {
    // Slide 4 MiB.
    const slide: u64 = 2 * kaslr.SLIDE_ALIGN;
    // Linkitys-osoite user-alueella.
    const fixed: u64 = kaslr.USER_REGION_ORIGIN + 0x20000;
    // Runtime = fixed + slide.
    const runtime = kaslr.relocUserVirt(fixed, slide);
    try std.testing.expect(runtime == fixed + slide);
    // Kernel-osoite alle origin — ei siirtoa.
    try std.testing.expect(kaslr.relocUserVirt(kaslr.LINK_BASE, slide) == kaslr.LINK_BASE);
}

test "heap base includes slide" {
    // Slide 2 MiB.
    const slide: u64 = kaslr.SLIDE_ALIGN;
    // Base = origin + slide.
    try std.testing.expect(kaslr.heapBase(slide) == kaslr.USER_REGION_ORIGIN + slide);
}

test "mix entropy changes with inputs" {
    // Sama rdtsc mutta eri hhdm → eri sekoitus.
    const a = kaslr.mixEntropy(1, 0x1000, kaslr.LINK_BASE);
    const b = kaslr.mixEntropy(1, 0x2000, kaslr.LINK_BASE);
    try std.testing.expect(a != b);
}
