//! Kernel heap — first-fit allokaattori (ydinlogiikka ilman VMM:ää).
//!
//! **Vastuu**: Vapaiden lohkojen hallinta, alloc/free.
//! **Riippuvuudet**: ei
//! **Käytetään**: `heap.zig`, host-testit

// Minimipalloitus — header + pienin käyttökelpoinen lohko.
const MIN_BLOCK_SIZE: usize = 32;
// Header jokaisen allokoidun/vapaan lohkon edessä.
const BlockHeader = struct {
    // Lohkon koko tavuina mukaan lukien tämä header.
    size: usize,
    // Onko lohko vapaa (true) vai käytössä (false).
    free: bool,
};

// Vapaan lohkon solmu — upotettu vapaan muistin alkuun.
const FreeNode = struct {
    // Lohkon koko tavuina mukaan lukien header.
    size: usize,
    // Seuraava vapaa lohko linkitetty listassa.
    next: ?*FreeNode,
};

// Osoitin heap-alueen alkuun.
var heap_base: [*]u8 = undefined;
// Heap-alueen kokonaiskoko tavuina.
var heap_size: usize = 0;
// Vapaan muistin linkitetty lista (first-fit haku).
var free_list: ?*FreeNode = null;
// Onko heap alustettu.
var initialized: bool = false;

// Lisää yksi vapaa lohko linkitettyyn listaan.
fn addFreeBlock(ptr: [*]u8, size: usize) void {
    // Muunna osoitin FreeNode-rakenteeksi (upotettu vapaaseen muistiin).
    const node: *FreeNode = @ptrCast(@alignCast(ptr));
    // Tallenna lohkon koko solmuun.
    node.size = size;
    // Lisää solmu listan alkuun (LIFO — riittää first-fit:lle).
    node.next = free_list;
    // Päivitä listan pää.
    free_list = node;
}

// Alusta heap annetulla puskurilla — host-testit ja VMM-init käyttävät tätä.
pub fn initBuffer(buffer: []u8) void {
    // Nollaa tila ennen uutta alustusta.
    heap_size = 0;
    // Tyhjennä vapaiden lohkojen lista.
    free_list = null;
    // Aseta heap-pohja annettuun puskuriin.
    heap_base = buffer.ptr;
    // Aseta koko puskurin pituudeksi.
    heap_size = buffer.len;
    // Nollaa koko puskuri.
    @memset(buffer, 0);
    // Lisää koko puskuri yhtenä vapaana lohkona.
    addFreeBlock(buffer.ptr, buffer.len);
    // Merkitse alustettu.
    initialized = true;
}

// Lisää uusi vapaa alue heapin loppuun (VMM kasvattaa ennen tätä kutsua).
pub fn appendRegion(ptr: [*]u8, size: usize) void {
    // Ensimmäisellä alueella aseta heap-pohja ja merkitse alustetuksi.
    if (!initialized) {
        // Tallenna ensimmäisen sivun osoite heap-pohjaksi.
        heap_base = ptr;
        // Merkitse heap valmiiksi allokointeihin.
        initialized = true;
    }
    // Kasvata kokonaiskokoa uudella alueella.
    heap_size += size;
    // Lisää uusi alue vapaana lohkona.
    addFreeBlock(ptr, size);
}

// Etsi ensimmäinen riittävän suuri vapaa lohko (first-fit).
fn findFreeBlock(requested: usize) ?*FreeNode {
    // Käy vapaiden lohkojen linkitetty lista läpi.
    var current = free_list;
    // Toista kunnes lista loppuu.
    while (current) |node| {
        // Jos lohko on tarpeeksi suuri, palauta se.
        if (node.size >= requested) return node;
        // Siirry seuraavaan vapaaseen lohkoon.
        current = node.next;
    }
    // Ei sopivaa lohkoa.
    return null;
}

// Poista solmu vapaan listan kohdista.
fn removeFreeNode(target: *FreeNode) void {
    // Edellinen solmu listassa (null = listan alku).
    var prev: ?*FreeNode = null;
    // Nykyinen solmu listassa.
    var current = free_list;
    // Etsi kohdesolmu listasta.
    while (current) |node| {
        // Löytyi — poista listasta.
        if (node == target) {
            // Jos edellinen on olemassa, ohita kohde sen next:llä.
            if (prev) |p| {
                // Edellisen next = kohteen next.
                p.next = node.next;
            } else {
                // Kohde oli listan alku — siirrä pää eteenpäin.
                free_list = node.next;
            }
            // Poisto valmis.
            return;
        }
        // Siirry eteenpäin.
        prev = node;
        current = node.next;
    }
}

