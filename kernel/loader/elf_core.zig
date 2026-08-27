//! ELF64-ydin — otsikon ja PT_LOAD-segmenttien jäsentäminen (host-testattava).
//!
//! **Vastuu**: Validoi ET_EXEC x86_64 -binääri, palauta entry + segmentit.
//! **Riippuvuudet**: ei
//! **Käytetään**: `elf.zig`, host-testit

// std.mem — magic-vertailuun.
const std = @import("std");

// ELF-magic tavut 0..3 ident-kentässä.
pub const ELF_MAGIC: [4]u8 = .{ 0x7F, 'E', 'L', 'F' };
// ELF-luokka: 64-bittinen (ident[4]).
pub const ELFCLASS64: u8 = 2;
// ELF-data: little-endian (ident[5]).
pub const ELFDATA2LSB: u8 = 1;
// ELF-versio ident[6] — nykyinen = 1.
pub const EV_CURRENT: u8 = 1;
// Kohde-CPU: x86_64.
pub const EM_X86_64: u16 = 62;
// Tiedostotyyppi: suoritettava staattinen binääri.
pub const ET_EXEC: u16 = 2;
// Segmenttityyppi: ladattava muistialue.
pub const PT_LOAD: u32 = 1;
// Segmenttilippu: luettavissa.
pub const PF_R: u32 = 4;
// Segmenttilippu: kirjoitettavissa.
pub const PF_W: u32 = 2;
// Segmenttilippu: suoritettavissa.
pub const PF_X: u32 = 1;

// Maksimi PT_LOAD-segmenttien määrä boot-polussa.
pub const MAX_LOAD_SEGMENTS: usize = 8;

// ELF64-otsikko (52 tavua + ident).
pub const Elf64Ehdr = extern struct {
    // Magic + luokka + endian + versio + OS/ABI.
    e_ident: [16]u8,
    // Tiedostotyyppi (ET_EXEC, …).
    e_type: u16,
    // Kohde-arkkitehtuuri (EM_X86_64).
    e_machine: u16,
    // ELF-versio (1).
    e_version: u32,
    // Suoritus alkaa tästä virtuaaliosoitteesta.
    e_entry: u64,
    // Program header -taulukon tiedosto-offset.
    e_phoff: u64,
    // Section header -taulukon tiedosto-offset (ei käytössä loaderissa).
    e_shoff: u64,
    // Prosessorikohtaiset liput.
    e_flags: u32,
    // Otsikon koko tavuina.
    e_ehsize: u16,
    // Yhden program header -merkinnän koko.
    e_phentsize: u16,
    // Program header -merkintöjen lukumäärä.
    e_phnum: u16,
    // Section header -merkinnän koko.
    e_shentsize: u16,
    // Section header -merkintöjen lukumäärä.
    e_shnum: u16,
    // Section header -merkintä otsikko-osiolle.
    e_shstrndx: u16,
};

// ELF64 program header (PT_LOAD jne.).
pub const Elf64Phdr = extern struct {
    // Segmenttityyppi (PT_LOAD = 1).
    p_type: u32,
    // Segmenttiliput PF_R/W/X.
    p_flags: u32,
    // Segmentin alku tiedostossa (tavu).
    p_offset: u64,
    // Virtuaalinen latausosoite muistissa.
    p_vaddr: u64,
    // Fyysinen osoite (käytämme identtistä vaddr).
    p_paddr: u64,
    // Segmentin koko tiedostossa.
    p_filesz: u64,
    // Segmentin koko muistissa (≥ filesz, BSS nollataan).
    p_memsz: u64,
    // Kohdistus (4096 tyypillisesti).
    p_align: u64,
};

// Yksi ladattava PT_LOAD-segmentti loaderille.
pub const LoadSegment = struct {
    // Virtuaalinen alkuosoite.
    vaddr: u64,
    // Muistissa varattava koko (sis. BSS).
    mem_size: u64,
    // Tiedostosta kopioitava koko.
    file_size: u64,
    // Offset ELF-blobissa.
    file_offset: u64,
    // PF_R | PF_W | PF_X.
    flags: u32,
};

// Jäsennetyn ELF:n tulos — viittaa callerin segmenttipuskuriin.
pub const ParsedElf = struct {
    // e_entry — ring 3 hyppypiste.
    entry: u64,
    // Ladattavat segmentit (slice segmenttipuskuriin).
    segments: []LoadSegment,
};

// Loader-virheet — palautetaan parseElf:stä.
pub const ElfError = error{
    // Blob liian pieni otsikkoa varten.
    TooSmall,
    // Magic ei 7F 45 4C 46.
    BadMagic,
    // Ei 64-bittinen ELF.
    NotElf64,
    // Väärä kone (ei x86_64).
    WrongMachine,
    // Väärä tyyppi (ei ET_EXEC).
    WrongType,
    // Program header -taulukko ulkopuolella / rikki.
    BadProgramHeader,
    // Liian monta PT_LOAD-segmenttiä.
    TooManySegments,
    // Segmentin file range ylittää blobin.
    SegmentOutOfBounds,
};

