# Zinux — Agentin nykyinen vaihe

> Cloud Agent -loop lukee tämän tiedoston jokaisella kierroksella.
> **Älä jumita valmiiseen vaiheeseen** — siirry seuraavaan kun vaihe on ✅ ROADMAPissa.

---

## Nykyinen vaihe: **11** (ei vielä ROADMAPissa) ⬜

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
| 6 Ajurit & tiedostojärjestelmä | ✅ |
| 7 Turvallisuus & kovennus | ✅ |
| 8 IPC käyttäjätilaan | ✅ |
| 9 Capability delegointi | ✅ |
| 10 Capability-luonti | ✅ |

### Tämän kierroksen prioriteetti (Vaihe 11)

Katso `docs/ROADMAP.md` — seuraava vaihe määritellään sinne.

---

## Loop-säännöt

1. Lue `docs/ROADMAP.md` + tämä tiedosto.
2. Toteuta **alin keskeneräinen vaihe** (ei Vaihe 2 uudelleen).
3. Ylidokumentointi: `//` jokaisella rivillä uudessa Zig-koodissa.
4. `zig build test` + boot-testi ennen committia.
5. Kun vaihe valmis ROADMAPissa → päivitä **Nykyinen vaihe** -numero tähän tiedostoon.
6. Commit, push, päivitä PR.
