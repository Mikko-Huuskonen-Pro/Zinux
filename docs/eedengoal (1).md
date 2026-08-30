# Eeden Goal — AI Agent Implementation Checklist

> This document translates the Eeden vision and ROADMAP phases 31.5–37 into concrete coding tasks. Every task is measurable: either it is done, or it is not.

---

## Agent Operating Principles

1. **Implement one phase at a time**. Do not start phase N+1 until phase N's boot test is green.
2. **Every phase has a boot test**. No test = not done.
3. **Userland first**. If something can be done in ring 3, it is done in ring 3.
4. **Capability constraints are absolute**. No new code may bypass capability checks.
5. **Document as you go**. Every module gets a `.md` file in the `docs/` folder.

---

## Phase 31.5 — Plugin Snapshots and Recovery

**Goal**: A user can restore a broken plugin to a previous state in milliseconds.

| # | Task | File | Acceptance Criteria |
|---|------|------|---------------------|
| 31.5.1 | Define snapshot structure (memory + capabilities + IPC + registers) | `kernel/snapshot.zig` | Structure serializes and deserializes bit-perfectly |
| 31.5.2 | Implement `sys_plugin_checkpoint(slot)` | `kernel/syscall/snapshot_syscall.zig` | Ring 3 can call checkpoint → snapshot is saved |
| 31.5.3 | Implement `sys_plugin_restore(slot, snapshot_id)` | `kernel/syscall/restore_syscall.zig` | Restore brings back memory, capabilities, IPC queues, and registers |
| 31.5.4 | Incremental diff memory | `kernel/snapshot_delta.zig` | Only changed pages are saved → snapshot size < 10% of full |
| 31.5.5 | Watchdog: automatic recovery after crash | `kernel/plugin_watchdog.zig` | Plugin crashes → watchdog detects within 100 ms → restores from last snapshot |
| 31.5.6 | Host tests for snapshots | `tests/host/snapshot_test.zig` | 100 serialization/deserialization tests pass |
| 31.5.7 | Boot test: checkpoint → crash → restore | `tests/boot/snapshot_boot.zig` | During boot, a plugin crashes intentionally → restores → prints "Snapshot restore OK" |

**Dependencies**: Requires phases 20–24 (process table, spawn, exit/wait).

---

## Phase 32 — Plugin Ecosystem and Trustless Distribution

**Goal**: Anyone can publish a plugin without kernel-upstream approval. Trust is based on signature and capability audit.

| # | Task | File | Acceptance Criteria |
|---|------|------|---------------------|
| 32.1 | Define plugin package format (`.zpg` = Zinux Plugin) | `docs/ZPG_FORMAT.md` | Format contains: manifest, ELF, signature, capability list |
| 32.2 | Ed25519 signature for plugin packages | `kernel/plugin_sign.zig` | Only signed packages install; signature verification takes < 1 ms |
| 32.3 | Reproducible build support | `docs/REPRODUCIBLE_BUILD.md` | Same source → same hash → same signature |
| 32.4 | Decentralized plugin registry (local manifest database) | `userland/plugin_registry/registry.zig` | Registry lists installed plugins and their capabilities |
| 32.5 | Capability audit: check manifest vs. granted rights | `userland/plugin_registry/audit.zig` | If manifest requests "network" but audits "filesystem" → reject |
| 32.6 | `zig build plugin-install <url>` | `build.zig` | Command downloads, verifies signature, audits capabilities, installs to registry |
| 32.7 | Boot test: load a third-party plugin | `tests/boot/plugin_ecosystem_boot.zig` | During boot, a test plugin is loaded from URL → audited → started → "Plugin ecosystem OK" |

**Dependencies**: Requires phase 31.5 (snapshots are a security feature, but not strictly required for this phase).

---

## Phase 33 — Self-Healing Systems

**Goal**: Plugin crashes → system diagnoses, generates a fix, validates, and hot-swaps.

| # | Task | File | Acceptance Criteria |
|---|------|------|---------------------|
| 33.1 | Crash log collection and analysis | `kernel/plugin_diag.zig` | After crash, kernel writes: PID, RIP, capability violation, last IPC |
| 33.2 | Local AI diagnosis (LLM API or rule-based) | `userland/self_heal/diagnose.zig` | Crash log yields probable cause (e.g., "null pointer dereference at MMIO read") |
| 33.3 | Patch generation | `userland/self_heal/patch.zig` | AI produces corrected source code; patch is < 100 lines |
| 33.4 | Validation pipeline for patched plugin | `userland/self_heal/validate.zig` | Patched plugin is compiled, tested 10× in QEMU, capabilities audited |
| 33.5 | Hot-swap: old out, new in, state transferred | `kernel/plugin_swap.zig` | Swap takes < 100 ms; IPC messages do not disappear |
| 33.6 | Boot test: intentional crash and repair | `tests/boot/self_heal_boot.zig` | Plugin crashes → diagnosed → patched → swapped → "Self-heal OK" |

**Dependencies**: Requires phases 31.5 (snapshots) and 32 (plugin ecosystem).

---

## Phase 34 — Task-Based Composition (The Eeden Phase)

**Goal**: User defines a task → Zinux composes a minimal environment → executes → tears down.

