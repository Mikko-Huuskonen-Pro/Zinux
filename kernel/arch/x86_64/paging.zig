//! x86_64 sivutus — 4-tasoinen paging (PML4 → PDPT → PD → PT).
//!
//! **Vastuu**: CR3-luku, sivutaulujen kävely, yhden sivun kartoitus.
//! **Riippuvuudet**: ei
//! **Käytetään**: `mm/vmm.zig`

// Sivukoko x86_64:ssa on 4 KiB.
pub const PAGE_SIZE: u64 = 4096;
// Bittien määrä virtuaaliosoitteen indeksissä per taso.
pub const INDEX_BITS: u64 = 9;
// Maski yhden tason indeksille (512 merkintää per taulu).
pub const INDEX_MASK: u64 = 0x1FF;

// Sivutaulumerkinnän liput (x86_64 PTE/PDE bits).
pub const PageFlags = packed struct(u64) {
    present: u1 = 1,
    writable: u1 = 1,
    user: u1 = 0,
    write_through: u1 = 0,
    cache_disable: u1 = 0,
    accessed: u1 = 0,
    dirty: u1 = 0,
    huge: u1 = 0,
    global: u1 = 0,
    _avail: u3 = 0,
    addr: u52 = 0,

    pub fn toU64(self: PageFlags) u64 {
        return @bitCast(self);
    }

    pub fn fromU64(raw: u64) PageFlags {
        return @bitCast(raw);
    }
};

// 64-bit sivutaulumerkintä — sama rakenne kaikilla tasoilla.
pub const PageTableEntry = packed struct(u64) {
    present: u1,
    writable: u1,
    user: u1,
    write_through: u1,
    cache_disable: u1,
    accessed: u1,
    dirty: u1,
    huge: u1,
    global: u1,
    _avail: u3,
    addr: u52,

    pub fn isPresent(self: PageTableEntry) bool {
        return self.present == 1;
    }

    pub fn physicalAddr(self: PageTableEntry) u64 {
        return @as(u64, self.addr) << 12;
    }

    pub fn fromPhys(phys: u64, flags: PageFlags) PageTableEntry {
        var f = flags;
        f.addr = @truncate(phys >> 12);
        return @bitCast(f.toU64());
    }
};

// Lue CR3 — osoittaa aktiiviseen PML4-tauluun (fysinen osoite).
pub fn getCr3() u64 {
    var cr3: u64 = undefined;
    asm volatile ("mov %%cr3, %[out]"
        : [out] "=r" (cr3),
    );
    return cr3;
}

// Kirjoita CR3 — aktivoi uuden sivutaulun.
pub fn setCr3(pml4_phys: u64) void {
    asm volatile ("mov %[in], %%cr3"
        :
        : [in] "r" (pml4_phys),
    );
}

// Lue CR2 — page fault -virheen virtuaaliosoite.
pub fn getCr2() u64 {
    var cr2: u64 = undefined;
    asm volatile ("mov %%cr2, %[out]"
        : [out] "=r" (cr2),
    );
    return cr2;
}

// Poimi PML4-indeksi virtuaaliosoitteesta (bitit 47..39).
fn pml4Index(virt: u64) u64 {
    return (virt >> 39) & INDEX_MASK;
}

// Poimi PDPT-indeksi (bitit 38..30).
fn pdptIndex(virt: u64) u64 {
    return (virt >> 30) & INDEX_MASK;
}

// Poimi PD-indeksi (bitit 29..21).
fn pdIndex(virt: u64) u64 {
    return (virt >> 21) & INDEX_MASK;
}

// Poimi PT-indeksi (bitit 20..12).
fn ptIndex(virt: u64) u64 {
    return (virt >> 12) & INDEX_MASK;
}

// Muunna virtuaalinen sivutauluosoite HHDM:llä (phys + offset → virt).
pub fn physToVirt(phys: u64, hhdm: u64) *PageTableEntry {
    const virt = phys + hhdm;
    return @ptrFromInt(virt);
}

// Kartoita yksi 4 KiB sivu olemassa olevaan PML4:ään (Limine page tables).
pub fn mapPage(pml4_phys: u64, hhdm: u64, virt: u64, phys: u64, flags: PageFlags) bool {
    const pml4 = physToVirt(pml4_phys, hhdm);
    const pml4e = &pml4[pml4Index(virt)];
    if (!pml4e.isPresent()) return false;
    const pdpt = physToVirt(pml4e.physicalAddr(), hhdm);
    const pdpte = &pdpt[pdptIndex(virt)];
    if (!pdpte.isPresent()) return false;
    const pd = physToVirt(pdpte.physicalAddr(), hhdm);
    const pde = &pd[pdIndex(virt)];
    if (!pde.isPresent()) return false;
    const pt = physToVirt(pde.physicalAddr(), hhdm);
    const pte = &pt[ptIndex(virt)];
    pte.* = PageTableEntry.fromPhys(phys, flags);
    return true;
}

// TLB flush yhdelle sivulle — pakollinen CR3/muutoksen jälkeen.
pub fn flushTlb(virt: u64) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (virt),
    );
}
