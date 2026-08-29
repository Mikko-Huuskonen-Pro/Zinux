# Zinux: "Everything is Plugin" - Arkkitehtuurianalyysi ja Ehdotukset

> Tämä dokumentti on koottu ulkopuolisen arvioijan näkemyksestä Zinuxin ROADMAP.md (vaiheet 29–31) ja POC.md -dokumentaation pohjalta.
> Tarkoitus: tunnistaa avoimet kysymykset ja ehdottaa konkreettisia ratkaisuja ennen kuin ne kasvavat rakenteellisiksi ongelmiksi.

---

## 1. Yhteenveto arkkitehtuurista

Zinuxin keskeinen oivallus on **kääntää Linux alisteiseksi pluginiksi** sen sijaan, että se olisi perusta tai korvattava kilpailija. Tämä on strategisesti älykäs. ROADMAPin vaiheet 29–31 muodostavat loogisen ketjun:

1. **Vaihe 29**: Määritellään plugin-arkkitehtuuri (ABI, manifest, lifecycle, capability-rajoitukset)
2. **Vaihe 30**: Linux integroidaan "ensimmäisenä järjestelmäpluginina" — hardware service
3. **Vaihe 31**: Paikallinen AI voi generoida uusia plugineja laitteille ilman Core-muutoksia

POC on skaalattu oikein: HP Stream + Web Plugin + Uptime Plugin + IPC. Tämä todistaa idean pienessä mittakaavassa ennen kuin rakennetaan "kaikki".

---

## 2. Tunnistetut riskit ja ratkaisuehdotukset

### 2.1 IPC-suorituskyky ("Everything is Plugin" -viive)

**Ongelma**: Jos kaikki on plugin, kaikki kommunikointi käy capability-IPC:n kautta. Web-serverin täytyy pyytää uptimea toiselta pluginilta viestillä. Tämä on elegantti, mutta latenssi kasvaa verrattuna suoraan funktiokutsuun.

**Ehdotus — Lisätään ROADMAPiin/vaiheeseen 29:**

```markdown
### 29.8 IPC Performance Benchmark
- Määritellään maksimilatenssi pluginien väliselle IPC:lle
- Mitataan: tyhjän viestin round-trip aika (target: < 10 µs QEMU:ssa, < 1 µs hardwaressa)
- Jos latenssi ylittää rajan, sallitaan "fastpath": jaettu muisti capabilityn kautta
```

**Perustelu**: POC vaatii web-serverin kysyvän uptimea IPC:llä. Jos tämä kestää millisekunteja, HTTP-vastaus hidastuu merkittävästi. Fastpath (jaettu sivu capabilityn kautta) säilyttää turvallisuusmallin mutta sallii zero-copy-kommunikaation.

---

### 2.2 Plugin-riippuvuuksien hallinta ja boot-järjestys

**Ongelma**: POC:n Phase 4 määrittelee plugin lifecyclen (discover → validate → load → grant → start → stop → unload), mutta ei käsittele riippuvuuksia. Mitä tapahtuu, jos Web Plugin käynnistyy ennen Uptime Pluginia? Tai jos Linux-plugin vaatii network-pluginin?

**Ehdotus — Lisätään vaiheeseen 29:**

```markdown
### 29.9 Plugin Dependency Resolution
- Manifestiin `depends_on`: lista vaadituista plugineista ja minimiversioista
- Plugin manager ratkaisee DAGin (Directed Acyclic Graph) ennen loadia
- Jos dependency puuttuu: plugin jää tilaan `waiting`, ei `failed`
- Boot-järjestys: Core → dependency-vapaa pluginit → riippuvaiset pluginit
```

**Perustelu**: Ilman tätä POC:n Phase 10 (plugin failure test) on vaikea toteuttaa luotettavasti. Jos uptime-plugin on pysähdyksissä ja web-plugin kaatuu sen puutteeseen, onko kyse bugista vai odotetusta käyttäytymisestä?

---

### 2.3 Linux-pluginin capability-rajojen todellinen toteutus

**Ongelma**: Vaihe 30.5 vaatii "Capability isolation: Linux-plugin ei saa Zinux Corelle kuuluvaa rajoittamatonta pääsyä." Linux on kuitenkin monoliittinen kerneli, joka olettaa hallitsevansa laitteistoa suoraan. Miten Linux toimii "rajoitettuna"?

**Ehdotus — Lisätään vaiheeseen 30:**

```markdown
### 30.8 Linux-pluginin rajoitusten arkkitehtuuri
Koska Linux olettaa suoran laitteisto-ohjauksen, linux-zinux-plugin ei voi olla 
pelkkä käyttäjätilan prosessi. Sen sijaan se toimii seuraavasti:

- **Virtuaalikone-tyyppinen eristys**: Linux-plugin saa oman sivutaulunsa ja 
  MMIO-alueet, mutta Zinux Core hallitsee kaikkia fyysisiä keskeytyksiä ja DMA:ta.
- **Trap-and-emulate**: Linuxin kernel-tilan operaatiot, jotka ylittävät 
  myönnetyn capabilityn, trapataan Zinux Coreen ja joko emuloidaan tai hylätään.
- **Hardware service -rajapinta**: Linux ei puhu suoraan laitteistolle, vaan 
  pyytää Zinux Corelta capability-rajoitettuja resursseja (esim. "anna minulle 
  tämä PCI-laite" → Core antaa vain sen laitteen MMIO-alueen).

Testi: Linux-plugin yrittää kirjoittaa MMIO-osoitteeseen, jota ei ole 
myönnetty → Zinux Core hylkää operaation ja lähettää capability-violationin.
```

