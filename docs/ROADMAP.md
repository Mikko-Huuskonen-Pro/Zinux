# Zinux — Kehitystiekartta

> Vaiheittainen suunnitelma tyhjästä bootattavaan hybridimikrokernel-käyttöjärjestelmään.
> Jokainen vaihe tuottaa **testattavan artefaktin** (QEMU boot + serial output).

---

## Vaihe 0 — Perusta ✅

| Tehtävä | Tila |
|---------|------|
| Arkkitehtuuridokumentaatio | ✅ |
| Ylidokumentointistandardi | ✅ |
| Projektirakenne & build.zig runko | ✅ |
| Limine + linker.ld konfiguraatio | ✅ |
| Dokumentoitu entry point -esimerkki | ✅ |

---

## Vaihe 1 — Boot & tulostus ✅

**Tavoite**: Kernel boottaa Liminessä, tulostaa "Zinux boot OK" UART/VGA:han.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 1.1 | Limine request/response | `kernel/boot/limine_protocol.zig` | ✅ |
| 1.2 | `_start` entry + early stack | `kernel/boot/entry.zig` | ✅ |
| 1.3 | VGA text mode -ajuri | `kernel/drivers/video/vga.zig` | ✅ |
| 1.4 | UART COM1 debug -ajuri | `kernel/drivers/char/uart.zig` | ✅ |
| 1.5 | Log-moduuli (serial + vga) | `kernel/lib/log.zig` | ✅ |
| 1.6 | ISO-build + QEMU-run step | `build.zig` | ✅ |
| 1.7 | CI: boot-test "Zinux boot OK" | `.github/workflows/ci.yml` | ✅ |

**Testi**:
```bash
zig build iso && zig build run
# Odotettu serial: [Zinux] boot OK
```

---

## Vaihe 2 — Muistinhallinta ✅

**Tavoite**: Fyysinen ja virtuaalinen muistinhallinta toimii; kernel heap allokoi.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 2.1 | GDT + TSS | `kernel/arch/x86_64/gdt.zig` | ✅ GDT (TSS myöhemmin) |
| 2.2 | IDT + keskeytyskäsittelijät | `kernel/arch/x86_64/idt.zig` | ✅ stub + #14 |
| 2.3 | 4-tasoinen sivutus | `kernel/arch/x86_64/paging.zig` | ✅ mapPage + mapPageEnsure |
| 2.4 | PMM bitmap-allokaattori | `kernel/mm/pmm.zig` | ✅ Limine map + host-testit |
| 2.5 | VMM sivukartoitus | `kernel/mm/vmm.zig` | ✅ PMM-sivutaulut + mapNewPageEnsure |
| 2.6 | Kernel heap (first-fit) | `kernel/mm/heap.zig` | ✅ heap_core + VMM-kasvu |
| 2.7 | Page fault -handler | `kernel/arch/x86_64/idt.zig` | ✅ CR2 + error code log |

**Testi**: Allokoi 100 kehystä, kartoita, kirjoita, lue — ei page faultia. ✅

**Boot**:
```bash
zig build run
# Odotettu serial:
# PMM initialized, PMM alloc test OK, VMM initialized, Heap initialized
# Memory map test OK (100 frames), Heap test OK, Zinux boot OK
```

---

## Vaihe 3 — Prosessit & aikataulutus ✅

**Tavoite**: Useita säikeitä, kontekstinvaihto, PIT-ajastin.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 3.1 | CPU-konteksti (save/restore) | `kernel/arch/x86_64/context.zig` | ✅ RSP switch |
| 3.2 | Prosessi & säie -rakenteet | `kernel/sched/thread.zig` | ✅ stub |
| 3.3 | Round-robin scheduler | `kernel/sched/scheduler.zig` | ✅ coop ABAB-demo |
| 3.4 | PIT 8254 -ajastin | `kernel/drivers/timer/pit.zig` | ✅ |
| 3.5 | Timer IRQ → scheduler tick | `kernel/arch/x86_64/idt.zig` | ✅ PIT IRQ + Phase 3 timer ticks OK |
| 3.6 | SMP per-CPU init (Limine) | `kernel/boot/smp.zig` | ✅ CPU-määrä boot-logissa |

**Testi**: Kaksi säiettä vuorottelevat tulostusta → `ABAB...` serialissa ✅

---

## Vaihe 4 — Syscalls & IPC ✅

