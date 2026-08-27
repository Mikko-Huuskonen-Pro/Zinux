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
// Tuo user_access — stac/clac SMAP-yhteensopivuuteen user-sivuille.
const user_access = @import("../arch/x86_64/user_access.zig");
// Tuo heap — kiinteät user-ELF linkitysosoitteet (slot 0 = HEAP_START).
const heap = @import("../mm/heap.zig");

// Upotettu loader-testi ELF — build.zig kopioi user-bin:n tähän ennen kernel-käännöstä.
const test_elf = @embedFile("test_prog.bin");

// Loader-testin pinon heap-slot (slot 33).
const LOADER_TEST_STACK_SLOT: u64 = 33;

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

// Kartoita yksi 4 KiB sivu segmentille — prosessille aina uusi kehys jos ei vielä kartoitettu.
fn mapUserPage(virt: u64, executable: bool, pml4_phys: u64) bool {
    // Tarkista onko sivu jo kartoitettu tässä latauksessa / kernelissä.
    const already = paging.getPteRaw(pml4_phys, vmm.hhdm(), virt) != null;
    // Prosessin osoiteavaruus — uusi PMM-kehys (prepareSpawnPageTable tyhjensi jaetun PT:n).
    if (pml4_phys != vmm.pml4Phys()) {
        if (!already) {
            if (!vmm.mapNewUserPageEnsureFor(pml4_phys, virt, USER_RW_FLAGS)) return false;
        }
        if (executable) {
            return paging.setUserPagePath(pml4_phys, vmm.hhdm(), virt, true);
        }
        return paging.setUserPagePath(pml4_phys, vmm.hhdm(), virt, false);
    }
    // Kernel PML4 — alkuperäinen polku.
    // Tarkista onko sivu jo kartoitettu (useat PT_LOAD samalla sivulla).
    // const already yllä
    // Uusi sivu — allokoi PMM:stä ja kartoita writable latausta varten.
    if (!already) {
        if (!vmm.mapNewUserPageEnsureFor(pml4_phys, virt, USER_RW_FLAGS)) return false;
    }
    // Suoritettava segmentti samalla sivulla — varmista NX pois.
    if (executable) {
        return paging.setUserPagePath(pml4_phys, vmm.hhdm(), virt, true);
    }
    // Ensimmäinen ei-suoritettava kartoitus — aseta user-bitti.
    if (!already) {
        return paging.setUserPagePath(pml4_phys, vmm.hhdm(), virt, false);
    }
    // Sivu jo olemassa (esim. .text + .rodata) — säilytä olemassa oleva kartoitus.
    return true;
}

// Kartoita [vaddr, vaddr+mem_size) sivu kerrallaan.
fn mapSegmentRange(vaddr: u64, mem_size: u64, executable: bool, pml4_phys: u64) bool {
    // Sivun koko x86_64:ssa.
    const page_size = paging.PAGE_SIZE;
    // Ensimmäinen sivu alueen alussa (tasattu alaspäin).
    var page = vaddr & ~(page_size - 1);
    // Alueen yläraja (exclusive).
    const end = vaddr + mem_size;
    // Käy jokainen sivu alueella.
    while (page < end) : (page += page_size) {
        // Kartoita yksi sivu kohde-PML4:ään.
        if (!mapUserPage(page, executable, pml4_phys)) return false;
    }
    // Kaikki sivut kartoitettu.
    return true;
}

// Kopioi segmentin file-osuus ELF-blobista + nollaa BSS.
fn copySegmentData(seg: core.LoadSegment, elf_data: []const u8) bool {
    // Segmentin file data ELF-blobissa.
    if (seg.file_offset + seg.file_size > elf_data.len) return false;
    // Kohde muistissa segmentin linkitys-vaddr:ssa (user-ELF ei relocatable).
    const dst: [*]u8 = @ptrFromInt(seg.vaddr);
    // Lähde ELF-blobissa.
    const src = elf_data[seg.file_offset..][0..seg.file_size];
    // SMAP: salli user-sivujen kirjoitus kernelistä.
    user_access.stac();
    // Kopioi alustettu osa (file_size).
    @memcpy(dst[0..seg.file_size], src);
    // Nollaa BSS (mem_size - file_size) jos on.
    if (seg.mem_size > seg.file_size) {
        // BSS alkaa file-osion jälkeen.
        const bss_len = seg.mem_size - seg.file_size;
        // Nollaa laajennusalue.
        @memset(dst[seg.file_size..][0..bss_len], 0);
    }
    // Palauta SMAP-suojaus.
    user_access.clac();
    return true;
}

// Laske pinon sivun virtuaalinen alku annetusta heap-slotista.
fn stackBaseForSlot(stack_slot: u64) u64 {
    // Kiinteä HEAP_START + slot × 4 KiB (user-ELF linkitysosoitteet).
    return heap.HEAP_START + stack_slot * paging.PAGE_SIZE;
}

