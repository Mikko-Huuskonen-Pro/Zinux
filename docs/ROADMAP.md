# Zinux — Kehitystiekartta

> Vaiheittainen suunnitelma tyhjästä bootattavaan hybridimikrokernel-käyttöjärjestelmään.
> Jokainen vaihe tuottaa **testattavan artefaktin** (QEMU boot + serial output).

---

## Vaihe 0 — Perusta ✅ (tämä PR)

| Tehtävä | Tila |
|---------|------|
| Arkkitehtuuridokumentaatio | ✅ |
| Ylidokumentointistandardi | ✅ |
| Projektirakenne & build.zig runko | ✅ |
| Limine + linker.ld konfiguraatio | ✅ |
| Dokumentoitu entry point -esimerkki | ✅ |

**Artefakti**: `zig build` kääntää (kun Zig asennettuna); dokumentaatio luettavissa.

---

## Vaihe 1 — Boot & tulostus (MVP)

**Tavoite**: Kernel boottaa Liminessä, tulostaa "Zinux boot OK" UART/VGA:han.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 1.1 | Limine request/response -sidonta | `kernel/boot/limine.zig` |
| 1.2 | `_start` entry + early stack | `kernel/boot/entry.zig` |
| 1.3 | VGA text mode -ajuri | `kernel/drivers/video/vga.zig` |
| 1.4 | UART COM1 debug -ajuri | `kernel/drivers/char/uart.zig` |
| 1.5 | Log-moduuli (serial + vga) | `kernel/lib/log.zig` |
| 1.6 | ISO-build + QEMU-run step | `build.zig` |
| 1.7 | CI: boot-test "Zinux boot OK" | `.github/workflows/ci.yml` |

**Testi**:
```bash
zig build iso && zig build run
# Odotettu serial: [Zinux] boot OK
```

---

## Vaihe 2 — Muistinhallinta

**Tavoite**: Fyysinen ja virtuaalinen muistinhallinta toimii; kernel heap allokoi.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 2.1 | GDT + TSS | `kernel/arch/x86_64/gdt.zig` |
| 2.2 | IDT + keskeytyskäsittelijät | `kernel/arch/x86_64/idt.zig` |
| 2.3 | 4-tasoinen sivutus | `kernel/arch/x86_64/paging.zig` |
| 2.4 | PMM bitmap-allokaattori | `kernel/mm/pmm.zig` |
| 2.5 | VMM sivukartoitus | `kernel/mm/vmm.zig` |
| 2.6 | Kernel heap (first-fit) | `kernel/mm/heap.zig` |
| 2.7 | Page fault -handler | `kernel/arch/x86_64/idt.zig` |

**Testi**: Allokoi 100 kehystä, kartoita, kirjoita, lue — ei page faultia.

---

## Vaihe 3 — Prosessit & aikataulutus

**Tavoite**: Useita säikeitä, kontekstinvaihto, PIT-ajastin.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 3.1 | CPU-konteksti (save/restore) | `kernel/arch/x86_64/context.zig` |
| 3.2 | Prosessi & säie -rakenteet | `kernel/sched/process.zig`, `thread.zig` |
| 3.3 | Round-robin scheduler | `kernel/sched/scheduler.zig` |
| 3.4 | PIT 8254 -ajastin | `kernel/drivers/timer/pit.zig` |
| 3.5 | Timer IRQ → scheduler tick | `kernel/arch/x86_64/idt.zig` |
| 3.6 | SMP per-CPU init (Limine) | `kernel/boot/smp.zig` |

**Testi**: Kaksi säiettä vuorottelevat tulostusta → `[A][B][A][B]...`

---

## Vaihe 4 — Syscalls & IPC

**Tavoite**: Käyttäjätilan prosessi voi kutsua kerneliä; capability-malli.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 4.1 | Syscall entry (syscall/sysenter) | `kernel/arch/x86_64/syscall.zig` |
| 4.2 | Syscall dispatch -taulu | `kernel/syscall/dispatch.zig` |
| 4.3 | Capability-rakenne | `kernel/ipc/capability.zig` |
| 4.4 | IPC-portit (send/recv) | `kernel/ipc/port.zig` |
| 4.5 | Ring 3 siirtymä | `kernel/arch/x86_64/usermode.zig` |
| 4.6 | Jaettu ABI | `libs/zinuxabi.zig` |

**Testi**: Käyttäjätilan "hello" -binääri kutsuu `sys_write` → serial output.

---

## Vaihe 5 — Käyttäjätila

**Tavoite**: Init-prosessi, shell, peruskomennot.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 5.1 | ELF-loader kernelissä | `kernel/loader/elf.zig` |
| 5.2 | init-prosessi | `userland/init/main.zig` |
| 5.3 | Interaktiivinen shell | `userland/shell/main.zig` |
| 5.4 | PS/2-näppäimistö | `kernel/drivers/char/keyboard.zig` |
| 5.5 | Komennot: help, meminfo, ps | `userland/shell/commands/` |

**Testi**: Boot → shell prompt `zinux> ` → `help` tulostaa komennot.

---

## Vaihe 6 — Ajurit & tiedostojärjestelmä

**Tavoite**: PCI-enumerointi, virtio-blk, yksinkertainen FS.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 6.1 | PCI bus scan | `kernel/drivers/bus/pci.zig` |
| 6.2 | VirtIO block -ajuri | `kernel/drivers/block/virtio_blk.zig` |
| 6.3 | VFS-rajapinta | `kernel/fs/vfs.zig` |
| 6.4 | tmpfs (RAM-pohjainen) | `kernel/fs/tmpfs.zig` |
| 6.5 | Käyttäjätilan ajurimalli | `userland/drivers/` |

---

## Vaihe 7 — Turvallisuus & kovennus

| # | Tehtävä |
|---|---------|
| 7.1 | SMEP/SMAP aktivointi |
| 7.2 | Stack canaries kernelissä |
| 7.3 | KASLR (satunnainen kernel-base) |
| 7.4 | Capability-audit logging |
| 7.5 | Fuzzing: syscall-rajapinta |

---

## Riippuvuudet vaiheiden välillä

```mermaid
graph TD
    V0[Vaihe 0: Perusta] --> V1[Vaihe 1: Boot]
    V1 --> V2[Vaihe 2: Muisti]
    V2 --> V3[Vaihe 3: Scheduler]
    V3 --> V4[Vaihe 4: Syscalls]
    V4 --> V5[Vaihe 5: Shell]
    V5 --> V6[Vaihe 6: FS]
    V6 --> V7[Vaihe 7: Turvallisuus]
```

---

## Mittarit

| Vaihe | LOC (arvio) | Boot-aika | Testit |
|-------|-------------|-----------|--------|
| 0 | ~500 | — | docs review |
| 1 | ~2 000 | <1 s | 1 integration |
| 2 | ~5 000 | <1 s | 5 unit + 2 integration |
| 3 | ~8 000 | <1 s | 10 unit + 3 integration |
| 4 | ~12 000 | <2 s | 15 unit + 5 integration |
| 5 | ~18 000 | <2 s | 20 unit + 8 integration |

*LOC sisältää ylidokumentointikommentit (~40 % koodista).*