**Tavoite**: Käyttäjätilan prosessi voi kutsua kerneliä; capability-malli.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 4.1 | Syscall entry (syscall/sysenter) | `kernel/arch/x86_64/syscall.zig` | ✅ STAR/LSTAR/SFMASK + entry.S |
| 4.2 | Syscall dispatch -taulu | `kernel/syscall/dispatch.zig` | ✅ write/exit/getpid + boot-testi |
| 4.3 | Capability-rakenne | `kernel/ipc/capability.zig` | ✅ create/delegate/revoke + boot-testi |
| 4.4 | IPC-portit (send/recv) | `kernel/ipc/port.zig` | ✅ rengasjono + cap send/recv + boot-testi |
| 4.5 | Ring 3 siirtymä | `kernel/arch/x86_64/usermode.zig` | ✅ iretq + SYSCALL hello + test_return |
| 4.6 | Jaettu ABI | `libs/zinuxabi.zig` | ✅ syscall-numerot + virhekoodit |

**Testi**: Ring 3 `sys_write("hello")` → serial + `Usermode test OK` ✅

---

## Vaihe 5 — Käyttäjätila ✅

**Tavoite**: Init-prosessi, shell, peruskomennot.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 5.1 | ELF-loader kernelissä | `kernel/loader/elf.zig` | ✅ parse PT_LOAD + boot "elf" |
| 5.2 | init-prosessi | `userland/init/main.zig` | ✅ ELF load + "init\n" + Init process OK |
| 5.3 | Interaktiivinen shell | `userland/shell/main.zig` | ✅ prompt + help + Shell test OK |
| 5.4 | PS/2-näppäimistö | `kernel/drivers/char/keyboard.zig` | ✅ IRQ1 + Keyboard init/test OK |
| 5.5 | Komennot: help, meminfo, ps | `userland/shell/commands/` | ✅ SYS_meminfo/ps + boot test OK |

**Testi**: Boot → shell prompt `zinux> ` → `help` / `meminfo` / `ps` toimivat.

---

## Vaihe 6 — Ajurit & tiedostojärjestelmä ✅

**Tavoite**: PCI-enumerointi, virtio-blk, yksinkertainen FS.

| # | Tehtävä | Tiedosto |
|---|---------|----------|
| 6.1 | PCI bus scan | `kernel/drivers/bus/pci.zig` | ✅ config scan + PCI scan OK |
| 6.2 | VirtIO block -ajuri | `kernel/drivers/block/virtio_blk.zig` | ✅ PCI common cfg + VirtIO block read OK |
| 6.3 | VFS-rajapinta | `kernel/fs/vfs.zig` | ✅ mount + open/read/close + VFS test OK |
| 6.4 | tmpfs (RAM-pohjainen) | `kernel/fs/tmpfs.zig` | ✅ /tmp/welcome + tmpfs test OK |
| 6.5 | Käyttäjätilan ajurimalli | `userland/drivers/` | ✅ registry + null driver + Userland driver test OK |

---

## Vaihe 7 — Turvallisuus & kovennus ✅

| # | Tehtävä |
|---|---------|
| 7.1 | SMEP/SMAP aktivointi | ✅ CR4 + stac/clac + SMEP/SMAP hardening OK |
| 7.2 | Stack canaries kernelissä | ✅ early/syscall/TSS/thread + Stack canary OK |
| 7.3 | KASLR (satunnainen kernel-base) | ✅ RDTSC+HHDM heap slide + KASLR OK |
| 7.4 | Capability-audit logging | ✅ rengaspuskuri + Capability audit OK |
| 7.5 | Fuzzing: syscall-rajapinta | ✅ LCG fuzz + Syscall fuzz OK |

---

## Vaihe 8 — IPC käyttäjätilaan ✅

**Tavoite**: Ring 3 voi lähettää/vastaanottaa viestejä capability-slottien kautta syscallien avulla.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 8.1 | sys_ipc_send / sys_ipc_recv | `kernel/syscall/dispatch.zig`, `ipc_syscall_core.zig` | ✅ invoke + IPC syscall OK |
| 8.2 | Userland IPC-kirjasto | `userland/lib/ipc.zig` | ✅ ring 3 send/recv + Userland IPC test OK |

**Testi**:
```bash
zig build run
# Odotettu serial: IPC syscall OK, userland ipc OK, Userland IPC test OK
```

---

## Vaihe 9 — Capability delegointi käyttäjätilaan ✅

