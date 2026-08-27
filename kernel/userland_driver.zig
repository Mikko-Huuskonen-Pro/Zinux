//! Käyttäjätilan ajuritestin käynnistys — ELF-loader + ring 3.
//!
//! **Vastuu**: Lataa upotettu driver-test-ELF ja aja registry-demoa.
//! **Riippuvuudet**: `loader/elf.zig`, `arch/x86_64/usermode.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu ajuritesti-ELF — build.zig kopioi userland/drivers ennen kernel-käännöstä.
const driver_elf = @embedFile("loader/driver_prog.bin");

// Ajuritestin pinon heap-slot — erillään shell (67) ja init (49) sloteista.
const DRIVER_STACK_SLOT: u64 = 83;

// Boot-testi — lataa ajuritesti-ELF, hyppää ring 3:een, odota sys_test_return.
pub fn runBootTest() void {
    // Lataa ajuritesti-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(driver_elf, DRIVER_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland driver ELF load failed");
        // Lopeta testi.
        return;
    };
    // Siirry ring 3:een ajuritestin entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland driver OK".
    log.info("Userland driver test OK");
}
