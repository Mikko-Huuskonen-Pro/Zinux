//! Zinux ABI — jaettu rajapinta kernelin ja käyttäjätilan välillä.
//!
//! **Vastuu**: Syscall-numerot, virhekoodit, vakiorakenteet.
//! **Käytetään**: `kernel/syscall/`, `userland/` (Vaihe 4+)

// Syscall-numerointi — vakio enum, ei magic number -litereitä.
pub const Syscall = enum(u64) {
    // Lopeta prosessi — vastaa Unix exit(2).
    exit = 0,
    // Kirjoita tietoa tiedostokuvaukseen — vastaa Unix write(2).
    write = 1,
    // Lue tietoa tiedostokuvauksesta — vastaa Unix read(2).
    read = 2,
    // Luo uusi capability-objekti.
    cap_create = 10,
    // Delegoi capability toiselle prosessille.
    cap_delegate = 11,
    // Lähetä IPC-viesti porttiin.
    ipc_send = 12,
    // Vastaanota IPC-viesti portista.
    ipc_recv = 13,
    // Kartoita muistisivu capabilityn perusteella.
    mem_map = 14,
};

// Paluuarvot syscall-kutsuista — 0 = onnistui, muuten virhekoodi.
pub const Error = enum(u64) {
    // Operaatio onnistui.
    ok = 0,
    // Virheellinen argumentti.
    invalid_arg = 1,
    // Oikeudet eivät riitä (capability puuttuu).
    permission_denied = 2,
    // Resurssia ei löydy (esim. virheellinen handle).
    not_found = 3,
    // Ei muistia (allokaatio epäonnistui).
    out_of_memory = 4,
    // Operaatio blokkaisi — yritä uudelleen (non-blocking tilassa).
    would_block = 5,
};
