//! Userland cap create boot-testi — lataa cap_create_test-ELF, ring 3 create-demo.
//!
//! **Vastuu**: Lataa ELF ja aja cap.createPort + ipc roundtrip ring 3:ssa.
//! **Riippuvuudet**: `loader/elf.zig`, `usermode.zig`, log
//! **Käytetään**: `kernel/main.zig`

// Tuo ELF-loader — PT_LOAD kartoitus ja pinon varaus.
const elf = @import("loader/elf.zig");
// Tuo ring 3 siirtymä — iretq entry + sys_test_return paluu.
const usermode = @import("arch/x86_64/usermode.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("lib/log.zig");

// Upotettu cap_create-testi-ELF — build.zig kopioi ennen kernel-käännöstä.
const cap_create_test_elf = @embedFile("loader/cap_create_test_prog.bin");

// Cap create -testin pinon heap-slot — erillään muista user-ELF:istä.
const CAP_CREATE_STACK_SLOT: u64 = 102;

// Boot-testi — lataa cap_create_test-ELF, hyppää ring 3:een.
pub fn runBootTest() void {
    // Lataa cap_create_test-ELF muistiiin (segmentit + user-pino).
    const loaded = elf.loadElfWithStack(cap_create_test_elf, CAP_CREATE_STACK_SLOT) orelse {
        // Jäsentäminen tai sivukartoitus epäonnistui.
        log.err("Userland cap create ELF load failed");
        // Lopeta testi.
        return;
    };
    // Siirry ring 3:een capCreateMain entry-pisteessä.
    usermode.enterUser(loaded.entry, loaded.stack_top);
    // Paluu sys_test_return:lla — userland tulosti "userland cap create OK".
    log.info("Userland cap create test OK");
}
