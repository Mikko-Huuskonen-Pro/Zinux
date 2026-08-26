# Zinux — Arkkitehtuurisuunnitelma (2026)

> **Zinux** (Zig + Unix-inspiroitu) on käyttöjärjestelmä, joka on kirjoitettu lähes 100 % Zigillä.
> Jokainen rivi on tarkoituksella ylidokumentoitu, jotta jälkipolvet ymmärtävät *miksi* ja *miten*
> järjestelmä toimii — ei vain *mitä* se tekee.

---

## 1. Visio ja periaatteet

| Periaate | Kuvaus |
|----------|--------|
| **Lähes 100 % Zig** | Ei erillisiä `.S`-tiedostoja; inline `asm volatile` vain kun Zig ei riitä (esim. `lgdt`, `iretq`). |
| **Ylidokumentointi** | Jokaisella koodirivillä `//`-kommentti. Katso [DOCUMENTATION.md](./DOCUMENTATION.md). |
| **Selkeys > suorituskyky** | Ensin toimiva, ymmärrettävä koodi; optimointi vasta kun mittaus osoittaa tarpeen. |
| **Freestanding-first** | Ei `std`-kirjastoa kernelissa; oma `zinux`-moduulipuu. |
| **Testattavuus** | QEMU-pohjainen integraatiotestaus CI:ssä; yksikkotestit host-Zigillä missä mahdollista. |
| **Moniarkkitehtuuri-valmius** | x86_64 ensin; rajapinnat abstraktoidaan `arch/`-hakemistossa. |

---

## 2. Kernel-malli: hybridimikrokernel

Zinux käyttää **hybridimikrokernel**-mallia (inspiraatio: seL4, Graphene, Fuchsia):

```
┌─────────────────────────────────────────────────────────────┐
│                        Käyttäjätila                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  shell   │  │   init   │  │  drivers │  │  palvelut│    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       └─────────────┴─────────────┴─────────────┘           │
│                         │ IPC (capability-syscalls)        │
├─────────────────────────┼───────────────────────────────────┤
│                    Kernel-rajapinta (syscall)                │
├─────────────────────────┼───────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Mikrokernel-ydin (kernel core)          │    │
│  │  • prosessit & säikeet    • muistinhallinta (PMM/VMM)│    │
│  │  • aikataulutus           • IPC & capabilityt        │    │
│  │  • keskeytykset           • ajastin                  │    │
│  └─────────────────────────────────────────────────────┘    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ arch/x86_64  │  │   drivers/   │  │   lib/       │       │
│  │ (GDT,IDT,    │  │ (VGA, UART,  │  │ (ring buffer,│       │
│  │  paging,     │  │  keyboard,   │  │  bitmap,     │       │
│  │  context sw) │  │  timer, PCI) │  │  log, fmt)   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Miksi hybridimikrokernel?

- **Turvallisuus**: capability-pohjainen oikeuksienhallinta (ei root/UID-perinteistä mallia).
- **Modulaarisuus**: ajurit voidaan ajaa käyttäjätilassa myöhemmin ilman kernelin uudelleenkääntämistä.
- **Ymmärrettävyys**: selkeä raja kernel ↔ käyttäjätila helpottaa ylidokumentointia.
- **2026-käytäntö**: Limine + freestanding Zig + QEMU-testaus on vakiintunut yhdistelmä.

---

## 3. Teknologiavalinnat

| Komponentti | Valinta | Perustelu |
|-------------|---------|-----------|
| Kieli | Zig 0.14+ | comptime, `@import("builtin")`, sisäänrakennettu cross-compile |
| Bootloader | [Limine](https://github.com/limine-bootloader/limine) | UEFI/BIOS, SMP, framebuffer, higher-half valmiina |
| Kohde | `x86_64-freestanding-none` | Laajin ekosysteemi, QEMU-tuki |
| Linkkeri | LLD (Zigin mukana) | `linker.ld` higher-half-kernelille |
| Emulaattori | QEMU 9.x | CI-integraatiotestit |
| ISO | xorriso + Limine | Bootattava levykuva |
| Versionhallinta | `.zigversion` + `build.zig.zon` | Toistettavat buildit |

---

## 4. Muistimalli

### 4.1 Higher-half kernel

```
Virtuaalinen osoiteavaruus (x86_64):

0xFFFF_FFFF_FFFF_FFFF ┐
                      │  Kernel higher-half ( -2 GiB )
0xFFFF_FFFF_8000_0000 ┤  kernel/.text, .data, .bss
                      │
