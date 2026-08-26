# Zinux — Agentin nykyinen vaihe

> Cloud Agent -loop lukee tämän tiedoston jokaisella kierroksella.
> **Älä jumita valmiiseen vaiheeseen** — siirry seuraavaan kun vaihe on ✅ ROADMAPissa.

---

## Nykyinen vaihe: **4** (Syscalls & IPC) ⬜

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

### Tämän kierroksen prioriteetti (Vaihe 4)

Tee **yksi merkittävä askel** kerrallaan, testaa, commit + push + PR:

1. **4.1** Syscall entry (`kernel/arch/x86_64/syscall.zig`)
2. **4.2** Syscall dispatch -taulu (`kernel/syscall/dispatch.zig`)
3. Kun vaihe valmis → nosta **Nykyinen vaihe** → **5**

---

## Seuraava vaihe kun 4 on ✅: **5** (Käyttäjätila)

Katso `docs/ROADMAP.md` — aloita kohdasta 5.1.

---

## Loop-säännöt

1. Lue `docs/ROADMAP.md` + tämä tiedosto.
2. Toteuta **alin keskeneräinen vaihe** (ei Vaihe 2 uudelleen).
3. Ylidokumentointi: `//` jokaisella rivillä uudessa Zig-koodissa.
4. `zig build test` + boot-testi ennen committia.
5. Kun vaihe valmis ROADMAPissa → päivitä **Nykyinen vaihe** -numero tähän tiedostoon.
6. Commit, push, päivitä PR.
