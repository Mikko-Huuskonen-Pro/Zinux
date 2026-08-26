//! Virtuaalimuistinhallinta (VMM) — stub Limine-sivutaulujen päällä.
//!
//! **Vastuu**: Sivukartoitus CR3:n kautta, HHDM-muunnos.
//! **Riippuvuudet**: `../arch/x86_64/paging.zig`, `pmm.zig`
//! **Käytetään**: `kernel/main.zig`, heap (tuleva)

const paging = @import("../arch/x86_64/paging.zig");
const pmm = @import("pmm.zig");

var hhdm_offset: u64 = 0;
var kernel_pml4_phys: u64 = 0;

// Alusta VMM — tallenna HHDM ja Liminen PML4 (CR3).
pub fn init(hhdm_off: u64) void {
    hhdm_offset = hhdm_off;
    kernel_pml4_phys = paging.getCr3();
}

// Kartoita virtuaalinen sivu fyysiseen kehykseen (stub — vaatii olemassa olevan taulun).
pub fn mapPage(virt: u64, phys: u64, flags: paging.PageFlags) bool {
    const ok = paging.mapPage(kernel_pml4_phys, hhdm_offset, virt, phys, flags);
    if (ok) paging.flushTlb(virt);
    return ok;
}

// Allokoi vapaa kehys PMM:stä ja kartoita se virtuaaliosoitteeseen.
pub fn mapNewPage(virt: u64, flags: paging.PageFlags) bool {
    const frame = pmm.allocFrame() orelse return false;
    const phys = pmm.frameToPhys(frame);
    return mapPage(virt, phys, flags);
}

// Palauta HHDM-offset (fys → virt: virt = phys + offset).
pub fn hhdm() u64 {
    return hhdm_offset;
}

// Palauta aktiivisen PML4:n fyysinen osoite.
pub fn pml4Phys() u64 {
    return kernel_pml4_phys;
}

// Muunna fyysinen osoite HHDM-virtuaaliosoitteeksi.
pub fn physToVirt(phys: u64) u64 {
    return phys + hhdm_offset;
}
