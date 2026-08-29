---

## Vaihe 32 — Plugin-ekosysteemi ja luottamaton jakelu ⬜

**Tavoite**: Pluginit ovat itsenäisiä artefakteja, joita kuka tahansa voi julkaista ilman kernel-upstreamin hyväksyntää. Luottamus siirtyy tekijästä kernelin rajoihin.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 32.1 | Pluginin allekirjoitus ja reproducible build | `docs/PLUGIN_SIGNING.md` | ⬜ |
| 32.2 | Julkinen plugin-rekisteri (hajautettu manifestien verkko) | `userland/plugin_registry/` | ⬜ |
| 32.3 | Community audit: capability-manifestin tarkistus ja julkaisu | `docs/PLUGIN_AUDIT.md` | ⬜ |
| 32.4 | `zig build plugin-install <url>` — lataa, validoi, auditoi, asentaa | `build.zig` | ⬜ |

**Testi**:
```bash
zig build plugin-install https://example.com/plugins/uptime-1.0.zpg
# Odotettu serial: Plugin manifest OK, Capabilities audited, Plugin installed
```

---

## Vaihe 33 — Itsekorjaavat järjestelmät (Self-Healing) ⬜

**Tavoite**: "Everything is replaceable" tarkoittaa, että järjestelmä korjaa itsensä ilman ihmistä.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 33.1 | Pluginin virheen automaattinen diagnostiikka | `kernel/plugin_diag.zig` | ⬜ |
| 33.2 | Patchin generointi: AI tuottaa korjatun version | `docs/SELF_HEAL.md` | ⬜ |
| 33.3 | Validointiputki: korjattu plugin testataan samassa sandboxissa | `tests/plugin_heal/` | ⬜ |
| 33.4 | Hot-swap: vanha pysäytetään, uusi käynnistetään, tila siirretään IPC:llä | `kernel/plugin_swap.zig` | ⬜ |

**Testi**:
```bash
zig build run
# Odotettu serial: Web plugin crashed, Diagnosis complete, Patch generated,
# Validation OK, Hot-swap complete, Web plugin restored
```

---

## Vaihe 34 — Tehtäväpohjainen koostaminen (The Eeden Phase) ⬜

**Tavoite**: Käyttäjä ei asenna käyttöjärjestelmää. Hän määrittelee tehtävän, ja Zinux koostaa siihen tarvittavan minimiympäristön.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 34.1 | Task Description Language (TDL) | `docs/TDL.md` | ⬜ |
| 34.2 | AI-suunnittelija: valitse, generoi, hylkää pluginit | `userland/composer/` | ⬜ |
| 34.3 | Boot → Compose → Execute: tyhjästä vain tarvittavat komponentit | `kernel/composer.zig` | ⬜ |
| 34.4 | Decompose: tehtävän jälkeen pluginit pysäytetään, resurssit vapautetaan | `kernel/decomposer.zig` | ⬜ |

**Testi**:
```bash
zig build run --task "HTTP server with uptime"
# Odotettu serial:
# [Zinux] Task received: HTTP server with uptime
# [Zinux] Composing system...
# [Zinux] System composed: 4 plugins, 12 capabilities
# [Zinux] Running...
# [Zinux] Task complete
# [Zinux] Decomposing...
# [Zinux] Core only. Ready for next task.
```

---

## Vaihe 35 — Hajautettu Zinux (Federated Capabilities) ⬜

**Tavoite**: Zinux ei ole yksi kone. Se on kykyjen verkko, joka ylittää laitteiden rajat.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 35.1 | Verkon yli kulkeva capability-delegointi | `kernel/net/cap_tunnel.zig` | ⬜ |
| 35.2 | Etäplugin: plugin toimii toisessa koneessa, IPC kuin paikallinen | `userland/remote_ipc/` | ⬜ |
| 35.3 | Pluginin migraatio: suoritus siirtyy koneelta toiselle | `kernel/migrate.zig` | ⬜ |
| 35.4 | Häviävän solmun käsittely: replikointi tai generointi | `kernel/failover.zig` | ⬜ |

**Testi**:
```bash
# Kone A ja B verkossa
zig build run --cluster
# Odotettu serial:
# [Zinux] Node A joined
# [Zinux] Node B joined
# [Zinux] Uptime plugin migrated A → B
# [Zinux] Node A left
# [Zinux] Failover: uptime plugin replicated on B
```

---

## Vaihe 36 — Laitteiston täysi abstrahointi (Hardware as a Service) ⬜

**Tavoite**: Laite ilmoittaa kykynänsä, Zinux generoi väliaikaisen rajapinnan. Ei pysyviä ajureita.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 36.1 | Hardware capability protocol | `docs/HW_CAP_PROTOCOL.md` | ⬜ |
| 36.2 | Lenossa generoitu ajuri tehtävästä ja laitteen kyvystä | `kernel/hw_gen.zig` | ⬜ |
| 36.3 | Ajurin elinkaari: syntyy, toimii, tuhoutuu | `kernel/hw_lifecycle.zig` | ⬜ |
| 36.4 | Ei pysyviä ajuritiedostoja: vain generointikapasiteetti | `docs/NO_DRIVERS.md` | ⬜ |

**Testi**:
```bash
# Tuntematon sensori liitetään
zig build run
# Odotettu serial:
# [Zinux] Unknown device detected
# [Zinux] Capabilities: temperature, humidity
# [Zinux] Generating driver...
# [Zinux] Driver active: temp=23.4C
# [Zinux] Device detached
# [Zinux] Driver destroyed
```

---

## Vaihe 37 — Eeden Gate ⬜

**Tavoite**: Todistaa, että Zinux on perusta, ei päämäärä. Järjestelmä syntyy tehtäväänsä, elää sen mukaan ja sallii itsensä hajota.

| # | Tehtävä | Tiedosto | Tila |
|---|---------|----------|------|
| 37.1 | Eeden-demonstraatio: 30 päivän autonominen elinkaari | `docs/EEDEN_DEMO.md` | ⬜ |
| 37.2 | Mittarit: boot, composition, stability, decommission | `tests/eeden_metrics/` | ⬜ |
| 37.3 | Dokumentaatio: "Zinux is a foundation for building operating systems" | `docs/EEDEN.md` | ⬜ |
| 37.4 | Gate: järjestelmän täytyy pystyä syntymään ja kuolemaan ilman ihmistä | `.github/workflows/eeden_gate.yml` | ⬜ |

**Testi**:
```bash
zig build eeden-gate
# Odotettu serial:
# [Zinux] Boot
# [Zinux] Task received
# [Zinux] Composing...
# [Zinux] Running (30 days simulated)
# [Zinux] Task complete
# [Zinux] Decomposing...
# [Zinux] Core only
# [Zinux] Eeden Gate: PASSED
```

---

> *"Zinux is not a fixed operating system. Zinux is a foundation for building operating systems."*
