# Zinux — Agentin nykyinen vaihe

> Cloud Agent -loop lukee tämän tiedoston jokaisella kierroksella.
> **Älä jumita valmiiseen vaiheeseen** — siirry seuraavaan kun vaihe on ✅ ROADMAPissa.

---

## Nykyinen vaihe: **26** ⬜

**Branch**: `cursor/process-address-space-4d97`  
**PR**: #4 (base: #3 exit/wait)  
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
| 11 Estävä IPC recv | ✅ |
| 12 Capability peruutus | ✅ |
| 13 Non-blocking IPC recv | ✅ |
| 14 IPC jonon syvyys | ✅ |
| 15 Capability oikeuskysely | ✅ |
| 16 Capability tyyppikysely | ✅ |
| 17 IPC jonon tyhjennys | ✅ |
| 18 Capability resurssitunniste | ✅ |
| 19 IPC jonon kapasiteetti | ✅ |
| 20 Prosessitaulukko | ✅ |
| 21 Prosessin luonti (sys_spawn) | ✅ |
| 22 Cross-process IPC | ✅ |
| 23 Prosessilista (sys_ps) | ✅ |
| 24 Prosessin elinkaari (exit/wait) | ✅ |
| 25 Osoiteavaruudet per prosessi | ✅ |

### Tämän kierroksen prioriteetti (Vaihe 26)

**Scheduler + prosessit** — timer-preempt vaihtaa prosessia; useita ring 3 -prosesseja vuorottelee.  
Katso `docs/ROADMAP.md` vaihe 26.

---

## Loop-säännöt

1. Lue `docs/ROADMAP.md` + tämä tiedosto.
2. Toteuta **alin keskeneräinen vaihe** (ei Vaihe 2 uudelleen).
3. Ylidokumentointi: `//` jokaisella rivillä uudessa Zig-koodissa.
4. `zig build test` + `zig build boot-test` ennen committia (`zig build run` = nopea smoke).
5. Kun vaihe valmis ROADMAPissa → päivitä **Nykyinen vaihe** -numero tähän tiedostoon.
6. Commit, push, päivitä PR.
