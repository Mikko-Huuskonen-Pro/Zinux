//! Pinon canary-ydin — maalaus ja tarkistus (host-testattava).
//!
//! **Vastuu**: 64-bit canary pinon alareunaan (stack kasvaa alaspäin).
//! **Riippuvuudet**: ei
//! **Käytetään**: `stack_canary.zig`, host-testit

// Canary-magic — tunnistettava 64-bit arvo pinon alaosassa.
pub const CANARY: u64 = 0x5A1F_C0DE_CAFE_BABE;

// Maalaa canary pinon alimpiin 8 tavuun (stack[0..8]).
pub fn paintBottom(stack: []const u8) void {
    // Osoitin pinon alareunaan u64-kirjoitusta varten (const → mut).
    const slot: *u64 = @constCast(@ptrCast(@alignCast(stack.ptr)));
    // Kirjoita magic — ylivuoto ylikirjoittaa tämän.
    slot.* = CANARY;
}

// Tarkista että pinon alareunan canary on ehjä.
pub fn checkBottom(stack: []const u8) bool {
    // Osoitin pinon alareunaan luettavana u64:na.
    const slot: *const u64 = @ptrCast(@alignCast(stack.ptr));
    // Vertaa magic-arvoon.
    return slot.* == CANARY;
}

// Tarkista kaikki pinot — palauta false jos jokin rikki.
pub fn verifyAll(stacks: []const []const u8) bool {
    // Käy jokainen rekisteröity pino.
    for (stacks) |stack| {
        // Yksikin rikki → epäonnistuminen.
        if (!checkBottom(stack)) return false;
    }
    // Kaikki ehjiä.
    return true;
}