// Tarkista ELF ident -magic ja luokka.
fn validateIdent(ident: *const [16]u8) ElfError!void {
    // Vertaa neljä magic-tavua.
    if (!std.mem.eql(u8, ident[0..4], &ELF_MAGIC)) return ElfError.BadMagic;
    // Varmista 64-bittinen luokka.
    if (ident[4] != ELFCLASS64) return ElfError.NotElf64;
    // Varmista little-endian.
    if (ident[5] != ELFDATA2LSB) return ElfError.BadProgramHeader;
    // Varmista ELF-versio ident-kentässä.
    if (ident[6] != EV_CURRENT) return ElfError.BadProgramHeader;
}

// Jäsennä ELF64 ET_EXEC — kerää PT_LOAD-segmentit segmenttipuskuriin.
pub fn parseElf(
    data: []const u8,
    segments_out: *[MAX_LOAD_SEGMENTS]LoadSegment,
) ElfError!ParsedElf {
    // Otsikon pitää mahtua blobiin.
    if (data.len < @sizeOf(Elf64Ehdr)) return ElfError.TooSmall;
    // Otsikko — align(1) sallii @embedFile -blobin (ei 8-tavun aligned).
    const hdr: *align(1) const Elf64Ehdr = @ptrCast(data.ptr);
    // Tarkista magic + luokka.
    try validateIdent(&hdr.e_ident);
    // Varmista x86_64.
    if (hdr.e_machine != EM_X86_64) return ElfError.WrongMachine;
    // Varmista suoritettava staattinen binääri.
    if (hdr.e_type != ET_EXEC) return ElfError.WrongType;
    // Program header -koko ja lukumäärä oltava järkevät.
    if (hdr.e_phentsize != @sizeOf(Elf64Phdr)) return ElfError.BadProgramHeader;
    if (hdr.e_phnum == 0) return ElfError.BadProgramHeader;
    // Program header -taulukko mahtuu tiedostoon.
    const ph_end = hdr.e_phoff + @as(u64, hdr.e_phnum) * @as(u64, hdr.e_phentsize);
    if (ph_end > data.len) return ElfError.BadProgramHeader;
    // Kerää PT_LOAD-segmentit.
    var seg_count: usize = 0;
    var i: u16 = 0;
    while (i < hdr.e_phnum) : (i += 1) {
        // Laske tämän PHDR:n offset blobissa.
        const off = hdr.e_phoff + @as(u64, i) * @as(u64, hdr.e_phentsize);
        // Program header — align(1) luku blobista.
        const ph: *align(1) const Elf64Phdr = @ptrCast(data.ptr + off);
        // Ohita ei-LOAD segmentit (PT_PHDR, PT_INTERP, …).
        if (ph.p_type != PT_LOAD) continue;
        // Segmentin file range blobin sisällä.
        if (ph.p_offset + ph.p_filesz > data.len) return ElfError.SegmentOutOfBounds;
        // filesz ≤ memsz loader-sääntö.
        if (ph.p_filesz > ph.p_memsz) return ElfError.BadProgramHeader;
        // Liian monta LOAD-segmenttiä.
        if (seg_count >= MAX_LOAD_SEGMENTS) return ElfError.TooManySegments;
        // Täytä LoadSegment-kentät.
        segments_out[seg_count] = .{
            .vaddr = ph.p_vaddr,
            .mem_size = ph.p_memsz,
            .file_size = ph.p_filesz,
            .file_offset = ph.p_offset,
            .flags = ph.p_flags,
        };
        // Kasvata segmenttilaskuria.
        seg_count += 1;
    }
    // Vähintään yksi PT_LOAD vaaditaan.
    if (seg_count == 0) return ElfError.BadProgramHeader;
    // Palauta entry + segmenttislice.
    return .{
        .entry = hdr.e_entry,
        .segments = segments_out[0..seg_count],
    };
}

// Onko segmentti suoritettava (PF_X)?
pub fn segmentExecutable(seg: LoadSegment) bool {
    // PF_X bitti 0.
    return (seg.flags & PF_X) != 0;
}

// Onko segmentti kirjoitettava (PF_W)?
pub fn segmentWritable(seg: LoadSegment) bool {
    // PF_W bitti 1.
    return (seg.flags & PF_W) != 0;
}

// Host-testit — ajetaan `zig build test`:llä.
test "parse rejects bad magic" {
    // Liian pieni blob.
    var buf: [16]u8 = undefined;
    // Segmenttipuskuri (ei käytetä onnistuneessa polussa).
    var segs: [MAX_LOAD_SEGMENTS]LoadSegment = undefined;
    // Odotetaan TooSmall — alle otsikon koko.
    try std.testing.expectError(ElfError.TooSmall, parseElf(&buf, &segs));
}

test "parse real loader-test ELF when embedded" {
    // Upotettu blob — build kopioi ennen kernel-käännöstä.
    const data = @embedFile("test_prog.bin");
    // Segmenttipuskuri parseElf:lle.
    var segs: [MAX_LOAD_SEGMENTS]LoadSegment = undefined;
    // Jäsennä blob.
    const parsed = try parseElf(data, &segs);
    // Entry = _start (toinen PT_LOAD, R E) — ei file alku.
    try std.testing.expect(parsed.entry == 0xFFFFFFFF9002002c);
    // Kaksi LOAD-segmenttiä (rodata + text).
    try std.testing.expect(parsed.segments.len >= 2);
    // Suoritettava segmentti löytyy.
    var has_exec = false;
    for (parsed.segments) |seg| {
        if (segmentExecutable(seg)) has_exec = true;
    }
    try std.testing.expect(has_exec);
}
