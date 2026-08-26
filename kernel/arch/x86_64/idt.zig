//! Interrupt Descriptor Table (IDT) x86_64:lle + page fault -käsittelijä.
//!
//! **Vastuu**: Keskeytykset, poikkeukset (#14 page fault).
//! **Riippuvuudet**: `gdt.zig`, `paging.zig`, `../../lib/log.zig`, `../../drivers/char/uart.zig`
//! **Käytetään**: `kernel/main.zig`

// Tuo GDT segmenttivalitsimet IDT-merkintöjen selector-kenttään.
const gdt = @import("gdt.zig");
// Tuo CR2-luku page fault -osoitteen varmistukseen.
const paging = @import("paging.zig");
// Tuo lokitusmoduuli virheviestien tulostukseen.
const log = @import("../../lib/log.zig");
// Tuo UART suoraan heksadesimaalitulostukseen (runtime-arvot).
const uart = @import("../../drivers/char/uart.zig");
// Tuo PIC EOI timer-käsittelijään.
const pic = @import("pic.zig");
// PIT-tickien laskuri — taustatimer Vaihe 3:lle.
var timer_ticks: u64 = 0;

// IDT-merkintä — 128-bittinen kuvaus yhdestä keskeytys/poikkeusvektorista.
const IdtEntry = packed struct {
    // Handler-funktion alaosat (bittit 0..15).
    offset_low: u16,
    // GDT-segmenttivalitsin (kernel code = 0x08).
    selector: u16,
    // Interrupt Stack Table -indeksi (0 = käytä nykyistä pinon).
    ist: u8,
    // Gate type + DPL + present (0x8E = 64-bit interrupt gate, DPL 0).
    type_attr: u8,
    // Handler-funktion keskiosa (bittit 16..31).
    offset_mid: u16,
    // Handler-funktion yläosa (bittit 32..63).
    offset_high: u32,
    // Varattu — pitää olla nolla x86_64:ssa.
    zero: u32,

    // Muodosta IDT-merkintä handler-osoitteesta ja attribuuteista.
    fn init(handler: u64, selector: u16, type_attr: u8) IdtEntry {
        // Palauta täytetty merkintä handler-osoitteen kolmesta osasta.
        return .{
            // Alimmat 16 bittiä handler-osoitteesta.
            .offset_low = @truncate(handler & 0xFFFF),
            // Kernel code -segmentti GDT:stä.
            .selector = selector,
            // Ei erillistä IST-pinoa vielä.
            .ist = 0,
            // Interrupt gate, present, ring 0.
            .type_attr = type_attr,
            // Keskimmäiset 16 bittiä handler-osoitteesta.
            .offset_mid = @truncate((handler >> 16) & 0xFFFF),
            // Ylimmät 32 bittiä handler-osoitteesta.
            .offset_high = @truncate(handler >> 32),
            // Varattu kenttä nollaksi.
            .zero = 0,
        };
    }
};

// IDTR-rekisteriin ladattava kuvaus (limit + base).
const IdtPointer = packed struct {
    // IDT-taulukon koko tavuina miinus yksi.
    limit: u16,
    // IDT-taulukon virtuaalinen osoite.
    base: u64,
};

// 256 vektorin IDT-taulukko (IRQ 0..255 + CPU poikkeukset).
var idt: [256]IdtEntry = undefined;
// IDTR-kuvaus lidt-komentoa varten.
var idt_ptr: IdtPointer = undefined;

// Heksadesimaalimerkkijono yhden nibble-tulostukseen.
const HEX_DIGITS = "0123456789ABCDEF";

// Tulosta 64-bittinen arvo UART:iin muodossa 0xXXXXXXXXXXXXXXXX.
fn writeHex64(val: u64) void {
    // Etuliite heksadesimaaliosoitteelle.
    uart.write("0x");
    // Käy 16 nibbleä vasemmalta oikealle (MSB ensin).
    var shift: u6 = 60;
    while (true) : (shift -= 4) {
        // Poimi yksi 4-bittinen nibble annetusta siirrosta.
        const nibble: u4 = @truncate(val >> shift);
        // Tulosta vastaava heksamerkki.
        uart.putc(HEX_DIGITS[nibble]);
        // Lopeta kun ollaan viimeisessä nibblessä.
        if (shift == 0) break;
    }
}

// Tulosta page fault -virhekoodin bittien merkitykset UART:iin.
fn writeFaultErrorBits(code: u64) void {
    // Bit 0: sivu ei ollut present (not-present fault vs protection fault).
    if ((code & 1) == 0) uart.write(" not-present");
    // Bit 1: kirjoitus aiheutti virheen (write vs read).
    if ((code & 2) != 0) uart.write(" write");
    // Bit 2: käyttäjätila (CPL=3) aiheutti virheen.
    if ((code & 4) != 0) uart.write(" user");
    // Bit 3: varattu bitti — ei pitäisi olla 1 normaalisti.
    if ((code & 8) != 0) uart.write(" rsvd");
    // Bit 4: instruction fetch (NX / execute-disable).
    if ((code & 16) != 0) uart.write(" ifetch");
}

