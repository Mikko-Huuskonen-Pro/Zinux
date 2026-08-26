# Zinux

**Zinux** on käyttöjärjestelmä, joka on kirjoitettu lähes 100 % [Zig](https://ziglang.org/)-kielellä.
Jokainen koodirivi on tarkoituksella ylidokumentoitu — jälkipolvet voivat lukea kernelin
kuin oppikirjan ja ymmärtää *miksi* järjestelmä toimii niin kuin se toimii.

## Visio

| Ominaisuus | Kuvaus |
|------------|--------|
| Kieli | Zig (freestanding, ei `std` kernelissa) |
| Malli | Hybridimikrokernel + capability-pohjainen turvallisuus |
| Boot | [Limine](https://github.com/limine-bootloader/limine) (UEFI/BIOS) |
| Kohde | x86_64-freestanding (moniarkkitehtuuri-valmius) |
| Dokumentointi | `//` jokaisella rivillä — katso [DOCUMENTATION.md](docs/DOCUMENTATION.md) |

## Dokumentaatio

| Tiedosto | Sisältö |
|----------|---------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arkkitehtuuri, muistimalli, IPC, hakemistorakenne |
| [docs/DOCUMENTATION.md](docs/DOCUMENTATION.md) | Ylidokumentointistandardi |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Vaiheittainen kehityssuunnitelma |

## Projektirakenne

```
zinux/
├── kernel/          # Kernel-lähdekoodi (boot, arch, mm, sched, ipc, drivers, lib)
├── libs/            # Jaettu ABI (zinuxabi.zig)
├── tests/           # Host-yksikkötestit + tulevat QEMU-integraatiotestit
├── docs/            # Arkkitehtuuri- ja suunnitteludokumentit
├── build.zig        # Build-järjestelmä
├── linker.ld        # Higher-half kernel -muistikartta
└── limine.conf      # Bootloader-konfiguraatio
```

## Vaatimukset

- [Zig](https://ziglang.org/download/) 0.14.0+ (`.zigversion`)
- QEMU (Vaihe 1+: `zig build run`)
- xorriso + Limine (Vaihe 1+: `zig build iso`)

## Kääntäminen

```bash
# Asenna Zig (esim. 0.14.0)
# curl -L https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz | tar xJ

# Käännä kernel
zig build

# Aja host-yksikkotestit
zig build test
```

## Kehitysvaihe

Projekti on **Vaihe 0** (perusta): arkkitehtuurisuunnitelma, dokumentointistandardi ja
build-runko. Seuraava askel on **Vaihe 1** — bootattava kernel Liminessä joka tulostaa
`Zinux boot OK` serial-porttiin.

Katso [ROADMAP.md](docs/ROADMAP.md) koko tiekartta.

## Lisenssi

MIT — katso [LICENSE](LICENSE).
