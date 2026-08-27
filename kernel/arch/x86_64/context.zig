//! CPU-kontekstin tallennus ja vaihto x86_64:ssa.
//!
//! **Vastuu**: RSP-pohjainen kontekstinvaihto säikeiden välillä.
//! **Riippuvuudet**: `context_switch.S`
//! **Käytetään**: `sched/scheduler.zig`

// Tallennettu CPU-konteksti — toistaiseksi vain pinon osoitin.
pub const CpuContext = struct {
    // Pinon osoitin (RSP) kontekstinvaihtohetkellä.
    rsp: u64,
};

// Callee-saved rekisterit joita pushataan ennen kontekstinvaihtoa.
const CALLEE_PUSHES: usize = 6;

// Assembly-toteutus context_switch.S — ei kääntäjän prologia/epilogia.
extern fn switchContextAsm(prev_rsp: *u64, next_rsp: u64) callconv(.c) void;

// Zig-kääre assembly-funktiolle.
pub fn switchContext(prev_rsp: *u64, next_rsp: u64) void {
    // Delegoi context_switch.S switchContextAsm-symbolille.
    switchContextAsm(prev_rsp, next_rsp);
}

// Alusta uuden säikeen pinon — 6 dummy pop:ia + entry return-osoite.
pub fn initStack(stack: []u8, entry: *const fn () callconv(.c) void) u64 {
    // Pinon yläreuna (kasvaa alaspäin).
    var sp: u64 = @intFromPtr(stack.ptr) + stack.len;
    // 16-tavun tasaus alaspäin (x86_64 ABI vaatii ret→entry jälkeen RSP%16==8).
    sp &= ~@as(u64, 15);
    // Entry-osoite 16-tavun aligned slotissa (ret pop:ien jälkeen RSP%16==8).
    const entry_slot = sp - 16;
    @as(*u64, @ptrFromInt(entry_slot)).* = @intFromPtr(entry);
    // Dummy-arvot pop r15..rbx:lle (ensimmäisellä switch-to-this).
    const dummy_base = entry_slot - @as(u64, CALLEE_PUSHES) * 8;
    const callee_area: [*]u8 = @ptrFromInt(dummy_base);
    @memset(callee_area[0 .. CALLEE_PUSHES * 8], 0);
    // RSP osoittaa dummy-blokin alkuun — switchContext pop + ret toimii.
    return dummy_base;
}