0xFFFF_8000_0000_0000 ┤  Direct map (fysinen RAM, -128 GiB)
                      │
0x0000_0000_0000_0000 ┴  Käyttäjätila (0 – 128 TiB teoreettinen)
```

- Limine antaa higher-half-offsetin (`HHDM`); kernel linkitetään `0xFFFFFFFF80000000`.
- Identiteettikartoitus poistetaan bootin jälkeen (turvallisuus).

### 4.2 Muistinhallinta

| Kerros | Toteutus | Vaihe |
|--------|----------|-------|
| **PMM** (Physical Memory Manager) | Bitmap-allokaattori, 4 KiB frame | Vaihe 1 |
| **VMM** (Virtual Memory Manager) | 4-tasoinen sivutus (PML4→PDPT→PD→PT) | Vaihe 2 |
| **Heap (kernel)** | Linked-list / slab-allokaattori | Vaihe 2 |
| **Käyttäjätilan heap** | `mmap`-tyylinen syscall | Vaihe 4 |

---

## 5. Prosessi- ja säiemalli

```zig
// Konseptuaalinen rakenne (toteutus kernel/sched/process.zig)

Process {
    pid: u64,
    capabilities: CapabilitySet,
    address_space: PageTable,
    threads: []Thread,
    state: enum { created, ready, running, blocked, zombie },
}

Thread {
    tid: u64,
    context: CpuContext,   // arch-spesifinen rekisteritila
    stack: VirtualRange,
    state: ThreadState,
}
```

- **Aikataulutus**: Round-robin → CFS-inspiroitu myöhemmin.
- **Kontekstinvaihto**: `arch/x86_64/context.zig` — tallentaa GPR, RIP, RSP, RFLAGS, segmentit.
- **SMP**: per-CPU run queue Liminen SMP-infon pohjalta (Vaihe 3).

---

## 6. IPC ja capabilityt

Zinux ei käytä perinteistä Unix-oikeusmallia (root, setuid). Sen sijaan:

```
Prosessi A                    Kernel                     Prosessi B
    │                           │                            │
    │── cap_create(port) ────────►│                            │
    │◄── capability handle ───────│                            │
    │                           │                            │
    │── cap_send(port, msg) ────►│── deliver ────────────────►│
    │                           │                            │
```

| Syscall | Kuvaus |
|---------|--------|
| `sys_cap_create` | Luo capability-objekti (portti, muisti, irq) |
| `sys_cap_delegate` | Anna osa oikeuksista toiselle prosessille |
| `sys_ipc_send` | Lähetä viesti capabilityyn liittyvään porttiin |
| `sys_ipc_recv` | Vastaanota viesti (blokkaa jos tyhjä) |
| `sys_mem_map` | Kartoita muistisivu capabilityn perusteella |

---

## 7. Syscall-rajapinta

- **Mekanismi**: `syscall` / `sysenter` (x86_64) — `arch/x86_64/syscall.zig`
- **Numerointi**: vakio `Syscall` enum — ei magic number -litereita.
- **Parametrit**: System V AMD64 ABI (RDI, RSI, RDX, R10, R8, R9).
- **Paluu**: RAX = tulos tai virhekoodi (`Error` enum).

---

## 8. Ajurimalli

```
drivers/
├── bus/
│   └── pci.zig          // PCI-enumerointi
├── char/
│   ├── uart.zig         // COM1 sarjaportti (debug)
│   └── keyboard.zig     // PS/2-näppäimistö
├── video/
│   ├── vga.zig          // VGA text mode 0xB8000
│   └── framebuffer.zig  // Limine framebuffer
└── timer/
    └── pit.zig          // 8254 PIT → scheduler tick
