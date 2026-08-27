//! Virtuaalimuistinhallinta (VMM) — sivukartoitus Limine CR3:n päällä.
//!
//! **Vastuu**: Sivukartoitus CR3:n kautta, HHDM-muunnos, uusien sivutaulujen luonti.
//! **Riippuvuudet**: `../arch/x86_64/paging.zig`, `pmm.zig`
//! **Käytetään**: `kernel/main.zig`, `heap.zig`

// Tuo paging — CR3, mapPage, mapPageEnsure, flushTlb.
const paging = @import("../arch/x86_64/paging.zig");
// Tuo PMM — fyysisten kehysten allokointi uusille sivutauluille.
const pmm = @import("pmm.zig");

// HHDM-offset — muunna phys → virt lisäämällä tämä.
var hhdm_offset: u64 = 0;
// Aktiivisen PML4-taulun fyysinen osoite (Liminen CR3 bootissa).
var kernel_pml4_phys: u64 = 0;
// CR3 ennen prosessiin hyppyä — palautetaan kerneliin (Vaihe 25).
var saved_kernel_cr3: u64 = 0;

// PMM-callback paging.mapPageEnsure:lle — palauttaa uuden kehyksen fyysinen osoite.
fn allocFramePhys() ?u64 {
    // Allokoi vapaa 4 KiB kehys bitmapista.
    const frame = pmm.allocFrame() orelse return null;
    // Muunna kehysindeksi fyysiseksi tavuosoitteeksi.
    return pmm.frameToPhys(frame);
}

// Alusta VMM — tallenna HHDM ja Liminen PML4 (CR3).
pub fn init(hhdm_off: u64) void {
    // Tallenna HHDM kaikkea phys→virt -muunnosta varten.
    hhdm_offset = hhdm_off;
    // Lue Liminen valmiiksi kartoittama PML4 CR3:stä.
    kernel_pml4_phys = paging.getCr3();
}

// Kartoita virtuaalinen sivu fyysiseen kehykseen (vaatii valmiit sivutaulut).
pub fn mapPage(virt: u64, phys: u64, flags: paging.PageFlags) bool {
    // Yritä kartoitus olemassa oleviin Limine-tauluihin.
    const ok = paging.mapPage(kernel_pml4_phys, hhdm_offset, virt, phys, flags);
    // Flushaa TLB jos kartoitus onnistui.
    if (ok) paging.flushTlb(virt);
    // Palauta onnistuminen kutsujalle.
    return ok;
}

// Kartoita virtuaalinen sivu — luo puuttuvat sivutaulut PMM:stä tarvittaessa.
pub fn mapPageEnsure(virt: u64, phys: u64, flags: paging.PageFlags) bool {
    // Käy sivutaulut läpi ja allokoi puuttuvat tasot PMM:stä.
    const ok = paging.mapPageEnsure(
        kernel_pml4_phys,
        hhdm_offset,
        virt,
        phys,
        flags,
        allocFramePhys,
    );
    // Flushaa TLB uuden kartoituksen jälkeen.
    if (ok) paging.flushTlb(virt);
    // Palauta onnistuminen kutsujalle.
    return ok;
}

// Allokoi vapaa kehys PMM:stä ja kartoita se virtuaaliosoitteeseen (valmiit taulut).
pub fn mapNewPage(virt: u64, flags: paging.PageFlags) bool {
    // Allokoi fyysinen kehys bitmapista.
    const frame = pmm.allocFrame() orelse return false;
    // Muunna kehysindeksi fyysiseksi osoitteeksi.
    const phys = pmm.frameToPhys(frame);
    // Kartoita kehys virtuaaliosoitteeseen.
    return mapPage(virt, phys, flags);
}

// Allokoi kehys ja kartoita — luo sivutaulut tarvittaessa (käyttäjäpolku U=1).
pub fn mapNewUserPageEnsure(virt: u64, flags: paging.PageFlags) bool {
    // Delegoi kernel PML4:lle (boot / legacy).
    return mapNewUserPageEnsureFor(kernel_pml4_phys, virt, flags);
}

