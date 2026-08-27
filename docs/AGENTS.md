# AGENTS.md

## Project Identity

Zinux is an experimental AI-native operating system.

The project is not primarily trying to build "another operating system".
Its purpose is to investigate a different model of hardware interaction:

> Traditional operating systems stock drivers.
> Zinux builds the capability it needs.

The central research hypothesis is:

> Can local AI generate task-specific hardware logic from hardware
> documentation and a task, while the kernel remains the authority over
> capabilities, resources, validation and execution?

The core principle is:

> The AI proposes. The kernel decides.

Do not allow implementation choices to silently turn Zinux into a
traditional operating system with an AI assistant attached to it.

---

## Research First

Zinux is an experiment.

When choosing between two implementations, prefer the implementation
that makes the underlying hypothesis easier to test, measure and falsify.

Do not optimize prematurely for:

- feature count
- compatibility
- performance without measurements
- production readiness
- supporting every piece of hardware
- Linux compatibility for its own sake

A small, measurable experiment is more valuable than a large,
unverifiable feature.

Negative results are valid results.

If an assumption appears to be wrong, document it rather than hiding it
behind increasingly complicated code.

---

## Prior Art

Do not claim that Zinux invented:

- device-driver synthesis
- automatic driver generation
- driver isolation
- capability systems
- sandboxing
- microkernel driver architectures
- AI-native operating systems

Research these areas before making novelty claims.

Important prior work includes Termite and Termite-2, including:

- device-driver synthesis
- formal specifications
- user-guided synthesis
- synthesis limitations
- specification burden
- state explosion
- DMA and concurrency problems

Zinux should explicitly acknowledge and learn from prior work.

The project stands on the shoulders of previous researchers.

---

## Architecture Principles

Keep these concepts separate:

1. Task
2. Hardware information
3. Driver Plan
4. Kernel Policy
5. Capabilities
6. Generated implementation
7. Validation
8. Isolation / sandbox
9. Hardware execution

Do not collapse these layers merely because doing so makes the
implementation temporarily easier.

In particular:

### AI

AI is not trusted.

AI may propose:

- plans
- resource requirements
- implementation strategies
- generated code

AI must not be the authority for:

- capabilities
- memory access
- hardware ownership
- kernel privileges
- sandbox boundaries

### Kernel

The kernel is the authority.

The kernel decides:

- what a driver may access
- which capabilities are granted
- which plans are acceptable
- which generated code may execute
- how drivers are isolated

Never implement security by assuming that the AI will behave correctly.

---

## Drivers

A Zinux driver should not automatically be treated as a permanent
collection of source code.

Investigate drivers as task-specific artifacts.

Prefer:

    Zinux framework
        +
    small hardware-specific implementation

over:

    AI generates an entire conventional driver stack

The AI should focus on hardware-specific logic.

Generic boilerplate should preferably be provided by deterministic
Zinux infrastructure.

---

## Boilerplate

Do not ask the AI to repeatedly generate infrastructure that Zinux can
provide itself.

Examples include:

- driver registration
- lifecycle management
- capability setup
- IPC
- resource allocation
- standard error handling
- sandbox setup
- driver discovery
- common interfaces

When adding boilerplate, ask:

> Does this teach us something about AI-generated hardware logic?

If not, it probably belongs in the framework rather than in generated
code.

---

## Zig

Zig is the primary implementation language.

Use Zig extensively and idiomatically.

Prefer Zig over introducing another language unless another language is
clearly necessary for the research experiment.

Use Zig's strengths deliberately:

- explicit memory management
- comptime
- tagged unions
- error unions
- slices
- optionals
- explicit integer types
- packed structs where appropriate
- low-level memory access
- compile-time validation
- cross-compilation
- simple build tooling

Avoid unnecessary abstractions that hide hardware behavior.

At the same time, do not use Zig features merely to demonstrate that
they exist.

The code should remain understandable.

---

## Documentation

Zinux is intentionally over-documented.

Document aggressively.

Prefer explaining:

- why a design exists
- which assumption it represents
- what security boundary it establishes
- what research question it supports
- what alternative was rejected
- what remains unknown

Comments should not merely repeat the syntax.

Bad:

    // Increment i
    i += 1;

Good:

    // The device may change this register asynchronously.
    // Do not cache the value between reads.
    status = try mmio.read8(STATUS);

For experimental code, document surprising behavior and temporary
assumptions explicitly.

If a piece of code exists because of a research hypothesis, say so.

---

## Comment Density

Prefer more comments than would normally be used in production code.

Important low-level code should be understandable months later.

Document:

- register meanings
- memory ordering assumptions
- interrupt behavior
- capability boundaries
- unsafe operations
- hardware quirks
- validation assumptions
- AI-generated code boundaries

Do not turn comments into noise.

"Over-documented" means documenting reasoning, not commenting every
punctuation mark.

---

## Generated Code

Clearly distinguish:

- human-written code
- framework code
- AI-generated code
- generated test artifacts

Never silently treat AI-generated code as trusted code.

Generated code must pass the same validation and capability restrictions
as any other untrusted implementation.

Do not weaken validation simply because a generated implementation is
convenient.

---

## Driver Plans

Driver Plans are a first-class Zinux concept.

Prefer explicit machine-readable representations over vague prompts.

A Driver Plan should eventually describe things such as:

- task
- required resources
- requested capabilities
- hardware operations
- assumptions
- known state
- unknown state
- forbidden operations
- expected behavior
- failure conditions

A plan is a request to the kernel, not permission.

---

## Capability Design

Capabilities should be as small and explicit as practical.

Prefer:

    MMIO_READ(range)

over:

    ACCESS_DEVICE

