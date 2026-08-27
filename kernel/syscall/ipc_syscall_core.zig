//! IPC-syscall-ydin — PortError → ABI-virhekoodit (host-testattava).
//!
//! **Vastuu**: Muunna port_core-virheet negatiivisiksi paluuarvoiksi.
//! **Riippuvuudet**: ei
//! **Käytetään**: `dispatch.zig`, host-testit

// Virhekoodit — sama kuin zinuxabi (host-testit eivät importtaa ABI:ta).
pub const EBADF: i64 = -9;
// Yritä myöhemmin — tyhjä jono tai täysi jono.
pub const EAGAIN: i64 = -11;
// Virheellinen argumentti — liian suuri viesti tms.
pub const EINVAL: i64 = -22;

// PortError-joukon virheet dispatch-käsittelijöitä varten.
pub const PortErr = error{
    // Porttia tai capability-slottia ei löydy.
    NotFound,
    // Viestijono täynnä (send).
    Full,
    // Viestijono tyhjä (recv).
    Empty,
    // Viesti ylittää MAX_MSG_SIZE.
    TooLarge,
    // Porttiydin ei alustettu.
    NotInitialized,
};

// Muunna PortError → negatiivinen ABI-paluuarvo.
pub fn mapPortError(err: PortErr) i64 {
    // switch jokaiselle port_core-virheelle.
    return switch (err) {
        // Huono capability-slotti tai portti → EBADF.
        error.NotFound => EBADF,
        // Jono täynnä → EAGAIN (non-blocking recv/send tyyli).
        error.Full => EAGAIN,
        // Ei viestejä → EAGAIN.
        error.Empty => EAGAIN,
        // Liian suuri payload → EINVAL.
        error.TooLarge => EINVAL,
        // Ydin ei valmis → EINVAL.
        error.NotInitialized => EINVAL,
    };
}