**Tavoite**: Ring 3 voi delegoida capability-oikeuksia `sys_cap_delegate`-syscallilla.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 9.1 | sys_cap_delegate | `kernel/syscall/dispatch.zig`, `cap_syscall_core.zig` | ✅ invoke + Cap syscall OK |
| 9.2 | Userland cap-kirjasto | `userland/lib/cap.zig` | ✅ ring 3 delegate + Userland cap test OK |

**Testi**:
```bash
zig build run
# Odotettu serial: Cap syscall OK, userland cap OK, Userland cap test OK
```

---

## Vaihe 10 — Capability-luonti käyttäjätilaan ✅

**Tavoite**: Ring 3 voi luoda uusia IPC-portti-capabilityja `sys_cap_create`-syscallilla.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 10.1 | sys_cap_create | `kernel/syscall/dispatch.zig`, `cap_syscall_core.zig` | ✅ invoke + Cap create syscall OK |
| 10.2 | Userland cap.createPort | `userland/lib/cap.zig` | ✅ ring 3 create + Userland cap create test OK |

**Testi**:
```bash
zig build run
# Odotettu serial: Cap create syscall OK, userland cap create OK, Userland cap create test OK
```

---

## Vaihe 11 — Estävä IPC recv ✅

**Tavoite**: `sys_ipc_recv` blokkaa kun portin jono on tyhjä; timer IRQ herättää odottavan recv:n boot-testissä.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 11.1 | Blocking recv + timer-wake | `kernel/syscall/ipc_block_core.zig`, `ipc_block.zig`, `dispatch.zig` | ✅ IPC block OK |
| 11.2 | Userland blocking ipc.recv | `userland/ipc_block_test/`, `ipc_block_userland.zig` | ✅ userland ipc block OK |

**Testi**:
```bash
zig build run
# Odotettu serial: IPC block OK, userland ipc block OK, Userland IPC block test OK
```

---

## Vaihe 12 — Capability peruutus käyttäjätilaan ✅

**Tavoite**: Ring 3 voi peruuttaa capability-slottinsa `sys_cap_revoke`-syscallilla.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 12.1 | sys_cap_revoke | `kernel/syscall/dispatch.zig`, `capability_core.zig` | ✅ invoke + Cap revoke syscall OK |
| 12.2 | Userland cap.revoke | `userland/lib/cap.zig`, `userland/cap_revoke_test/` | ✅ ring 3 revoke + Userland cap revoke test OK |

**Testi**:
```bash
zig build run
# Odotettu serial: Cap revoke syscall OK, userland cap revoke OK, Userland cap revoke test OK
```

---

## Vaihe 13 — Non-blocking IPC recv ✅

**Tavoite**: Ring 3 voi kokeilla viestin vastaanottoa ilman blokkausta `sys_ipc_try_recv`-syscallilla (EAGAIN jos jono tyhjä).

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 13.1 | sys_ipc_try_recv | `kernel/syscall/dispatch.zig`, `ipc_try_recv_syscall.zig` | ✅ invoke + IPC try recv syscall OK |
| 13.2 | Userland ipc.tryRecv | `userland/lib/ipc.zig`, `userland/ipc_try_recv_test/` | ✅ ring 3 tryRecv + Userland IPC try recv test OK |

**Testi**:
```bash
zig build run
# Odotettu serial: IPC try recv syscall OK, userland ipc try recv OK, Userland IPC try recv test OK
```

---

## Vaihe 14 — IPC jonon syvyyskysely ✅

**Tavoite**: Ring 3 voi kysyä capability-slotin portin jonossa olevien viestien määrän `sys_ipc_pending`-syscallilla.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 14.1 | sys_ipc_pending | `kernel/syscall/dispatch.zig`, `port.zig` | ✅ invoke + IPC pending syscall OK |
| 14.2 | Userland ipc.pending | `userland/lib/ipc.zig`, `userland/ipc_pending_test/` | ✅ ring 3 pending + Userland IPC pending test OK |

**Testi**:
```bash
zig build run
# Odotettu serial: IPC pending syscall OK, userland ipc pending OK, Userland IPC pending test OK
```

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
    V7 --> V8[Vaihe 8: IPC userland]
    V8 --> V9[Vaihe 9: Cap delegate]
    V9 --> V10[Vaihe 10: Cap create]
    V10 --> V11[Vaihe 11: Blocking IPC]
    V11 --> V12[Vaihe 12: Cap revoke]
    V12 --> V13[Vaihe 13: Try recv]
    V13 --> V14[Vaihe 14: IPC pending]
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