// Jaa vapaa lohko kahteen jos jäljelle jää tarpeeksi tilaa.
fn splitBlock(node: *FreeNode, total_needed: usize) void {
    // Laske jäljelle jäävän vapaan tilan koko splitin jälkeen.
    const remaining = node.size - total_needed;
    // Jaa vain jos jäljelle jää vähintään MIN_BLOCK_SIZE tavua.
    if (remaining < MIN_BLOCK_SIZE) return;
    // Laske uuden vapaan lohkon osoite jaetun lohkon perään.
    const new_ptr: [*]u8 = @ptrFromInt(@intFromPtr(node) + total_needed);
    // Pienennä alkuperäistä lohkoa allokoidun koon mukaiseksi.
    node.size = total_needed;
    // Lisää jäljelle jäänyt osa vapaana lohkona listaan.
    addFreeBlock(new_ptr, remaining);
}

// Allokoi requested tavua heapistä — palauttaa osoittimen data-alueeseen.
pub fn alloc(requested: usize) ?[*]u8 {
    // Hylkää nolla-koko ja alustamaton heap.
    if (!initialized or requested == 0) return null;
    // Tarvittava tila mukaan lukien BlockHeader ennen dataa.
    const total = requested + @sizeOf(BlockHeader);
    // Pyöristä ylöspäin MIN_BLOCK_SIZE:n kerravaiheeseen.
    const needed = if (total < MIN_BLOCK_SIZE) MIN_BLOCK_SIZE else total;
    // Etsi sopiva vapaa lohko.
    const node = findFreeBlock(needed) orelse return null;
    // Poista valittu lohko vapaan listan hallinnasta.
    removeFreeNode(node);
    // Jaa lohko jos ylimääräistä tilaa jää merkittävästi.
    splitBlock(node, needed);
    // Osoitin lohkon data-alueeseen (header heti ennen dataa).
    const data_ptr: [*]u8 = @ptrFromInt(@intFromPtr(node) + @sizeOf(BlockHeader));
    // Kirjoita header allokoidun lohkon alkuun.
    const header: *BlockHeader = @ptrCast(@alignCast(node));
    // Tallenna todellinen varattu koko.
    header.size = needed;
    // Merkitse lohko käytössä olevaksi.
    header.free = false;
    // Palauta osoitin data-alueeseen kutsujalle.
    return data_ptr;
}

// Vapauta aiemmin allokoitu muistilohko.
pub fn free(ptr: [*]u8) void {
    // Hylkää alustamaton heap.
    if (!initialized) return;
    // Header sijaitsee aina data-osoitteen edessä.
    const header: *BlockHeader = @ptrFromInt(@intFromPtr(ptr) - @sizeOf(BlockHeader));
    // Älä vapauta jo vapaata lohkoa (kaksinkertainen free).
    if (header.free) return;
    // Merkitse lohko vapaaksi.
    header.free = true;
    // Lisää koko lohko (header mukaan lukien) vapaaseen listaan.
    addFreeBlock(@ptrFromInt(@intFromPtr(header)), header.size);
}

// Palauta heapin kokonaiskoko tavuina.
pub fn totalSize() usize {
    // Palauta nykyinen koko.
    return heap_size;
}

// Onko heap alustettu?
pub fn isInitialized() bool {
    // Palauta alustuslippu.
    return initialized;
}

// Yritä allokoida — kutsu grow-callbackia kunnes onnistuu tai epäonnistuu.
pub fn allocWithGrow(requested: usize, grow: *const fn () bool) ?[*]u8 {
    // Yritä ensin ilman kasvua.
    if (alloc(requested)) |ptr| return ptr;
    // Kasvata heapia kunnes allokointi onnistuu tai kasvu epäonnistuu.
    while (grow()) {
        // Yritä uudelleen kasvaneella heapilla.
        if (alloc(requested)) |ptr| return ptr;
    }
    // Heap loppu eikä kasvu onnistunut.
    return null;
}
