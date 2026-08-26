//! ELF64-loader — PT_LOAD kartoitus ring 3 -prosessille.
//!
//! **Vastuu**: Jäsennä ELF, kartoita segmentit VMM:llä, käynnistä boot-testi.
//! **Riippuvuudet**: `elf_core.zig`, `vmm.zig`, `paging.zig`, `usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-jäsennyksen ydin.
const core = @import("elf_core.zig");
// Tuo VMM — user-sivujen kartoitus.
const vmm = @import("../mm/vmm.zig");
// Tuo sivutus — PAGE_SIZE ja user-polku.
const paging = @import("../arch/x86_64/paging.zig");
// Tuo ring 3 siirtymä — iretq + paluu.
const usermode = @import("../arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../lib/log.zig");

// Upotettu loader-testi ELF — build.zig kopioi user-bin:n tähän ennen kernel-käännöstä.
const test_elf = @embedFile("test_prog.bin");

// Ring 3 pinon virtuaaliosoite — loader-testin stack (slot 33 heapin jälkeen).
const heap = @import("../mm/heap.zig");
// Pinon sivu heti ELF LOAD-alueen jälkeen.
const USER_STACK_SLOT: u64 = 33;
// Pinon sivun alku.
const USER_STACK_BASE: u64 = heap.HEAP_START + USER_STACK_SLOT * paging.PAGE_SIZE;
// Pinon yläreuna (16 tavun aligned iretq:ä varten).
const USER_STACK_TOP: u64 = USER_STACK_BASE + paging.PAGE_SIZE - 16;

// Ladattu käyttäjäkuva — entry + pinon huippu.
pub const LoadedImage = struct {
    // ELF e_entry — suoritus alkaa täältä.
    entry: u64,
    // Käyttäjäpinon yläreuna ring 3:lle.
    stack_top: u64,
};

// Ring 3 sivulippu — present + writable + user (data/rodata).
const USER_RW_FLAGS = paging.PageFlags{
    // Sivu kartoitettu.
    .present = 1,
    // Kirjoitus sallittu (data/BSS).
    .writable = 1,
    // Ring 3 pääsee sivulle.
    .user = 1,
};

// Kartoita yksi 4 KiB sivu segmentille — kaikki RW latauksen ajaksi (CR0.WP).
fn mapUserPage(virt: u64, executable: bool) bool {
    // Kartoita uusi user-sivu PMM:stä (aina writable — kernel kopioi segmenttidatan).
    if (!vmm.mapNewUserPageEnsure(virt, USER_RW_FLAGS)) return false;
    // Aseta U-bitti koko polussa; NX pois jos suoritettava.
    return paging.setUserPagePath(vmm.pml4Phys(), vmm.hhdm(), virt, executable);
}

// Kartoita [vaddr, vaddr+mem_size) sivu kerrallaan.
fn mapSegmentRange(vaddr: u64, mem_size: u64, executable: bool) bool {
    // Sivun koko x86_64:ssa.
    const page_size = paging.PAGE_SIZE;
    // Ensimmäinen sivu alueen alussa (tasattu alaspäin).
    var page = vaddr & ~(page_size - 1);
    // Alueen yläraja (exclusive).
    const end = vaddr + mem_size;
    // Käy jokainen sivu alueella.
    while (page < end) {
        // Kartoita yksi sivu.
        if (!mapUserPage(page, executable)) return false;
        // Seuraava sivu.
        page += page_size;
    }
    // Kaikki sivut kartoitettu.
    return true;
}

// Kopioi segmentin file-osuus ELF-blobista + nollaa BSS.
fn copySegmentData(seg: core.LoadSegment, elf_data: []const u8) bool {
    // Segmentin file data ELF-blobissa.
    if (seg.file_offset + seg.file_size > elf_data.len) return false;
    // Kohde muistissa segmentin vaddr:ssa.
    const dst: [*]u8 = @ptrFromInt(seg.vaddr);
    // Lähde ELF-blobissa.
    const src = elf_data[seg.file_offset..][0..seg.file_size];
    // Kopioi alustettu osa (file_size).
    @memcpy(dst[0..seg.file_size], src);
    // Nollaa BSS (mem_size - file_size) jos on.
    if (seg.mem_size > seg.file_size) {
        // BSS alkaa file-osion jälkeen.
        const bss_len = seg.mem_size - seg.file_size;
        // Nollaa laajennusalue.
        @memset(dst[seg.file_size..][0..bss_len], 0);
    }
    return true;
}

// Kartoita käyttäjäpinon yksi sivu.
fn mapUserStack() bool {
    // Kartoita pinosivu (writable, ei executable).
    return mapUserPage(USER_STACK_BASE, false);
}

// Lataa jäsennetty ELF muistiiin — palauta entry ja stack_top.
pub fn loadParsed(parsed: core.ParsedElf, elf_data: []const u8) bool {
    // Kartoita jokainen PT_LOAD-segmentti.
    for (parsed.segments) |seg| {
        // Suoritettavuus PF_X-bitistä.
        const executable = core.segmentExecutable(seg);
        // Kartoita sivut segmentin virtuaalialueelle.
        if (!mapSegmentRange(seg.vaddr, seg.mem_size, executable)) return false;
        // Kopioi tiedot ELF-blobista segmenttiin.
        if (!copySegmentData(seg, elf_data)) return false;
    }
    // Kartoita erillinen käyttäjäpinon sivu.
    if (!mapUserStack()) return false;
    // Kaikki segmentit + pino valmiina.
    return true;
}

// Lataa ELF blobista — jäsentää ja kartoittaa.
pub fn loadElf(elf_data: []const u8) ?LoadedImage {
    // Segmenttipuskuri parseElf:lle.
    var segments: [core.MAX_LOAD_SEGMENTS]core.LoadSegment = undefined;
    // Jäsennä ELF-otsikko ja PT_LOAD:t.
    const parsed = core.parseElf(elf_data, &segments) catch return null;
    // Kartoita segmentit ja pino.
    if (!loadParsed(parsed, elf_data)) return null;
    // Palauta hyppypiste ja pinon yläreuna.
    return .{
        .entry = parsed.entry,
        .stack_top = USER_STACK_TOP,
    };
}

// Boot-testi — lataa upotettu ELF, aja ring 3 (sys_write "elf" + paluu).
pub fn runBootTest() void {
    // Lataa test_elf blob kernel-muistiin / sivuja.
    const loaded = loadElf(test_elf) orelse {
        // Jäsentäminen tai kartoitus epäonnistui.
        log.err("ELF load failed");
        return;
    };
    // Siirry ring 3:een ladatun entry:n kautta.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return ret:llä (sama kuin usermode-testi).
    log.info("ELF loader test OK");
}
