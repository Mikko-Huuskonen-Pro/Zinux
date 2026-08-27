//! IPC-estävän recv-ydin — odotusloopin ja timer-wake-tilan host-testit.
//!
//! **Vastuu**: Timer-arm state, odotus ennen uudelleenyritystä.
//! **Riippuvuudet**: ei
//! **Käytetään**: `ipc_block.zig`, host-testit

// Montako tickiä odotetaan ennen timer-lähetystä boot-testissä.
pub const BOOT_SEND_DELAY_TICKS: u64 = 2;

// Timer-wake tila — port_id johon viesti lähetetään IRQ:sta (kernel sisäinen).
var armed_port_id: ?u32 = null;
// Montako tickiä armauksen jälkeen lähetetään.
var armed_delay: u64 = 0;
// Tick-laskuri armon hetkellä.
var armed_at_tick: u64 = 0;
// Onko timer-lähetys jo tehty.
var armed_sent: bool = false;

// Montako pause-kierrosta odotusloopissa (~muutama ms @ 100 Hz timer).
const WAIT_SPIN_LIMIT: u32 = 2_000_000;

// Aseista timer-wake — lähetä viesti porttiin delay tickin kuluttua.
pub fn armTimerSendViaPort(port_id: u32, current_tick: u64, delay_ticks: u64) void {
    // Tallenna kohde-portti.
    armed_port_id = port_id;
    // Viive tickinä.
    armed_delay = delay_ticks;
    // Aloitushetki.
    armed_at_tick = current_tick;
    // Ei vielä lähetetty.
    armed_sent = false;
}

// Poista timer-wake — boot-testin jälkeen.
pub fn disarm() void {
    // Ei kohde-porttia.
    armed_port_id = null;
    // Nollaa viive.
    armed_delay = 0;
    // Nollaa aloitustick.
    armed_at_tick = 0;
    // Nollaa lähetyslippu.
    armed_sent = false;
}

// Onko timer-lähetys jo suoritettu?
pub fn isSent() bool {
    // Muistiesto — näe IRQ-päivitetty armed_sent.
    asm volatile ("" ::: .{ .memory = true });
    // Palauta lähetyslippu.
    return armed_sent;
}

// Hae aseistettu portti (timer-lähetystä varten).
pub fn armedPort() ?u32 {
    // Palauta port_id tai null.
    return armed_port_id;
}

// Merkitse timer-lähetys valmiiksi.
pub fn markSent() void {
    // Lähetys tehty.
    armed_sent = true;
    // Muistiesto — näkyy pääsäikeelle heti IRQ:n jälkeen.
    asm volatile ("" ::: .{ .memory = true });
}

// Pitäisikö timer lähettää viestin tällä tickillä?
pub fn shouldFire(now_tick: u64) bool {
    // Ei aseistettu.
    if (armed_port_id == null) return false;
    // Jo lähetetty.
    if (isSent()) return false;
    // Viive ei täyttynyt.
    if (now_tick < armed_at_tick + armed_delay) return false;
    // Lähetä nyt.
    return true;
}

// Odotus ennen recv-uudelleenyritystä — spin kunnes timer on lähettänyt.
pub fn waitForMessage() void {
    // Odota kunnes timer-wake merkitsee lähetyksen valmiiksi.
    while (!isSent()) {
        // Ota keskeytykset käyttöön — PIT IRQ0 vaatii IF=1.
        asm volatile ("sti" ::: .{ .memory = true });
        // Spin yksi quantum — timer IRQ voi keskeyttää.
        var spin: u32 = 0;
        while (spin < WAIT_SPIN_LIMIT) : (spin += 1) {
            // CPU-friendly spin.
            asm volatile ("pause" ::: .{ .memory = true });
            // Herää heti kun timer lähetti viestin.
            if (isSent()) break;
        }
        // Palauta keskeytysmaski ennen seuraavaa recv-yritystä.
        asm volatile ("cli" ::: .{ .memory = true });
    }
}