**Perustelu**: Ilman tätä Linux-plugin on joko (a) turvaton, koska Linuxilla on rajoittamaton pääsy, tai (b) rikki, koska Linux ei toimi ilman suoraa laitteistopääsyä. "Trap-and-emulate" on sama periaate kuin hypervisoreissa (KVM, Xen), mutta sovellettuna capability-malliin.

---

### 2.4 AI-generoitujen pluginien determinismi ja rollback

**Ongelma**: Vaihe 31.10 mainitsee "Plugin rollback", mutta ei määrittele, milloin rollback tapahtuu. Jos AI-generoitu ajuri toimii 99 % ajasta, mutta aiheuttaa satunnaisen kernel panicin 1 % käynnistyksistä, miten tämä havaitaan?

**Ehdotus — Lisätään vaiheeseen 31:**

```markdown
### 31.11 Determinismi- ja regressiotestaus
- Jokainen AI-generoitu plugin testataan QEMU:ssa vähintään N kertaa 
  (ehdotus: N=100) ennen asennusta
- Testi sisältää: boot, toiminnallisuus, stressi, virheelliset syötteet
- Jos mikään testeistä epäonnistuu → automaattinen rollback, plugin 
  merkitään `rejected`
- Generoidun pluginin lähdekoodi tallennetaan versionhallintaan 
  (reproducibility)

### 31.12 Plugin-sandboxin asteittainen vapautus
- Uusi plugin aloittaa `strict`-tilassa: kaikki epäilyttävät operaatiot 
  trapataan ja logataan
- Jos plugin toimii M tuntia ilman virheitä, se voi siirtyä 
  `trusted`-tilaan (vähemmän trap-overheadia)
- Mikä tahansa virhe palauttaa `strict`-tilaan
```

**Perustelu**: AI-generoidun koodin pääongelma ei ole se, että se on väärin, vaan että se on **epädeterministisesti** väärin. Rollback on hyödyllinen vain, jos virhe havaitaan. Asteittainen vapautus (strict → trusted) vähentää riskiä tuotannossa.

---

### 2.5 POC:n mittauskriteerit

**Ongelma**: POC.md listaa tavoitteet, mutta ei määrittele "hyväksyttävää" suorituskykyä. Mikä on "continuously running"? Onko 1 tztri riittävä? Entä jos HTTP-vastaus kestää 5 sekuntia?

**Ehdotus — Lisätään POC.md Phase 9:**

```markdown
### Performance Acceptance Criteria
- HTTP request → response: < 100 ms paikallisessa verkossa
- Plugin crash → restart: < 5 s (ilman Core-rebootia)
- Uptime IPC query: < 1 ms (pluginilta toiselle)
- Memory overhead per plugin: < 10 MB (HP Streamilla rajallinen RAM)
```

---

## 3. Yhteenveto: Mitä ehdotan konkreettisesti

| Ongelma | Ehdotus | Kohde |
|---------|---------|-------|
| IPC-latenssi | Fastpath + benchmark | ROADMAP 29.8 |
| Riippuvuudet | DAG-resoluutio | ROADMAP 29.9 |
| Linux-eristys | Trap-and-emulate -arkkitehtuuri | ROADMAP 30.8 |
| AI-determinismi | 100x QEMU-testi + strict/trusted -tilat | ROADMAP 31.11–31.12 |
| POC-mittarit | Hyväksyntäkriteerit | POC.md Phase 9 |

Nämä eivät ole arkkitehtuurin vastaisia — ne täydentävät olemassa olevaa suunnitelmaa konkreettisuudella, joka auttaa välttämään myöhempiä umpikujia.

---

## 4. Viimeinen huomio

Zinuxin "Everything is Plugin" -ajattelu on vahvin, kun se on **myös "Everything is Replaceable"**. Linux-plugin on vain ensimmäinen. Jos joku rakentaa paremman network-pluginin, Linux-pluginin network-osa voidaan korvata. Jos AI generoi paremman ajurin, Linux-pluginin vastaava osa voidaan poistaa käytöstä.

Tämä modulaarisuus on Zinuxin todellinen kilpailuetu. Sen säilyttämiseksi on tärkeää, ettei mikään plugin — edes Linux — kasva liian suureksi tai liian integroiduksi Coreen.

---

*Dokumentti laadittu: 2026-08-29*
*Lähteet: Mikko-Huuskonen-Pro/Zinux/docs/ROADMAP.md (vaiheet 29–31), docs/POC.md*
