//! Userland capability-ydin — oikeusmaskit (host-testattava).
//!
//! **Vastuu**: rights_mask-vakiot sys_cap_delegate-argumetille.
//! **Riippuvuudet**: ei
//! **Käytetään**: `cap.zig`, host-testit

// EPERM — ei grant-oikeutta tai liikaa oikeuksia.
pub const EPERM: i64 = -1;
// EBADF — virheellinen slotti.
pub const EBADF: i64 = -9;
// EINVAL — virheellinen maski.
pub const EINVAL: i64 = -22;

// read-oikeus maskissa.
pub const MASK_READ: u32 = 1 << 0;
// write-oikeus maskissa.
pub const MASK_WRITE: u32 = 1 << 1;
// send-oikeus maskissa.
pub const MASK_SEND: u32 = 1 << 2;
// recv-oikeus maskissa.
pub const MASK_RECV: u32 = 1 << 3;
// map-oikeus maskissa.
pub const MASK_MAP: u32 = 1 << 4;
// grant-oikeus maskissa.
pub const MASK_GRANT: u32 = 1 << 5;
// Kaikki sallitut bitit.
pub const MASK_ALL: u32 = MASK_READ | MASK_WRITE | MASK_SEND | MASK_RECV | MASK_MAP | MASK_GRANT;

// Onko negatiivinen syscall-paluuarvo virhe?
pub fn isError(ret: i64) bool {
    // Positiivinen tai nolla = onnistuminen (uusi slot-indeksi).
    return ret < 0;
}

// Kelpaako rights_mask (ei varattuja bittejä)?
pub fn validMask(mask: u32) bool {
    // Kaikki bitit MASK_ALL-joukon sisällä.
    return (mask & ~MASK_ALL) == 0;
}
