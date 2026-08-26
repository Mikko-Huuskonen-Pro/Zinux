//! CPU-kontekstin tallennus ja vaihto x86_64:ssa.
//!
//! **Vastuu**: RSP-pohjainen kontekstinvaihto säikeiden välillä.
//! **Riippuvuudet**: ei
//! **Käytetään**: `sched/scheduler.zig`

// Tallennettu CPU-konteksti — toistaiseksi vain pinon osoitin.
pub const CpuContext = struct {
    // Pinon osoitin (RSP) kontekstinvaihtohetkellä.
    rsp: u64,
};

// Vaihda säie: tallenna nykyinen RSP ja lataa seuraavan RSP, sitten ret.
pub export fn switchContext(prev_rsp: *u64, next_rsp: u64) callconv(.c) void {
    // Sidonta parametrit asm:iin — estää unused-varoituksen.
    const prev = prev_rsp;
    const next = next_rsp;
    // Tallenna nykyinen RSP, lataa uusi, hyppää ret:llä uuden pinon return-osoitteeseen.
    asm volatile (
        \\mov %%rsp, (%[prev])
        \\mov %[next], %%rsp
        \\ret
        :
        : [prev] "r" (prev),
          [next] "r" (next),
        : .{ .memory = true });
}

// Alusta uuden säikeen pinon — pushaa entry-osoitteen ja palauta RSP.
pub fn initStack(stack: []u8, entry: *const fn () callconv(.c) void) u64 {
    // Pinon yläreuna (kasvaa alaspäin).
    var sp: u64 = @intFromPtr(stack.ptr) + stack.len;
    // x86_64 ABI vaatii 16-tavun pinon tasaus ennen call/ret.
    sp &= ~@as(u64, 15);
    // Varaa tila return-osoitteelle.
    sp -= 8;
    // Kirjoita entry-osoite pinolle — ret hyppää tähän.
    @as(*u64, @ptrFromInt(sp)).* = @intFromPtr(entry);
    // Palauta alustettu RSP.
    return sp;
}
