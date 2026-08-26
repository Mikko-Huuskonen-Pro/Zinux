# Zinux — Agentin nykyinen vaihe

> Cloud Agent -loop lukee tämän tiedoston jokaisella kierroksella.
> **Älä jumita valmiiseen vaiheeseen** — siirry seuraavaan kun vaihe on ✅ ROADMAPissa.

---

## Nykyinen vaihe: **3** (Prosessit & aikataulutus) 🚧

**Branch**: `cursor/zinux-architecture-plan-4d97`  
**PR**: [#1](https://github.com/Mikko-Huuskonen-Pro/Zinux/pull/1)  
**Zig**: 0.16.0

### Valmiit vaiheet (älä tee uudelleen ellei regressio)

| Vaihe | Tila |
|-------|------|
| 0 Perusta | ✅ |
| 1 Boot & tulostus | ✅ |
| 2 Muistinhallinta | ✅ |

### Tämän kierroksen prioriteetti (Vaihe 3)

Tee **yksi merkittävä askel** kerrallaan, testaa, commit + push + PR:

1. **3.5** Timer IRQ → scheduler tick (idle näkee tickit; `Phase 3 timer ticks OK` serialissa)
2. **3.6** SMP per-CPU init (`kernel/boot/smp.zig`, Limine)
3. Vaihe 3 valmis → merkitse ROADMAP ✅ ja **nosta alla oleva numero 4:ksi**

### Vaihe 3 valmis kun

- Coop ABAB-demo toimii (✅)
- Timer tick -laskuri näkyy idle-silmukassa tai boot-logissa
- SMP stub boottaa (vähintään yksi CPU logitettu)

---

## Seuraava vaihe kun 3 on ✅: **4** (Syscalls & IPC)

Katso `docs/ROADMAP.md` — aloita kohdasta 4.1.

---

## Loop-säännöt

1. Lue `docs/ROADMAP.md` + tämä tiedosto.
2. Toteuta **alin keskeneräinen vaihe** (ei aina Vaihe 2).
3. Ylidokumentointi: `//` jokaisella rivillä uudessa Zig-koodissa.
4. `zig build test` + boot-testi ennen committia.
5. Kun vaihe valmis ROADMAPissa → päivitä **Nykyinen vaihe** -numero tähän tiedostoon.
6. Commit, push, päivitä PR.
