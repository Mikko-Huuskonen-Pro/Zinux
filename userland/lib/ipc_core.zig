//! Userland IPC-ydin — pituusrajat ja syscall-paluuarvojen tulkinta (host-testattava).
//!
//! **Vastuu**: Viestin max-koko, negatiivinen paluu = virhe.
//! **Riippuvuudet**: ei
//! **Käytetään**: `ipc.zig`, host-testit

// Yhden IPC-viestin max-pituus — sama kuin kernel port_core.MAX_MSG_SIZE.
pub const MAX_MSG_SIZE: usize = 32;
// EBADF — huono capability-slotti tai portti.
pub const EBADF: i64 = -9;
// EAGAIN — tyhjä tai täysi jono.
pub const EAGAIN: i64 = -11;
// EINVAL — liian suuri viesti tai virheellinen argumentti.
pub const EINVAL: i64 = -22;

// Onko syscall-paluuarvo virhe (negatiivinen)?
pub fn isError(ret: i64) bool {
    // Positiivinen tai nolla = onnistuminen.
    return ret < 0;
}

// Kelpaako lähetettävä pituus?
pub fn validSendLen(len: usize) bool {
    // Sallitaan tyhjä viesti ja max MAX_MSG_SIZE.
    return len <= MAX_MSG_SIZE;
}

// Kelpaako vastaanottopuskurin pituus (vähintään 1 tavu)?
pub fn validRecvBufLen(len: usize) bool {
    // Tyhjä puskuri ei ole järkevä recv-kutsussa.
    return len > 0;
}

// Muunna negatiivinen syscall-paluuarvo ipc_core-virhekoodiksi (testattavuus).
pub fn classifyError(ret: i64) ?i64 {
    // Onnistunut paluu — ei virhettä.
    if (ret >= 0) return null;
    // Tunnetut virhekoodit palautetaan sellaisenaan.
    return switch (ret) {
        // EBADF.
        EBADF => EBADF,
        // EAGAIN.
        EAGAIN => EAGAIN,
        // EINVAL.
        EINVAL => EINVAL,
        // Tuntematon negatiivinen → EINVAL.
        else => EINVAL,
    };
}
