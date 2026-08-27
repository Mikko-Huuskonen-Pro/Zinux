# Zinux — Ylidokumentointistandardi

> **Tavoite**: Jokainen koodirivi selittää itsensä. Jälkipolvi lukee kernelin kuin oppikirjan —
> ei tarvitse arvailla *miksi* rivi on olemassa.

---

## 1. Perussääntö

**Jokaisella suoritettavalla rivillä on `//`-kommentti**, joka vastaa kysymykseen:

> *"Mitä tämä rivi tekee juuri nyt, tässä kontekstissa?"*

```zig
// Määrittele prosessin tilakone: created → ready → running → blocked → zombie.
const ProcessState = enum {
    // Prosessi on luotu mutta ei vielä aikataulutettu scheduler-jonoon.
    created,
    // Prosessi odottaa CPU-aikaa valmiiden jonossa.
    ready,
    // Prosessi suorittaa parhaillaan CPU:lla.
    running,
    // Prosessi odottaa I/O:ta, IPC-viestiä tai ajastinta.
    blocked,
    // Prosessi on päättynyt; resursseja ei ole vielä vapautettu.
    zombie,
};
```

---

## 2. Kommenttitasot

| Taso | Milloin | Esimerkki |
|------|---------|-----------|
| **Rivi** (`//`) | Jokainen koodirivi | `// Kasvata frame-indeksiä yhdellä seuraavaa allokaatiota varten.` |
| **Lohko** | Ennen funktiota/rakennetta | `/// Vapauttaa yhden 4 KiB fyysisen muistikehyksen bitmapista.` |
| **Moduuli** | Tiedoston alussa | `//! Fyysinen muistinhallinta (PMM) — bitmap-pohjainen allokaattori.` |
| **Arkkitehtuuri** | `docs/` | Konseptuaaliset päätökset, kaaviot |

---

## 3. Mitä kommentoidaan

### ✅ Kommentoidaan aina

- Muuttujien alustukset
- Ehtolauseet ja silmukat
- Syscall-käsittely
- Rekisterien luku/kirjoitus (inline asm)
- `@bitCast`, `@intFromPtr`, `@ptrFromInt` — epäselvät muunnokset
- `comptime`-laskenta
- Virheenkäsittely (`try`, `catch`, `errdefer`)

### ✅ Kommentoidaan tarvittaessa

- Importit (jos ei ilmeisiä)
- Tyypit ja enum-variantit
- Julkiset API-funktiot (`///`-docstring + rivikommentit sisällä)

### ❌ Ei tarvitse toistaa

- Itsestäänselvä syntaksi (`}` sulkee lohkon)
- Automaattisesti generoitu koodi
- Kolmannen osapuolen koodi (Limine-header kopioitu sellaisenaan)

---

## 4. Kommenttien tyyli

### Kieli

- **Suomi** kernel-koodissa ja dokumentaatiossa (projektin pääkieli).
- **Englanti** sallittu ABI-nimissä (`ProcessState.running`) ja laitteistotermeissä (`CR3`, `GDT`).

### Muoto

```zig
// [Verbi] [kohde] [tarkennus/tulos].
// Hyvä:
// Aseta PML4-taulun osoite CR3-kontrollirekisteriin aktivoidaksesi sivutuksen.

// Huono:
// CR3 = pml4  (liian lyhyt, ei selitä miksi)
// Tässä asetamme rekisterin joka on tärkeä muistinhallinnassa (liian pitkä, ei konkreettinen)
```

### Inline assembly

```zig
// Lataa uusi Global Descriptor Table CPU:n GDTR-rekisteriin.
// Tämä aktivoi segmenttien uudet base/limit-arvot seuraavalla segmenttiviittauksella.
asm volatile ("lgdt %[desc]":
    : [desc] "m" (gdt_descriptor),
);
```

---

## 5. Esimerkki: täysin dokumentoitu funktio

```zig
//! Fyysinen muistinhallinta — bitmap-allokaattori yhdelle 4 KiB kehykselle.

// Vapauta yksi aiemmin varattu fyysinen muistikehys.
// frame_index on kehyksen järjestysnumero (0 = ensimmäinen 4 KiB RAMista).
pub fn freeFrame(frame_index: usize) void {
    // Laske bitmap-taulukon tavuindeksi jakamalla kehysindeksi kahdeksalla (8 bittiä/tavu).
    const byte_index = frame_index / 8;
    // Laske bittipaikka tavun sisällä ottamalla jakojäännös kahdeksalla.
    const bit_index = frame_index % 8;
    // Aseta vapautettavan kehyksen bitti nollaksi (0 = vapaa, 1 = varattu).
    bitmap[byte_index] &= ~(@as(u8, 1) << @intCast(bit_index));
}
```

---

## 6. Moduuliotsikko (jokaisen `.zig`-tiedoston alku)

```zig
//! # Moduulin nimi
//!
//! **Vastuu**: yksi lause mitä moduuli tekee.
//! **Riippuvuudet**: lista `@import`-moduuleista.
//! **Käytetään**: kuka kutsuu tätä moduulia.
//!
//! ## Arkkitehtuurihuomiot
//! - Keskeiset päätökset ja miksi ne tehtiin näin.
```

---

## 7. linkkeriskripti ja konfiguraatiot

Myös ei-Zig-tiedostot dokumentoidaan rivi riviltä:

```ld
/* linkker.ld — Zinux kernelin muistikartta Limine higher-half -bootille */

/* Määrittele kernelin latausosoite: -2 GiB virtuaalimuistissa (Limine HHDM) */
ENTRY(_start)

/* Kernel alkaa tästä virtuaalisesta osoitteesta linkkauksen jälkeen */
KERNEL_BASE = 0xFFFFFFFF80000000;
```

---

## 8. Tarkistuslista (PR-review)

Ennen mergeä varmista:

- [ ] Jokaisella uudella suoritusrivillä on `//`-kommentti
- [ ] Moduuliotsikko (`//!`) on tiedoston alussa
- [ ] Julkinen API on dokumentoitu (`///`)
- [ ] Inline asm -lohkoissa kommentoidaan jokainen operandi
- [ ] `comptime`-blokit selittävät *miksi* compile-time eikä runtime
- [ ] Ei "TODO ilman issue-numeroa" — jokainen TODO → GitHub issue

---

## 9. Automaattinen tarkistus (tulevaisuus)

```bash
# Tuleva CI-step: varoitus jos rivi ilman kommenttia (ei-blokkaava aluksi)
zig build lint-docs
```

Toteutus: `tools/lint_docs.zig` — AST-kävely, raportoi rivit joilla ei edellisellä rivillä `//`-kommenttia.
