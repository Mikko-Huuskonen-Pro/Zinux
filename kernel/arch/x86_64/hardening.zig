//! SMEP/SMAP aktivointi — CR4 + CPUID (kernel).
//!
//! **Vastuu**: Ota SMEP/SMAP käyttöön jos CPU tukee, boot-testi.
//! **Riippuvuudet**: `hardening_core.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo ydin — bitit ja tila-analyysi.
const core = @import("hardening_core.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../../lib/log.zig");

// Viimeisin aktivointitila boot-testiä varten.
var last_state: core.HardeningState = .{
    .smep_supported = false,
    .smap_supported = false,
    .smep_enabled = false,
    .smap_enabled = false,
};

// Suorita CPUID — palauttaa EAX/EBX/ECX/EDX (Zig 0.16: +{rax} in/out).
fn cpuid(leaf: u32, subleaf: u32) struct { eax: u32, ebx: u32, ecx: u32, edx: u32 } {
    // Syötä leaf/subleaf rekistereihin ennen cpuid-komentoa.
    var eax: u32 = leaf;
    var ebx: u32 = undefined;
    var ecx: u32 = subleaf;
    var edx: u32 = undefined;
    // CPUID täyttää kaikki neljä rekisteriä.
    asm volatile ("cpuid"
        : [eax] "+{rax}" (eax),
          [ebx] "+{rbx}" (ebx),
          [ecx] "+{rcx}" (ecx),
          [edx] "+{rdx}" (edx),
    );
    // Palauta rekisterit struct-muodossa.
    return .{ .eax = eax, .ebx = ebx, .ecx = ecx, .edx = edx };
}

// Lue extended features EBX (leaf 7 sub 0).
fn readExtFeaturesEbx() u32 {
    // Leaf 7 subleaf 0 — structured extended features.
    const r = cpuid(core.CPUID_LEAF_EXT_FEATURES, 0);
    // Palauta EBX (SMEP/SMAP-bitit); 0 jos CPUID epäonnistui.
    return r.ebx;
}

// Lue CR4-rekisteri.
fn readCr4() u64 {
    // mov cr4 → rax.
    return asm volatile ("mov %%cr4, %[ret]"
        : [ret] "=r" (-> u64),
    );
}

// Kirjoita CR4-rekisteri.
fn writeCr4(value: u64) void {
    // mov rax → cr4.
    asm volatile ("mov %[val], %%cr4"
        :
        : [val] "r" (value),
    );
}

// Ota SMEP/SMAP käyttöön CR4:ään jos CPU tukee.
pub fn init() void {
    // Lue extended features CPUID:llä (leaf 7 sub 0).
    const ext_ebx = readExtFeaturesEbx();
    // CR4 ennen muutosta.
    const cr4_before = readCr4();
    // Laske uusi CR4 OR-aten vain CPUID-vahvistetut bitit.
    const cr4_next = core.cr4WithHardening(cr4_before, ext_ebx);
    // Kirjoita CR4 vain jos muutos.
    if (cr4_next != cr4_before) writeCr4(cr4_next);
    // CR4 aktivoinnin jälkeen.
    const cr4_after = readCr4();
    // Tila CPUID EBX:stä ja CR4 readbackista.
    last_state = core.makeState(ext_ebx, cr4_after);
}

// Palauta viimeisin aktivointitila.
pub fn state() core.HardeningState {
    // Palauta globaali tila.
    return last_state;
}

// Onko SMAP aktivoitu CR4:ssä (stac/clac tarvitaan vain silloin).
pub fn smapActive() bool {
    // Palauta enabled-lippu init():stä.
    return last_state.smap_enabled;
}

// Boot-testi — vahvista SMEP/SMAP enabled jos tuettu.
pub fn runBootTest() void {
    // Hae tallennettu tila init():stä.
    const st = state();
    // Tuettu mutta ei enabled → virhe.
    if (!core.activationOk(st)) {
        // CR4-bitti puuttuu vaikka CPU tukee.
        log.err("SMEP/SMAP activation failed");
        // Lopeta testi.
        return;
    }
    // Ei tukea ollenkaan — informatiivinen (vanha CPU / emulaattori).
    if (!st.smep_supported and !st.smap_supported) {
        // Ohita — ei vaadita CI:ssä.
        log.info("SMEP/SMAP not supported");
        // Valmis.
        return;
    }
    // Vähintään yksi ominaisuus aktivoitu.
    log.info("SMEP/SMAP hardening OK");
}