```

**Periaate**: jokainen ajuri on `Driver` vtable:

```zig
pub const Driver = struct {
    name: []const u8,
    init: fn () Error!void,
    probe: fn () bool,
    shutdown: fn () void,
};
```

Ajurit rekisteröidään bootissa `drivers/registry.zig`:ssä comptime-listana.

---

## 9. Hakemistorakenne

```
zinux/
├── .github/workflows/ci.yml   # QEMU-integraatiotestit
├── .zigversion                # 0.14.0 (tai uudempi)
├── build.zig                  # Build, ISO, QEMU-käynnistys
├── build.zig.zon              # Pakettimanifesti
├── docs/
│   ├── ARCHITECTURE.md        # ← tämä tiedosto
│   ├── DOCUMENTATION.md       # Ylidokumentointistandardi
│   └── ROADMAP.md             # Vaiheittainen kehityssuunnitelma
├── kernel/
│   ├── main.zig               # _start → kmain
│   ├── boot/
│   │   ├── entry.zig          # Limine entry, early init
│   │   └── limine.zig         # Limine request/response -sidonta
│   ├── arch/
│   │   └── x86_64/
│   │       ├── gdt.zig
│   │       ├── idt.zig
│   │       ├── paging.zig
│   │       ├── context.zig
│   │       └── syscall.zig
│   ├── mm/
│   │   ├── pmm.zig
│   │   ├── vmm.zig
│   │   └── heap.zig
│   ├── sched/
│   │   ├── process.zig
│   │   ├── thread.zig
│   │   └── scheduler.zig
│   ├── ipc/
│   │   ├── capability.zig
│   │   └── port.zig
│   ├── drivers/               # Laitteistoajurit
│   ├── syscall/               # Syscall dispatch
│   └── lib/                   # Kernel-apukirjasto (ei std)
│       ├── log.zig
│       ├── fmt.zig
│       └── ring_buffer.zig
├── userland/                  # Tulevaisuus: init, shell, ajurit
├── libs/
│   └── zinuxabi.zig           # Jaettu ABI käyttäjätilan kanssa
├── tests/
│   ├── host/                  # Host-Zig yksikkotestit
│   └── integration/           # QEMU boot -testit
├── tools/
│   └── mkiso.zig              # ISO-rakentaja (build.zig step)
├── linker.ld
├── limine.conf
└── README.md
```

---

## 10. Build-järjestelmä (build.zig)

`build.zig` hoitaa kaiken ilman ulkoisia skriptejä:

| Step | Kuvaus |
|------|--------|
| `zig build` | Käännä kernel.elf |
| `zig build iso` | Luo bootattava ISO (Limine + xorriso) |
| `zig build run` | Käynnistä QEMU:ssa |
| `zig build test` | Host-testit + QEMU-integraatio |
| `zig build docs` | Generoi moduulidokumentaatio |

Freestanding-asetukset:

```zig
const kernel_exe = b.addExecutable(.{
    .name = "zinux-kernel",
    .root_source_file = b.path("kernel/main.zig"),
    .target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    }),
    .optimize = optimize,
});
kernel_exe.setLinkerScript(b.path("linker.ld"));
kernel_exe.root_module.red_zone = false;
kernel_exe.root_module.stack_protector = false;
```

---

## 11. Testausstrategia

```
         ┌─────────────────┐
         │   Host-testit   │  bitmap, fmt, ring_buffer
         │  (zig build test)│  — ajetaan normaalilla std:llä
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  QEMU-testit    │  boot → serial output assert
         │  (CI pipeline)  │  "Zinux boot OK" → pass
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │  GDB + QEMU     │  Manuaalinen debug kehityksessä
         └─────────────────┘
```

---

## 12. Turvallisuus

| Uhkamalli | Vastatoimi |
|-----------|------------|
| Buffer overflow kernelissa | `@memcpy` + `@memset`, ei `std`; compile-time rajat |
| Käyttäjätilan kernel-pääsy | Sivutaulut + ring 3; SMEP/SMAP (Vaihe 3) |
| Oikeuksien eskalointi | Capability-malli; ei globaaleja root-oikeuksia |
| IRQ handler bugit | Minimal handler → scheduler queue; ei allokointia ISR:ssä |

---

## 13. Mitä jää Zigin ulkopuolelle

| Tiedosto | Syy |
|----------|-----|
| `linker.ld` | Linkkerin vaatimus; dokumentoidaan rivi riviltä kommenteilla |
| `limine.conf` | Limine-bootloaderin konfiguraatio |
| `.github/workflows/` | CI YAML (ei suorituskoodia) |

Kaikki assembly on **inline** Zig-tiedostoissa, esim.:

```zig
// Lataa Global Descriptor Table -rekisteriin uusi GDT.
asm volatile ("lgdt %[desc]":
    : [desc] "m" (gdt_descriptor),
);
```

---

## 14. Viitteet

- [OSDev Wiki](https://wiki.osdev.org/)
- [Limine Protocol](https://github.com/limine-bootloader/limine/blob/trunk/PROTOCOL.md)
- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Graphene Kernel](https://github.com/HTRMC/Graphene-Kernel) — Zig hybridimikrokernel
- [seL4 Microkernel](https://sel4.systems/) — capability-malli