// Laske pinon yläreuna iretq:ä varten (16 tavun aligned).
fn stackTopForSlot(stack_slot: u64) u64 {
    // Yksi sivu pinolle — yläreuna - 16 tavua.
    return stackBaseForSlot(stack_slot) + paging.PAGE_SIZE - 16;
}

// Kartoita käyttäjäpinon yksi sivu annettuun osoitteeseen.
fn mapUserStackAt(stack_base: u64, pml4_phys: u64) bool {
    // Kartoita pinosivu (writable, ei executable).
    return mapUserPage(stack_base, false, pml4_phys);
}

// Lataa jäsennetty ELF muistiiin — pinon sivu stack_base:ssa, kohde-PML4.
fn loadParsed(parsed: core.ParsedElf, elf_data: []const u8, stack_base: u64, pml4_phys: u64) bool {
    // Tallenna aktiivinen CR3 — palautetaan kerneliin deferillä (Vaihe 27).
    const prev_cr3 = paging.getCr3();
    // Vaihda kohde-PML4:ään jotta @ptrFromInt(vaddr) toimii kopioinnissa.
    paging.setCr3(pml4_phys);
    // Kartoita jokainen PT_LOAD-segmentti.
    var ok: bool = true;
    // Varmista kernel CR3 palautus myös virhepoluilla.
    defer {
        if (pml4_phys != vmm.pml4Phys()) {
            // Prosessin osoiteavaruus — palaa aina kerneliin (ei luota prev_cr3:een).
            vmm.switchToKernel();
        } else if (prev_cr3 != pml4_phys) {
            // Kernel PML4 -lataus — palauta aiempi CR3.
            paging.setCr3(prev_cr3);
        }
    }
    for (parsed.segments) |seg| {
        // Suoritettavuus PF_X-bitistä.
        const executable = core.segmentExecutable(seg);
        // Kartoita sivut segmentin linkitys-vaddr:iin.
        if (!mapSegmentRange(seg.vaddr, seg.mem_size, executable, pml4_phys)) {
            ok = false;
            break;
        }
        // Kopioi tiedot ELF-blobista segmenttiin (VA aktiivisessa CR3:ssa).
        if (!copySegmentData(seg, elf_data)) {
            ok = false;
            break;
        }
    }
    // Kartoita erillinen käyttäjäpinon sivu annettuun osoitteeseen.
    if (ok and !mapUserStackAt(stack_base, pml4_phys)) ok = false;
    // Palauta onnistuminen.
    return ok;
}

// Lataa ELF blobista — jäsentää, kartoittaa ja palauttaa entry + stack_top.
pub fn loadElfWithStackInto(elf_data: []const u8, stack_slot: u64, pml4_phys: u64) ?LoadedImage {
    // Segmenttipuskuri parseElf:lle.
    var segments: [core.MAX_LOAD_SEGMENTS]core.LoadSegment = undefined;
    // Jäsennä ELF-otsikko ja PT_LOAD:t.
    const parsed = core.parseElf(elf_data, &segments) catch return null;
    // Pinon sivun alku valitusta slotista.
    const stack_base = stackBaseForSlot(stack_slot);
    // Kartoita segmentit ja pino prosessin tai kernelin PML4:ään.
    if (!loadParsed(parsed, elf_data, stack_base, pml4_phys)) return null;
    // Palauta hyppypiste ja pinon yläreuna (slidattu entry).
    return .{
        .entry = parsed.entry,
        .stack_top = stackTopForSlot(stack_slot),
    };
}

// Lataa ELF kernelin jaettuun PML4:ään (Vaihe 5–24 boot-testit).
pub fn loadElfWithStack(elf_data: []const u8, stack_slot: u64) ?LoadedImage {
    // Delegoi kernel PML4:ään.
    return loadElfWithStackInto(elf_data, stack_slot, vmm.pml4Phys());
}

// Lataa ELF blobista — oletuspino ja kernel PML4 (legacy boot-testit).
pub fn loadElf(elf_data: []const u8) ?LoadedImage {
    // Delegoi stack_slot + kernel PML4.
    return loadElfWithStack(elf_data, LOADER_TEST_STACK_SLOT);
}

// Boot-testi — lataa upotettu ELF, aja ring 3 (sys_write "elf" + paluu).
pub fn runBootTest() void {
    // Lataa test_elf blob kernel-muistiin / sivuja.
    const loaded = loadElfWithStack(test_elf, LOADER_TEST_STACK_SLOT) orelse {
        // Jäsentäminen tai kartoitus epäonnistui.
        log.err("ELF load failed");
        return;
    };
    // Siirry ring 3:een ladatun entry:n kautta.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return ret:llä (sama kuin usermode-testi).
    log.info("ELF loader test OK");
}