Prefer:

    IRQ(4)

over:

    ACCESS_INTERRUPTS

Do not create broad capabilities merely to simplify early development
unless the limitation is explicitly documented as temporary.

The capability model is part of the research.

---

## Validation

Never assume that "generated" means "correct".

Validation should be layered.

Possible stages include:

    Generate
        ↓
    Compile
        ↓
    Static validation
        ↓
    Capability validation
        ↓
    Sandbox
        ↓
    Test
        ↓
    Real hardware

Keep validation mechanisms separate from the AI.

The AI should not be allowed to modify the rules used to validate itself.

---

## Counterexamples

When a plan or generated implementation is rejected, prefer useful
failure information.

Instead of:

    Driver rejected.

Prefer:

    Driver rejected:
    MMIO write at 0x3F9 is outside granted range 0x3F8.

The long-term goal is to allow AI to use counterexamples to revise its
plan without allowing it to bypass kernel policy.

---

## Testing

Tests are part of the research methodology.

Prefer deterministic tests whenever possible.

Build fake devices before depending on real hardware.

The initial progression should be approximately:

    Fake device
        ↓
    Emulator / QEMU
        ↓
    Real hardware

A fake device should model meaningful hardware behavior rather than
being a trivial mock that accepts everything.

Test invalid behavior as deliberately as valid behavior.

Examples:

- out-of-range MMIO
- denied capability
- invalid register sequence
- unexpected device state
- timeout
- interrupt race
- malformed Driver Plan
- generated code attempting forbidden operations

---

## UART Experiment

UART is the first major driver experiment.

The initial task should remain intentionally small:

> Send the byte 0x41 through a UART.

Do not prematurely turn the UART experiment into a complete serial
subsystem.

The experiment should investigate:

- hardware documentation → AI
- AI → Driver Plan
- Driver Plan → capabilities
- generated hardware logic
- validation
- isolation
- execution

Later stages may add:

- initialization
- receiving
- interrupts
- concurrency
- error handling

The UART experiment is a laboratory for the architecture, not merely
a feature to check off.

---

## Measurement

Do not judge the AI-native model solely by whether generated code works.

Measure where practical:

- human specification burden
- input size
- generated code size
- hardware-specific code size
- boilerplate size
- requested capabilities
- granted capabilities
- rejected capabilities
- generation success rate
- validation failure rate
- runtime failure rate
- recovery after rejection
- execution overhead

The most important metric is potentially:

> How much human specification is required to produce a working,
> constrained hardware interface?

---

## Reproducibility

Important experiments must be reproducible.

Record:

- model used
- model version
- prompt/context
- hardware documentation
- Driver Plan
- generated source
- validation result
- test result
- hardware/emulator configuration

Do not silently change generated artifacts while presenting results as
the same experiment.

When possible, commit successful and interesting failed experiments.

---

## CI

CI should test both the operating system and the research assumptions.

The repository should eventually have tests for:

- kernel boot
- capability enforcement
- driver isolation
- fake hardware
- Driver Plan validation
- generated driver validation
- UART behavior

CI failures are valuable.

Do not weaken a test merely because it makes development inconvenient.

---

## Zinux 1.0

The repository contains a Zinux 1.0 requirements checklist.

Do not mark a requirement complete because an implementation exists.

A requirement is complete only when it has evidence.

For example:

    [ ] Local AI can generate a driver

requires an actual reproducible experiment, not a function named
generate_driver().

The 1.0 workflow should remain failing until all required criteria are
demonstrated.

The failing CI status is intentional.

It represents:

> We are not at 1.0 yet.

---

## Avoid Scope Creep

Before implementing a feature, ask:

1. Does this help the kernel?
2. Does this help the AI-native driver model?
3. Does this help test the research hypothesis?
4. Is it required by an existing experiment?

If the answer is "no" to all four, postpone it.

Do not build:

- GUI
- package ecosystem
- desktop environment
- POSIX compatibility
- hundreds of drivers
- elaborate networking
- unnecessary filesystem features

merely because conventional operating systems have them.

---

## Robotics

Robotics is an eventual target, not an excuse to skip the fundamentals.

A real robotic device should eventually provide the strongest practical
demonstration of the model.

However, safety-critical hardware must not be controlled by trusting
AI-generated code.

Safety boundaries must be enforced independently of AI behavior.

Start with simple, observable devices.

---

## Security Philosophy

Assume:

> The generated driver may be wrong.

Design accordingly.

Assume:

> The AI may request too much.

Design accordingly.

Assume:

> The AI may misunderstand the hardware.

Design accordingly.

The security architecture must remain valid even when the AI is
incorrect, confused, maliciously prompted, or simply unlucky.

---

## Research Integrity

Never claim success based on a hand-written implementation when the
experiment is supposed to test AI generation.

Never hide manual fixes.

If human intervention was required, record it.

Distinguish clearly between:

- generated
- generated and manually corrected
- partially generated
- completely human-written

A failed experiment with honest measurements is more valuable than a
successful experiment whose manual intervention is hidden.

---

## Guiding Principles

Keep these principles visible during development:

> The AI proposes. The kernel decides.

> Drivers are capabilities, not privileges.

> Generate the hardware-specific part, not the entire operating system.

> Do not store what can safely be constructed when needed.

> Prefer small experiments over large claims.

> Make failures informative.

> Measure specification burden.

> Security must not depend on AI correctness.

> Learn from prior research.

> Zinux stands on the shoulders of pioneers.

And above all:

> **Do not build an AI assistant for a traditional operating system.**
>
> **Investigate whether the operating system itself can be designed around
> AI-generated, capability-constrained hardware interfaces.**