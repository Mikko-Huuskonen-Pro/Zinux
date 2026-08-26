//! Kernel heap — VMM-pohjainen kasvu first-fit-ytimen päällä.
//!
//! **Vastuu**: Dynaaminen muistin allokointi kernelille bootissa.
//! **Riippuvuudet**: `heap_core.zig`, `vmm.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo first-fit-ydin ilman VMM-riippuvuutta.
const core = @import("heap_core.zig");
// Tuo sivukoko kernel data -lippuja varten.
const paging = @import("../arch/x86_64/paging.zig");
// Tuo VMM — uusien sivujen kartoitus heap-kasvuun.
const vmm = @import("vmm.zig");

// Sivukoko — sama kuin paging.PAGE_SIZE.
const PAGE_SIZE: usize = paging.PAGE_SIZE;
// Heapin virtuaalinen alkuosoite — kernel higher-half -PML4:n sisällä (Limine PDPT 510).
pub const HEAP_START: u64 = 0xFFFFFFFF90000000;
// Aluksi kartoitettavien sivujen määrä (4 sivua = 16 KiB).
const INITIAL_PAGES: usize = 4;

// Kartoita yksi uusi sivu heap-alueen loppuun ja rekisteröi se ytimelle.
fn growHeap() bool {
    // Laske uuden sivun virtuaaliosoite nykyisen heap-koon perusteella.
    const virt = HEAP_START + core.totalSize();
    // Kartoita uusi sivu allokoiden kehyksen ja sivutaulut PMM:stä.
    if (!vmm.mapNewPageEnsure(virt, vmm.KERNEL_DATA_FLAGS)) return false;
    // Osoitin uuden sivun alkuun.
    const page_ptr: [*]u8 = @ptrFromInt(virt);
    // Nollaa uusi sivu ennen allokaattorin käyttöä.
    @memset(page_ptr[0..PAGE_SIZE], 0);
    // Lisää sivu heap-ytimen vapaaseen listaan.
    core.appendRegion(page_ptr, PAGE_SIZE);
    // Kasvu onnistui.
    return true;
}

// Alusta heap VMM:n kautta — kartoita INITIAL_PAGES sivua HEAP_START:iin.
pub fn init() void {
    // Älä alusta kahdesti.
    if (core.isInitialized()) return;
    // Kartoita alkusivut yksi kerrallaan.
    var page: usize = 0;
    // Toista INITIAL_PAGES kertaa.
    while (page < INITIAL_PAGES) : (page += 1) {
        // growHeap kartoittaa ja rekisteröi yhden sivun.
        if (!growHeap()) break;
    }
}

// Allokoi requested tavua — kasvata heapia tarvittaessa.
pub fn alloc(requested: usize) ?[*]u8 {
    // Delegoi ytimelle grow-callbackin kera.
    return core.allocWithGrow(requested, growHeap);
}

// Vapauta aiemmin allokoitu muistilohko.
pub fn free(ptr: [*]u8) void {
    // Delegoi ytimelle.
    core.free(ptr);
}

// Palauta heapin kokonaiskoko tavuina.
pub fn totalSize() usize {
    // Delegoi ytimelle.
    return core.totalSize();
}

// Onko heap alustettu?
pub fn isInitialized() bool {
    // Delegoi ytimelle.
    return core.isInitialized();
}

// Host-testejä varten — alusta staattisella puskurilla.
pub fn initBuffer(buffer: []u8) void {
    // Delegoi ytimelle ilman VMM:ää.
    core.initBuffer(buffer);
}
