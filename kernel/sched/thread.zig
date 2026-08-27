//! Säie — yksittäinen suoritettava virta omalla pinolla.
//!
//! **Vastuu**: Säikeen pino ja CPU-konteksti.
//! **Riippuvuudet**: `arch/x86_64/context.zig`
//! **Käytetään**: `scheduler.zig`

// Tuo CPU-konteksti pinon alustukseen.
const context = @import("../arch/x86_64/context.zig");

// Säikeen pinon koko — 4 KiB riittää yksinkertaiseen kernel-säikeeseen.
pub const STACK_SIZE: usize = 4096;

// Säikeen tila aikataulutusta varten.
pub const ThreadState = enum {
    // Säie odottaa CPU-aikaa.
    ready,
    // Säie suorittaa parhaillaan.
    running,
};

// Yksittäinen kernel-säie.
pub const Thread = struct {
    // Säikeen yksilöllinen tunniste.
    id: u32,
    // Tallennettu CPU-konteksti (RSP kontekstinvaihtoon).
    ctx: context.CpuContext,
    // Säikeen privaatti pinomuisti.
    stack: [STACK_SIZE]u8 align(16),
    // Säikeen tila scheduler-jonoa varten.
    state: ThreadState,
};

// Alusta säie annetulla id:llä ja entry-funktiolla.
pub fn init(thread: *Thread, id: u32, entry: *const fn () callconv(.c) void) void {
    // Aseta säikeen tunniste.
    thread.id = id;
    // Alusta pinon RSP entry-funktion call-kelpoiseksi.
    thread.ctx.rsp = context.initStack(&thread.stack, entry);
    // Säie alustetaan valmiiksi ajettavaksi.
    thread.state = .ready;
}
