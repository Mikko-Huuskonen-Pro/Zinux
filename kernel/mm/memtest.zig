//! Muistinhallinnan integraatiotestit bootissa (Vaihe 2).
//!
//! **Vastuu**: 100 kehyksen kartoitus + heap smoke test.
//! **Riippuvuudet**: PMM, VMM, heap, log
//! **Käytetään**: `kernel/main.zig`

// Tuo lokitus — testitulosten tulostus serialiin.
const log = @import("../lib/log.zig");
// Tuo PMM — kehysten allokointi kartoitustestiin.
const pmm = @import("pmm.zig");
// Tuo VMM — sivujen kartoitus uuteen virtuaaliseen alueeseen.
const vmm = @import("vmm.zig");
// Tuo heap — first-fit allokaattorin smoke test.
const heap = @import("heap.zig");
// Tuo UART desimaalilukujen tulostukseen boot-debugissa.
const uart = @import("../drivers/char/uart.zig");

// Kartoitustestin virtuaalinen alku — kernel higher-half, erillinen PD-indeksi.
pub const TEST_MAP_BASE: u64 = 0xFFFFFFFFA0000000;
// Kartoitettavien kehysten määrä (ROADMAP Vaihe 2 -testi).
const FRAME_COUNT: usize = 100;

// Aja kaikki muistitestit peräkkäin boot-vaiheessa.
pub fn runAll() void {
    // Testaa 100 kehyksen allokointi, kartoitus, kirjoitus ja luku.
    runFrameMapTest();
    // Testaa kernel heap alloc/free.
    runHeapTest();
}

// Allokoi FRAME_COUNT kehystä, kartoita, kirjoita tavu ja tarkista luku.
fn runFrameMapTest() void {
    // Taulukko allokoitujen kehysindeksien tallennukseen.
    var frames: [FRAME_COUNT]usize = undefined;
    // Käy jokainen testikehys läpi.
    var i: usize = 0;
    // Toista FRAME_COUNT kertaa.
    while (i < FRAME_COUNT) : (i += 1) {
        // Allokoi fyysinen kehys PMM:stä.
        const frame = pmm.allocFrame() orelse {
            // PMM loppu kesken testin — raportoi virhe.
            log.err("PMM OOM in map test");
            // Keskeytä testi.
            return;
        };
        // Tallenna kehysindeksi myöhempää vapautusta varten (ei vapauteta bootissa).
        frames[i] = frame;
        // Muunna kehysindeksi fyysiseksi osoitteeksi.
        const phys = pmm.frameToPhys(frame);
        // Laske virtuaaliosoite tälle kehykselle testialueella.
        const virt = TEST_MAP_BASE + @as(u64, i) * 4096;
        // Kartoita kehys luoden sivutaulut tarvittaessa.
        if (!vmm.mapPageEnsure(virt, phys, vmm.KERNEL_DATA_FLAGS)) {
            // Kartoitus epäonnistui — raportoi virhe.
            log.err("VMM map failed in map test");
            // Keskeytä testi.
            return;
        }
        // Osoitin kartoitettuun sivuun tavuosoitteena.
        const ptr: *u8 = @ptrFromInt(virt);
        // Kirjoita testitavu (alhaiset 8 bittiä indeksistä).
        ptr.* = @as(u8, @truncate(i));
    }
    // Tarkista jokaisen kehyksen sisältö luettuna takaisin.
    i = 0;
    // Toista FRAME_COUNT kertaa.
    while (i < FRAME_COUNT) : (i += 1) {
        // Laske saman virtuaaliosoitteen kuin kirjoituksessa.
        const virt = TEST_MAP_BASE + @as(u64, i) * 4096;
        // Osoitin kartoitettuun sivuun.
        const ptr: *u8 = @ptrFromInt(virt);
        // Vertaa luettua tavua odotettuun arvoon.
        if (ptr.* != @as(u8, @truncate(i))) {
            // Data ei täsmää — muistivirhe tai kartoitusongelma.
            log.err("Memory verify failed");
            // Keskeytä testi.
            return;
        }
    }
    // Kaikki 100 kehystä OK — tulosta vahvistus.
    log.info("Memory map test OK (100 frames)");
    // Tulosta PMM-vapaiden kehysten määrä boot-debugiin (Vaihe 2 diagnostiikka).
    logFreeFrameCount();
}

// Tulosta vapaiden PMM-kehysten määrä UART:iin (yksinkertainen desimaalilog).
fn logFreeFrameCount() void {
    // Hae vapaiden kehysten määrä bitmapista.
    const free = pmm.availableFrames();
    // Staattinen otsikko serialiin.
    log.info("PMM free frames:");
    // Tulosta luku yksinkertaisella desimaalitulostuksella (ei log.fmt).
    writeDecimal(free);
}

// Desimaalitulostus UART:iin — riittää boot-debug-luvuille.
fn writeDecimal(val: usize) void {
    // Nollatapaus erikseen.
    if (val == 0) {
        // Tulosta nolla.
        uart.putc('0');
        // Rivinvaihto luvun jälkeen.
        uart.putc('\n');
        // Valmis.
        return;
    }
    // Puskuri enintään 20 numeroa (64-bit desimaali).
    var buf: [20]u8 = undefined;
    // Montako numeroa on kerätty.
    var len: usize = 0;
    // Jäännös jakoa varten.
    var n = val;
    // Kerää numerot käänteisessä järjestyksessä.
    while (n > 0) : (n /= 10) {
        // ASCII-numero jäännöksestä.
        buf[len] = @as(u8, @truncate('0' + (n % 10)));
        // Kasvata pituus.
        len += 1;
    }
    // Tulosta numerot oikeassa järjestyksessä.
    while (len > 0) {
        // Vähennä ennen tulostusta.
        len -= 1;
        // Tulosta yksi numero.
        uart.putc(buf[len]);
    }
    // Rivinvaihto luvun jälkeen.
    uart.putc('\n');
}

// Smoke test kernel heapille — alloc, free, uudelleenalloc.
fn runHeapTest() void {
    // Allokoi 64 tavua heapistä.
    const a = heap.alloc(64) orelse {
        // Heap allokointi epäonnistui.
        log.err("Heap alloc failed");
        // Keskeytä testi.
        return;
    };
    // Allokoi 128 tavua heapistä.
    const b = heap.alloc(128) orelse {
        // Toinen allokointi epäonnistui.
        log.err("Heap alloc failed");
        // Keskeytä testi.
        return;
    };
    // Kirjoita testidata ensimmäiseen lohkoon.
    a[0] = 0xAA;
    // Kirjoita testidata toiseen lohkoon.
    b[0] = 0xBB;
    // Vapauta ensimmäinen lohko takaisin heapille.
    heap.free(a);
    // Vapauta toinen lohko.
    heap.free(b);
    // Allokoi uudelleen — varmistaa että free-list toimii.
    const c = heap.alloc(32) orelse {
        // Uudelleenallokointi epäonnistui.
        log.err("Heap re-alloc failed");
        // Keskeytä testi.
        return;
    };
    // Estä unused-varoitus.
    _ = c;
    // Heap smoke test OK.
    log.info("Heap test OK");
}