// Allokoi kehys ja kartoita annettuun PML4:ään (Vaihe 25 prosessikohtainen).
pub fn mapNewUserPageEnsureFor(pml4_phys: u64, virt: u64, flags: paging.PageFlags) bool {
    // Allokoi fyysinen kehys bitmapista.
    const frame = pmm.allocFrame() orelse return false;
    // Muunna kehysindeksi fyysiseksi osoitteeksi.
    const phys = pmm.frameToPhys(frame);
    // Kartoita kehys luoden user-sivutaulut kohde-PML4:ään.
    const ok = paging.mapUserPageEnsure(
        pml4_phys,
        hhdm_offset,
        virt,
        phys,
        flags,
        allocFramePhys,
    );
    // Flushaa TLB uuden kartoituksen jälkeen.
    if (ok) paging.flushTlb(virt);
    // Palauta onnistuminen.
    return ok;
}

// User-ELF / spawn -alueen alku — erillinen PD-kopiointi forkissa.
const USER_ASPACE_BASE: u64 = 0xFFFFFFFF90000000;
// Montako 4K-sivua user-heap/spawn-sloteille varataan (slot 0..127).
const USER_ASPACE_PAGE_COUNT: u64 = 128;

// Luo prosessin oma PML4 — fork kernel + erillinen user-haara (Vaihe 25).
pub fn createProcessPageTable() ?u64 {
    // Fork kernel PML4: jaettu kernel, erillinen user PD-haara.
    return paging.forkAddressSpace(
        kernel_pml4_phys,
        hhdm_offset,
        USER_ASPACE_BASE,
        USER_ASPACE_PAGE_COUNT,
        allocFramePhys,
    );
}

// Aktivoi prosessin osoiteavaruus — tallenna kernel CR3 ensimmäisellä kerralla.
pub fn switchToAddressSpace(pml4_phys: u64) void {
    // Tallenna nykyinen CR3 vain kerran per hyppy (kernel → prosessi).
    if (saved_kernel_cr3 == 0) {
        // Nykyinen pitäisi olla kernel PML4.
        saved_kernel_cr3 = paging.getCr3();
    }
    // Vaihda prosessin sivutauluun.
    paging.setCr3(pml4_phys);
}

// Palauta kernelin osoiteavaruus (Limine PML4).
pub fn switchToKernel() void {
    // Palauta tallennettu tai oletus kernel CR3.
    const target = if (saved_kernel_cr3 != 0) saved_kernel_cr3 else kernel_pml4_phys;
    // Aktivoi kernel PML4.
    paging.setCr3(target);
    // Nollaa tallenne seuraavaa prosessihyppyä varten.
    saved_kernel_cr3 = 0;
}

// Allokoi kehys ja kartoita — luo sivutaulut tarvittaessa.
pub fn mapNewPageEnsure(virt: u64, flags: paging.PageFlags) bool {
    // Allokoi fyysinen kehys bitmapista.
    const frame = pmm.allocFrame() orelse return false;
    // Muunna kehysindeksi fyysiseksi osoitteeksi.
    const phys = pmm.frameToPhys(frame);
    // Kartoita kehys luoden puuttuvat sivutaulut.
    return mapPageEnsure(virt, phys, flags);
}

// Palauta HHDM-offset (fys → virt: virt = phys + offset).
pub fn hhdm() u64 {
    // Palauta tallennettu Limine HHDM-offset.
    return hhdm_offset;
}

// Palauta aktiivisen PML4:n fyysinen osoite.
pub fn pml4Phys() u64 {
    // Palauta bootissa tallennettu CR3/PML4-osoite.
    return kernel_pml4_phys;
}

// Muunna fyysinen osoite HHDM-virtuaaliosoitteeksi.
pub fn physToVirt(phys: u64) u64 {
    // HHDM direct map: virt = phys + hhdm_offset.
    return phys + hhdm_offset;
}

// Kernel data -sivujen oletusliput — present, writable, kernel-only.
pub const KERNEL_DATA_FLAGS = paging.PageFlags{
    // Sivu on present.
    .present = 1,
    // Sivu on kirjoitettavissa.
    .writable = 1,
    // Ei user-tilaa — vain ring 0.
    .user = 0,
};