// Page fault -käsittelijä C-puolella — logittaa CR2 + virhekoodin ja pysäyttää CPU:n.
export fn pageFaultHandlerC(fault_addr: u64, error_code: u64) callconv(.c) noreturn {
    // Tulosta staattinen virheotsikko serialiin.
    log.err("Page fault at");
    // Tulosta virheen virtuaaliosoite (CR2) heksadesimaalimuodossa.
    writeHex64(fault_addr);
    // Rivinvaihto osoitteen jälkeen.
    uart.putc('\n');
    // Tulosta virhekoodin numeerinen arvo.
    uart.write("[ERR] Error code:");
    // Tulosta virhekoodi heksadesimaalimuodossa.
    writeHex64(error_code);
    // Tulosta virhekoodin bittien selitykset.
    writeFaultErrorBits(error_code);
    // Rivinvaihto virhekoodin jälkeen.
    uart.putc('\n');
    // Varmista CR2 vastaa parametria (debug — handler luki CR2 ennen callia).
    _ = paging.getCr2();
    // Poista keskeytykset ja pysäytä CPU — kernel ei vielä käsittele page faultia.
    asm volatile ("cli; hlt");
    // Varoitus: ei koskaan saavuteta — noreturn-silmukka varmuuden vuoksi.
    while (true) {}
}

// Page fault (#14) — naked wrapper lukee CR2 ja virhekoodin pinolta.
export fn pageFaultHandler() callconv(.naked) noreturn {
    // Poista keskeytykset heti — estää uudelleenpage faultin handlerissa.
    // Lue virhekoodi pinosta (CPU pushaa sen ennen handleria).
    // Lue CR2 — page fault -virtuaaliosoite.
    // Kutsu C-käsittelijää: RDI=fault_addr, RSI=error_code (SysV ABI).
    asm volatile (
        \\cli
        \\mov (%%rsp), %%rsi
        \\mov %%cr2, %%rdi
        \\call pageFaultHandlerC
        \\cli
        \\hlt
    );
}

// Yleinen stub muille keskeytyksille — pysäyttää CPU:n odottamaan debuggausta.
export fn isrStub() callconv(.naked) noreturn {
    // Poista keskeytykset ja pysäytä suoritus.
    asm volatile ("cli; hlt");
}

// Timer IRQ C-käsittelijä — EOI + tick-laskuri.
export fn timerIrqHandlerC() callconv(.c) void {
    // Ilmoita PIC:lle että IRQ0 on käsitelty.
    pic.sendEoi(0);
    // Kasvata taustatick-laskuria.
    timer_ticks += 1;
}

// Palauta PIT-tickien määrä.
pub fn timerTicks() u64 {
    return timer_ticks;
}

// Timer IRQ (vektori 32) — tallentaa rekisterit, kutsuu C-käsittelijää, iretq.
pub export fn timerIrqHandler() callconv(.naked) noreturn {
    // Tallenna caller-saved rekisterit ennen C-kutsua.
    asm volatile (
        \\push %%rax
        \\push %%rcx
        \\push %%rdx
        \\push %%rsi
        \\push %%rdi
        \\push %%rbp
        \\push %%r8
        \\push %%r9
        \\push %%r10
        \\push %%r11
        \\call timerIrqHandlerC
        \\pop %%r11
        \\pop %%r10
        \\pop %%r9
        \\pop %%r8
        \\pop %%rbp
        \\pop %%rdi
        \\pop %%rsi
        \\pop %%rdx
        \\pop %%rcx
        \\pop %%rax
        \\iretq
    );
}

// Alusta IDT — page fault #14 oikea käsittelijä, muut stub.
pub fn init() void {
    // Osoite yleiseen stub-handleriin kaikille muille vektoreille.
    const stub_addr: u64 = @intFromPtr(&isrStub);
    // Osoite page fault -handleriin vektoriin #14.
    const pf_addr: u64 = @intFromPtr(&pageFaultHandler);
    // 64-bit interrupt gate, present, DPL 0 (0x8E).
    const attr: u8 = 0x8E;
    // Täytä kaikki 256 IDT-merkintää.
    for (&idt, 0..) |*entry, i| {
        // Vektori 14 = page fault — käytä erikoiskäsittelijää.
        if (i == 14) {
            // Rekisteröi pageFaultHandler vektoriin #14.
            entry.* = IdtEntry.init(pf_addr, gdt.KERNEL_CODE_SEL, attr);
        } else {
            // Kaikki muut vektorit → stub joka pysäyttää CPU:n.
            entry.* = IdtEntry.init(stub_addr, gdt.KERNEL_CODE_SEL, attr);
        }
    }
    // IDT-koko tavuina miinus yksi (x86 vaatimus).
    idt_ptr.limit = @sizeOf(@TypeOf(idt)) - 1;
    // IDT-taulukon virtuaalinen osoite.
    idt_ptr.base = @intFromPtr(&idt);
    // Lataa IDT CPU:hen lidt-komennolla.
    asm volatile ("lidt (%[ptr])"
        :
        : [ptr] "r" (&idt_ptr),
    );
}

// Rekisteröi page fault -käsittelijä erikseen (testattavuus / uudelleenalustus).
pub fn setPageFaultHandler() void {
    // Osoite page fault -handleriin.
    const pf_addr: u64 = @intFromPtr(&pageFaultHandler);
    // Päivitä vain vektori #14.
    idt[14] = IdtEntry.init(pf_addr, gdt.KERNEL_CODE_SEL, 0x8E);
}

// Palauta page fault -virheen virtuaaliosoite (CR2) — ulkoiseen diagnostiikkaan.
pub fn lastFaultAddress() u64 {
    // Lue CR2 suoraan CPU:sta.
    return paging.getCr2();
}

// Rekisteröi yksittäinen IDT-käsittelijä vektorinumeroon (IRQ tai poikkeus).
pub fn registerHandler(vector: usize, handler: u64) void {
    // 64-bit interrupt gate, present, DPL 0.
    idt[vector] = IdtEntry.init(handler, gdt.KERNEL_CODE_SEL, 0x8E);
}