| # | Task | File | Acceptance Criteria |
|---|------|------|---------------------|
| 34.1 | Task Description Language (TDL) specification | `docs/TDL.md` | TDL is a JSON/YAML-like description: `{ "task": "web-server", "requirements": ["http", "uptime"] }` |
| 34.2 | TDL parser | `userland/composer/tdl.zig` | Parser accepts valid TDL, rejects invalid |
| 34.3 | Plugin resolver: TDL → list of plugins | `userland/composer/resolve.zig` | "web-server" → `[core, net, web, uptime]`; missing ones flagged |
| 34.4 | AI generator for missing plugins | `userland/composer/generate.zig` | If plugin missing, AI generates a minimal version from TDL |
| 34.5 | Composer: boot → load plugins → grant capabilities → start | `kernel/composer.zig` | Composer starts plugins in correct order (DAG) |
| 34.6 | Decomposer: stop → free memory → release capabilities | `kernel/decomposer.zig` | Decomposer frees all resources; no memory leaks |
| 34.7 | Boot test: TDL → compose → run → tear down | `tests/boot/composer_boot.zig` | `zig build run --task "uptime"` → composes → shows uptime → tears down → "Composer OK" |

**Dependencies**: Requires phases 29 (plugin architecture), 32 (ecosystem), and 33 (self-heal).

---

## Phase 35 — Federated Zinux (Federated Capabilities)

**Goal**: Zinux systems form a network where capabilities travel across machines.

| # | Task | File | Acceptance Criteria |
|---|------|------|---------------------|
| 35.1 | Encrypted and authorized capability delegation over network | `kernel/net/cap_tunnel.zig` | Capability delegation over network uses AES-GCM + Ed25519 |
| 35.2 | Remote IPC: message looks local | `userland/remote_ipc/remote.zig` | `ipc.send(remote_port)` works like local; latency < 5 ms on LAN |
| 35.3 | Plugin migration from machine to machine | `kernel/migrate.zig` | Snapshot is serialized → sent over network → restored on another machine |
| 35.4 | Failed node detection and replication | `kernel/failover.zig` | If node does not respond for 3 s → marked dead → critical plugins replicated |
| 35.5 | Boot test: two QEMU instances, migration | `tests/boot/federated_boot.zig` | Two instances → plugin migrated A→B → A shut down → B continues → "Federated OK" |

**Dependencies**: Requires phase 34 (composer) and a network stack (not yet in roadmap; must be implemented before this phase).

---

## Phase 36 — Full Hardware Abstraction (Hardware as a Service)

**Goal**: Device announces its capabilities; Zinux generates a driver on the fly. No permanent drivers.

| # | Task | File | Acceptance Criteria |
|---|------|------|---------------------|
| 36.1 | Hardware Capability Protocol (HCP) | `docs/HW_CAP_PROTOCOL.md` | Device announces capabilities (e.g., `{ "type": "sensor", "capabilities": ["temperature", "humidity"] }`) |
| 36.2 | HCP probing from PCI/USB | `kernel/drivers/hcp_probe.zig` | Unknown device detected → HCP message read |
| 36.3 | Driver generation from device capability and task | `kernel/hw_gen.zig` | AI produces a Zig driver: HCP + TDL → minimal driver |
| 36.4 | Generated driver lifecycle: born → works → destroyed | `kernel/hw_lifecycle.zig` | Device detached → driver destroyed automatically; no leftovers |
| 36.5 | Boot test: unknown device → driver → read → detach | `tests/boot/hw_abstract_boot.zig` | QEMU-simulated unknown device → generate driver → read value → detach → driver gone → "HW abstract OK" |

**Dependencies**: Requires phase 31 (AI-generated plugins) and 34 (TDL).

---

## Phase 37 — Eeden Gate

**Goal**: Prove that Zinux is a foundation, not a destination. The system is born, lives, and allows itself to die.

| # | Task | File | Acceptance Criteria |
|---|------|------|---------------------|
| 37.1 | 30-day autonomous demo | `docs/EEDEN_DEMO.md` | HP Stream boots → receives TDL → composes → serves → tears down → repeats for 30 days |
| 37.2 | Metrics: boot, composition, stability, decommission | `tests/eeden_metrics/metrics.zig` | Metrics for every phase: time, memory, plugin count |
| 37.3 | Documentation: "Zinux is a foundation for building operating systems" | `docs/EEDEN.md` | Document explains the vision and proves it is achievable |
| 37.4 | CI gate: `zig build eeden-gate` | `.github/workflows/eeden_gate.yml` | GitHub Actions runs the full Eeden cycle on every PR |
| 37.5 | Boot test: full cycle from scratch | `tests/boot/eeden_gate_boot.zig` | Boot → compose → run 1 min → decompose → core only → "Eeden Gate: PASSED" |

**Dependencies**: Requires ALL previous phases (31.5–36).

---

## Agent Work Order

```
Phase 31.5 ──→ Phase 32 ──→ Phase 33 ──→ Phase 34 ──→ Phase 35 ──→ Phase 36 ──→ Phase 37
(snapshots)    (ecosystem)   (self-heal)   (composer)   (network)    (hardware)   (gate)
     │              │             │             │            │            │           │
     └──────────────┴─────────────┴─────────────┴────────────┴────────────┴───────────┘
                              For every phase:
                              1. Implement kernel code
                              2. Implement userland code
                              3. Write host tests
                              4. Write boot test
                              5. Write documentation
                              6. Ensure CI is green
```

---

## Universal Rules for Every Phase

- **Do not touch Zinux Core** without a specific reason. Core stays small.
- **Use existing IPC**. Do not invent a new communication mechanism.
- **Capabilities are always explicit**. A plugin gets only what its manifest says.
- **Every new syscall goes into `zinuxabi.zig`** and `dispatch.zig`.
- **Every new module is documented** in the `docs/` folder.
- **Every boot test prints** `[Zinux] <Phase> OK` at the end.

---

*"Do not ship everything that might be needed. Construct the smallest environment required for the task."*
