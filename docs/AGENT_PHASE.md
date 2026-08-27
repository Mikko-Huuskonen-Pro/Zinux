# Zinux — Agentin nykyinen vaihe

> Cloud Agent -loop lukee tämän tiedoston jokaisella kierroksella.
> **Älä jumita valmiiseen vaiheeseen** — siirry seuraavaan kun vaihe on ✅ ROADMAPissa.

---

## Nykyinen vaihe: **6** (Ajurit & tiedostojärjestelmä) ⬜

**Branch**: `cursor/zinux-architecture-plan-4d97`  
**PR**: [#1](https://github.com/Mikko-Huuskonen-Pro/Zinux/pull/1)  
**Zig**: 0.16.0

### Valmiit vaiheet (älä tee uudelleen ellei regressio)

| Vaihe | Tila |
|-------|------|
| 0 Perusta | ✅ |
| 1 Boot & tulostus | ✅ |
| 2 Muistinhallinta | ✅ |
| 3 Prosessit & aikataulutus | ✅ |
| 4 Syscalls & IPC | ✅ |
| 5 Käyttäjätila | ✅ |

### Tämän kierroksen prioriteetti (Vaihe 6)

Tee **yksi merkittävä askel** kerrallaan, testaa, commit + push + PR:

1. ~~**6.1** PCI bus scan (`kernel/drivers/bus/pci.zig`)~~ ✅
2. ~~**6.2** VirtIO block -ajuri (`kernel/drivers/block/virtio_blk.zig`)~~ ✅
3. ~~**6.3** VFS-rajapinta (`kernel/fs/vfs.zig`)~~ ✅
4. ~~**6.4** tmpfs (`kernel/fs/tmpfs.zig`)~~ ✅
5. **6.5** Käyttäjätilan ajurimalli (`userland/drivers/`)

---

## Seuraava vaihe kun 6 on ✅: **7** (Turvallisuus & kovennus)

Katso `docs/ROADMAP.md` — aloita kohdasta 7.1.

---

## Loop-säännöt

1. Lue `docs/ROADMAP.md` + tämä tiedosto.
2. Toteuta **alin keskeneräinen vaihe** (ei Vaihe 2 uudelleen).
3. Ylidokumentointi: `//` jokaisella rivillä uudessa Zig-koodissa.
4. `zig build test` + boot-testi ennen committia.
5. Kun vaihe valmis ROADMAPissa → päivitä **Nykyinen vaihe** -numero tähän tiedostoon.
6. Commit, push, päivitä PR.
