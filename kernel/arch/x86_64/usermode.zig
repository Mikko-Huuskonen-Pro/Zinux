//! Ring 3 siirtymä — iretq käyttäjätilaan ja SYSCALL-palu reitti.
//!
//! **Vastuu**: Käyttäjäsivujen kartoitus, koodin kopiointi, boot-testi.
//! **Riippuvuudet**: `gdt.zig`, `vmm.zig`, `paging.zig`, `usermode_entry.S`
//! **Käytetään**: `kernel/main.zig`

// Tuo GDT — user code/data segmenttivalitsimet.
const gdt = @import("gdt.zig");
// Tuo VMM — uusien käyttäjäsivujen kartoitus.
const vmm = @import("../../mm/vmm.zig");
// Tuo sivulippujen rakenne.
const paging = @import("paging.zig");
// Tuo heap-alueen alku — käyttäjäsivut heapin jälkeen (4K-sivutaulut).
const heap = @import("../../mm/heap.zig");
// Tuo lokitus boot-viesteihin.
const log = @import("../../lib/log.zig");
// Tuo user_access — stac/clac SMAP-yhteensopivuuteen user-sivuille.
const user_access = @import("user_access.zig");

// Sivujen offset heapin alusta — yli INITIAL_PAGES (4) + marginaali.
const USER_PAGE_SLOT: u64 = 16;
// Käyttäjäkoodisivu — Limine higher-half 4K-taulut (ei 2 MiB huge).
const USER_CODE_ADDR: u64 = heap.HEAP_START + USER_PAGE_SLOT * paging.PAGE_SIZE;
// Käyttäjäpinon sivu — seuraava 4 KiB sivu.
const USER_STACK_ADDR: u64 = USER_CODE_ADDR + paging.PAGE_SIZE;
// Pinon yläreuna (kasvaa alaspäin).
const USER_STACK_TOP: u64 = USER_STACK_ADDR + paging.PAGE_SIZE - 16;

// Ring 3 sivulippu — present + writable + user.
const USER_PAGE_FLAGS = paging.PageFlags{
    // Sivu kartoitettu.
    .present = 1,
    // Kirjoitus sallittu.
    .writable = 1,
    // Ring 3 pääsee sivulle.
    .user = 1,
};

// Ring 3 testikoodi alku — kernel .text (kopioidaan user-sivulle).
extern fn userEntry() void;
// Ring 3 testikoodi loppu — kopiointimäärän laskentaan.
extern fn userEntryEnd() void;

// Kernel pinon osoite ennen iretq:ä — export assemblylle.
pub export var usermode_saved_kernel_rsp: u64 = 0;

// Siirry ring 3:een — usermode_jump.S iretq (palaa ret:llä sys_test_return:in kautta).
extern fn usermodeEnterIret(
    entry: u64,
    user_stack: u64,
    user_cs: u64,
    user_ss: u64,
    rflags: u64,
) callconv(.c) void;

// Palaa kernel boot-testiin — usermode_jump.S ret.
extern fn usermodeReturnToKernel() callconv(.c) noreturn;

// Kartoita 4K user-sivut, kopioi koodi, pakota P|W|U|!NX PTE:hen.
fn setupUserPages() bool {
    // Kopiointialue kernel .text:stä.
    const code_start: u64 = @intFromPtr(&userEntry);
    const code_end: u64 = @intFromPtr(&userEntryEnd);
    const code_len = code_end - code_start;
    // Koko yhden sivun sisällä.
    if (code_len == 0 or code_len > paging.PAGE_SIZE) return false;
    // Kartoita koodi- ja pino-sivut PMM:stä (user-sivutaulupolku).
    if (!vmm.mapNewUserPageEnsure(USER_CODE_ADDR, USER_PAGE_FLAGS)) return false;
    if (!vmm.mapNewUserPageEnsure(USER_STACK_ADDR, USER_PAGE_FLAGS)) return false;
    // Varmista U-bitti koko polussa; koodisivu myös suoritettava (NX=0).
    if (!paging.setUserPagePath(vmm.pml4Phys(), vmm.hhdm(), USER_CODE_ADDR, true)) return false;
    if (!paging.setUserPagePath(vmm.pml4Phys(), vmm.hhdm(), USER_STACK_ADDR, false)) return false;
    // Kopioi userEntry + userHello user-sivulle (SMAP: stac ennen user-kirjoitusta).
    const dst: [*]u8 = @ptrFromInt(USER_CODE_ADDR);
    const src: [*]const u8 = @ptrFromInt(code_start);
    user_access.stac();
    @memcpy(dst[0..code_len], src[0..code_len]);
    user_access.clac();
    return true;
}

// Palaa kerneliin sys_test_return-käsittelijästä.
pub fn returnToKernelTestContinue() noreturn {
    // Delegoi assembly-toteutukselle.
    usermodeReturnToKernel();
}

// Siirry ring 3:een annetulla entry:llä ja pinolla (iretq + sys_test_return paluu).
pub fn enterUser(entry: u64, user_stack_top: u64) void {
    // User segmenttivalitsimet RPL 3.
    const user_cs: u64 = gdt.USER_CODE_SEL | 3;
    const user_ss: u64 = gdt.USER_DATA_SEL | 3;
    // RFLAGS: bitti 1 pakollinen, IF=0.
    const rflags: u64 = 0x2;
    // Siirry ring 3:een — palaa ret:llä sys_test_return:in kautta.
    usermodeEnterIret(entry, user_stack_top, user_cs, user_ss, rflags);
}

// Boot-testi — ring 3 sys_write("hello") + paluu kerneliin.
pub fn runBootTest() void {
    // Kartoita sivut ja kopioi koodi.
    if (!setupUserPages()) {
        // Sivujen kartoitus epäonnistui.
        log.err("Usermode page setup failed");
        return;
    }
    // Siirry ring 3:een kopioituun blobiin.
    enterUser(USER_CODE_ADDR, USER_STACK_TOP);
    // Paluu sys_test_return ret:llä.
    log.info("Usermode test OK");
}
