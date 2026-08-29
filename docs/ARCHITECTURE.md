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
| Kieli | Zig 0.16+ | comptime, `@import("builtin")`, sisäänrakennettu cross-compile |
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


## 6.5 Plugin Architecture

Zinux is designed as an extensible operating system.

The core principle is:

Everything is a plugin.

A plugin is a replaceable component that extends the capabilities of the system without requiring the Zinux core to be modified.

Plugins are not limited to applications. A plugin may provide hardware support, drivers, filesystems, networking, device services, compatibility layers, or other operating-system functionality.

The goal is to keep the Zinux core small, stable, and trusted while allowing the rest of the system to evolve independently.

### Core and Plugins

The Zinux architecture is divided into a small trusted core and a collection of optional components.
```
                         Zinux
                           │
                    ┌──────┴──────┐
                    │ Zinux Core  │
                    │             │
                    │ memory      │
                    │ processes   │
                    │ IPC         │
                    │ capabilities│
                    │ security    │
                    └──────┬──────┘
                           │
                    Plugin Manager
                           │
          ┌────────────────┼────────────────┐
          │                │                │
     ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
     │ Plugin  │      │ Plugin  │      │ Plugin  │
     │ storage │      │ network │      │ linux-  │
     │         │      │         │      │ zinux   │
     └─────────┘      └─────────┘      └─────────┘
```
The core provides the fundamental mechanisms required by plugins:

* process isolation
* virtual memory
* IPC
* capability-based access control
* resource management
* plugin lifecycle management

Everything that does not need to be part of the trusted core should be implemented as a plugin.

### Capability-Based Plugins

Plugins do not receive unrestricted access to the system.

A plugin declares the resources and capabilities it requires. The Zinux core grants only the permissions that have been approved for that plugin.

For example:
```
Plugin: camera
Requested capabilities:
    device.camera
    dma
    interrupts
Not granted:
    filesystem.write
    network
    microphone
    arbitrary_memory
```
This follows the same security principle used throughout Zinux:

A component should receive the minimum authority required to perform its task.

The plugin system therefore extends the capability model rather than bypassing it.

### Plugin Lifecycle

Plugins have an explicit lifecycle:
```
discover
   │
   ▼
validate
   │
   ▼
load
   │
   ▼
grant capabilities
   │
   ▼
start
   │
   ▼
running
   │
   ▼
stop
   │
   ▼
unload
```
A plugin should be possible to stop, replace, update, or remove without rebuilding the entire operating system whenever its functionality permits it.

Plugin Manifest

Each plugin should provide a manifest describing its identity and requirements.

A future manifest may contain information such as:
```
name
version
ABI version
required capabilities
provided services
dependencies
architecture
integrity information
```
The manifest allows Zinux to determine what a plugin is allowed to do before the plugin is executed.

Plugin Communication

Plugins communicate with the Zinux core and with other plugins through defined interfaces and IPC.

A plugin should not need direct knowledge of the internal implementation of another component.
```
Plugin A
    │
    │ IPC
    ▼
Zinux Core
    │
    │ IPC
    ▼
Plugin B
```
This creates a stable boundary between components.

The exact plugin ABI is intentionally left open until the plugin subsystem is implemented. The initial implementation should keep the ABI as small and stable as possible.

### User-Space First

Whenever possible, plugins should run outside the trusted kernel core.
```
┌───────────────────────────────────────┐
│              User Space               │
│                                       │
│  ┌──────────┐   ┌──────────┐         │
│  │ Plugin A │   │ Plugin B │         │
│  └────┬─────┘   └────┬─────┘         │
│       │              │               │
└───────┼──────────────┼───────────────┘
        │      IPC     │
┌───────┴──────────────┴───────────────┐
│               Zinux Core              │
│                                       │
│      isolation • IPC • capabilities  │
└───────────────────────────────────────┘
```
Hardware or kernel-level functionality that cannot safely operate entirely in user space may require a different mechanism. Such exceptions should remain explicitly isolated and capability-controlled.

### Linux as a Plugin

One of the first major applications of the plugin architecture is linux-zinux.

Linux contains decades of hardware support, drivers, and compatibility knowledge. Zinux should not attempt to recreate all of this functionality from scratch.

Instead, Linux can be integrated as a Zinux component through the plugin architecture.
```
                     Zinux
                       │
                ┌──────▼──────┐
                │ Zinux Core  │
                └──────┬──────┘
                       │
                 Plugin Interface
                       │
                ┌──────▼──────┐
                │ linux-zinux │
                │   plugin    │
                └──────┬──────┘
                       │
                Linux hardware
                   support
```
The linux-zinux project therefore represents an important architectural experiment:

Can decades of Linux hardware support be exposed to Zinux as a replaceable system component?

The answer does not require Zinux to become Linux.

Linux becomes one component that Zinux can use.

### AI-Generated Plugins

The plugin architecture also provides the foundation for Zinux’s AI-driven hardware model.

When previously unsupported hardware is detected, a local AI may eventually be able to create a new plugin instead of modifying the Zinux core.

The intended workflow is:
```
Hardware detected
       │
       ▼
AI analyzes device
       │
       ▼
AI creates a plan
       │
       ▼
Required capabilities identified
       │
       ▼
Plugin generated
       │
       ▼
Build and validation
       │
       ▼
Sandbox testing
       │
       ▼
Capability verification
       │
       ▼
Plugin installed
```
The AI does not receive unrestricted access to the system.

Instead, the AI first creates a plan describing the smallest set of resources required to perform the task. The resulting plugin is then subject to the same isolation and capability rules as every other plugin.

### Evolution Over Time

A Zinux installation is not intended to be a fixed collection of functionality.

New capabilities can be added over time:
```
Zinux Core
    │
    ├── storage plugin
    ├── network plugin
    ├── graphics plugin
    ├── audio plugin
    ├── robotics plugin
    ├── linux-zinux plugin
    └── AI-generated plugins
```
The operating system can therefore evolve by adding, replacing, or removing components rather than requiring every capability to be permanently built into one monolithic system.

The long-term goal is a system where the trusted core changes slowly, while the surrounding plugin ecosystem can evolve continuously.

### Design Principle

The plugin architecture can be summarized in five principles:

1. Keep the core small.
2. Give components only the capabilities they require.
3. Prefer isolated user-space components.
4. Communicate through stable interfaces and IPC.
5. Allow the system to evolve without rebuilding the entire operating system.

Zinux is therefore not intended to be a finished collection of features.

It is intended to be a small, secure foundation on which the operating system can continuously grow.

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
├── .zigversion                # 0.16.0
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
