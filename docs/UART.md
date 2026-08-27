# Zinux UART Driver Experiment

## Purpose

This document defines the first concrete experiment for the Zinux AI-native hardware model.

The purpose is not to build the most complete UART driver possible.

The purpose is to answer a research question:

Can a local AI generate the hardware-specific part of a useful driver from hardware documentation and a task, while the Zinux kernel retains complete control over resources and capabilities?

UART is intentionally chosen because it is simple enough to understand completely, yet contains enough real hardware behavior to expose problems involving registers, state, timing, interrupts and concurrency.

This experiment is expected to guide the architecture of Zinux for the first months of development.

⸻

### 1. The hypothesis 

Traditional operating systems generally treat a driver as a persistent software component.
```
Operating System
        │
        ├── UART driver
        ├── USB driver
        ├── network driver
        ├── camera driver
        └── thousands of others
```
Zinux explores a different model:

Do not necessarily ship every possible driver. Build the hardware-specific logic when a task requires it.

The intended model is:
```
Hardware
    │
    ▼
Hardware description
    │
    ▼
Local AI
    │
    ▼
Driver Plan
    │
    ▼
Kernel Policy
    │
    ▼
Generated hardware logic
    │
    ▼
Validation
    │
    ▼
Capability sandbox
    │
    ▼
Hardware
```
The driver is therefore treated less like a permanent OS component and more like a task-specific artifact.

⸻

### 2. The core principle

The central security principle is:

The AI proposes. The kernel decides.

The AI must never be the authority that determines what resources it can access.

The AI may say:

I need MMIO read at address X.
I need MMIO write at address Y.
I need IRQ Z.

The kernel decides:

GRANTED
GRANTED
DENIED

The AI must operate entirely inside the resulting capability boundary.

This distinction is fundamental.

AI-generated code is not trusted merely because an AI generated it.

⸻

### 3. Plan, Policy and Implementation

Zinux separates three concepts that are often mixed together in traditional driver development.

3.1 Plan

The AI creates a Driver Plan.

The plan describes the resources and operations that the AI believes are necessary to accomplish the task.

Example:

Task:
    Send one byte through UART.
Required:
    MMIO read:  LSR
    MMIO write: THR
    Timer:      none
    IRQ:        none
Not required:
    DMA
    filesystem
    network
    other devices

The plan is a request, not an authority.

⸻

#### 3.2 Policy

The kernel evaluates the plan.

The kernel knows the actual resources available to the driver and applies system policy.

For example:

Requested:
    MMIO read  0x3FD
    MMIO write 0x3F8
    DMA

The kernel may produce:

MMIO read   → allowed
MMIO write  → allowed
DMA         → denied

The generated implementation must operate within these restrictions.

⸻

#### 3.3 Implementation

Only after the plan and capabilities have been established should the AI generate the hardware-specific implementation.

The AI should not need to generate generic driver infrastructure.

Instead:

Zinux framework
    +
AI-generated hardware logic

This is an intentional architectural constraint.

⸻

### 4. The boilerplate hypothesis

One of the lessons from previous driver synthesis research is that not all driver code is equally suitable for synthesis.

Large parts of a conventional driver are repetitive infrastructure:

* resource registration
* lifecycle handling
* capability setup
* IPC
* interrupt registration
* memory management
* error propagation
* driver discovery
* device registration

These should preferably be implemented by Zinux itself.

The AI should concentrate on the part that actually requires understanding the hardware.

Conceptually:
```
Traditional driver
┌──────────────────────────────┐
│ Boilerplate                  │
│                              │
│ registration                 │
│ resources                    │
│ lifecycle                    │
│ IPC                          │
│ capabilities                 │
│ interrupts                   │
│                              │
├──────────────────────────────┤
│ Hardware-specific logic      │
│                              │
│ register semantics           │
│ state transitions            │
│ timing                       │
│ device protocol              │
└──────────────────────────────┘
```
Zinux aims for:
```
Zinux framework
┌──────────────────────────────┐
│ Boilerplate                  │
│ generated/provided by Zinux  │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ AI-generated logic           │
│                              │
│ only what this hardware      │
│ and this task actually need  │
└──────────────────────────────┘
```
The first UART experiment should measure whether this separation is useful.

⸻

### 5. The first task

The first task should deliberately be extremely small:

Send the byte 0x41 through a UART.

The objective is not to implement a complete POSIX-compatible serial driver.

The objective is to prove the smallest complete path:
```
Task
 ↓
Hardware documentation
 ↓
AI
 ↓
Driver Plan
 ↓
Kernel capabilities
 ↓
Generated logic
 ↓
Validation
 ↓
Sandbox
 ↓
UART
```
If this cannot be made reliable for a simple UART, the broader AI-native driver hypothesis needs to be reconsidered before adding complexity.

⸻

### 6. Hardware information

The AI should receive hardware information in a structured but realistic form.

Possible inputs include:

* register map
* register descriptions
* reset values
* bit definitions
* interrupt descriptions
* timing requirements
* state-machine information
* device initialization requirements
* hardware errata
* vendor documentation
* datasheets
* relevant examples

The long-term goal is to investigate whether AI can extract the useful information from ordinary documentation.

The system should therefore not assume that a perfect formal specification already exists.

This is one of the major differences from classical driver synthesis.

⸻

### 7. Do not give the AI unnecessary assumptions

The AI should be encouraged to distinguish between:

Known
Unknown
Required
Assumed
Requested
Forbidden

For example:
```
KNOWN
UART base address:
    0x3F8
THR:
    offset 0x00
LSR:
    offset 0x05
THRE:
    bit 5
UNKNOWN
Current UART state.
IRQ configuration.
REQUIRED
Read LSR.
Write THR.
NOT REQUIRED
DMA.
Network.
Filesystem.
Other MMIO.
```
This is intentional.

A major goal of the experiment is to discover whether the AI can work effectively when it is not allowed to silently invent capabilities or assumptions.

⸻

### 8. Capability model

The first experiment should use the smallest possible capability set.

Potential capabilities:

MMIO_READ
MMIO_WRITE
PORT_READ
PORT_WRITE
IRQ
TIMER
DMA
IPC

The UART experiment should initially require as few of these as possible.

For a simple polling implementation, it may only require:

MMIO_READ
MMIO_WRITE

An interrupt-driven implementation may additionally require:

IRQ

DMA should not be granted merely because the AI asks for it.

This allows an important experiment:

Can the AI adapt its implementation after the kernel rejects an unnecessary capability?

For example:

AI:
    I need DMA.
Kernel:
    DENIED.
AI:
    DMA is unavailable.
    I will use programmed I/O instead.

This interaction is central to the Zinux concept.

⸻

### 9. Validation

Generated code must not immediately receive access to real hardware.

The intended pipeline is:

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
Hardware

Validation should verify at minimum:

* memory access boundaries
* capability usage
* prohibited operations
* resource declarations
* control-flow safety where possible
* ABI compliance
* driver lifecycle requirements

The exact verification mechanism is deliberately left open at this stage.

The experiment should determine what level of validation is practical without recreating the full specification burden of classical formal driver synthesis.

⸻

### 10. Runtime isolation

Even a successfully validated driver should not automatically be trusted with unrestricted system access.

The intended model is:

Kernel
  │
  ├── capability boundary
  │
  └── sandbox
        │
        └── generated driver

The driver should only see the resources explicitly granted to it.

A driver that attempts:

MMIO outside assigned range
DMA without capability
access to another device
access to kernel memory

should fail because the operating system prevents the operation, not because the AI was expected to behave correctly.

⸻

### 11. Counterexamples

One important lesson from synthesis research is the value of counterexamples.

If a plan or implementation fails, Zinux should eventually be able to provide a useful explanation.

Bad:

Driver rejected.

Better:

Driver rejected.
Reason:
    MMIO write outside granted range.
Requested:
    0x3F9
Granted:
    0x3F8
Suggested action:
    revise Driver Plan.

The long-term goal is for the AI to use these failures as feedback.

Conceptually:
'''
AI
 ↓
Plan
 ↓
Kernel
 ↓
REJECTED
 ↓
Counterexample
 ↓
AI revises plan
 ↓
Kernel
 ↓
ACCEPTED
'''
This creates a potentially important difference between traditional synthesis and AI-assisted synthesis.

The AI does not have to solve the entire problem perfectly on its first attempt.

It can iteratively converge under strict system constraints.

⸻

### 12. UART experiment stages

The experiment should grow gradually.

Stage 1 — Polling

Task:

Send 0x41.

Capabilities:

MMIO_READ
MMIO_WRITE

No interrupts.

No DMA.

No concurrency.

Goal:

Generate the smallest functioning UART hardware logic.

⸻

Stage 2 — Initialization

Add:

* UART initialization
* baud-rate configuration
* line configuration
* reset handling

Goal:

Determine whether AI can correctly reason about register dependencies and initialization order.

⸻

Stage 3 — Receive

Add:

receive byte

Goal:

Test device state and status-register reasoning.

⸻

Stage 4 — Interrupts

Add:

IRQ

Goal:

Determine whether generated logic can correctly handle asynchronous device state.

This stage is especially important because concurrency and interrupts were significant difficulties in previous synthesis research.

⸻

Stage 5 — Fault handling

Introduce:

* invalid states
* unexpected device state
* timeout
* rejected capability
* malformed plan

Goal:

Determine whether the AI can recover from explicit system feedback.

⸻

### 13. Fake hardware first

Before real hardware, Zinux should provide a deterministic fake UART.

AI-generated driver
        ↓
Zinux driver interface
        ↓
Fake UART
        ↓
Test oracle

The fake UART should deliberately emulate realistic behavior:

* register semantics
* status changes
* initialization requirements
* invalid operations
* timing where useful
* interrupts in later stages

This makes it possible to run the experiment repeatedly in CI.

The fake device is not a replacement for real hardware.

It is a controlled laboratory.

⸻

### 14. Real hardware

After the fake device works, the same driver model should be tested against real hardware.

The progression should be:

Fake UART
    ↓
QEMU UART
    ↓
Real UART

Only after this should the experiment move toward more complicated devices.

⸻

### 15. What should be measured?

The experiment should not use “it worked once” as its primary success criterion.

Measure at least:

Human specification burden

How much information had to be manually prepared?

Formal specification:
    X lines / concepts
AI input:
    Y lines / concepts

Generated code

Measure:

total generated code
hardware-specific code
boilerplate

Capability surface

Measure:

capabilities requested
capabilities granted
capabilities rejected

A particularly interesting result would be:

requested: 5
granted:    2

while the task still succeeds.

Reliability

Run the same generation/test process repeatedly.

Measure:

successful generations
failed generations
validation failures
runtime failures

Recovery

Measure whether the AI can recover from:

invalid plan
rejected capability
validation error
runtime counterexample

⸻

### 16. The most important comparison

The experiment should ultimately compare two models.

Traditional synthesis
```
Human
 ↓
formal specification
 ↓
synthesis
 ↓
verification
 ↓
driver

Zinux

Human / documentation
 ↓
Local AI
 ↓
Driver Plan
 ↓
Kernel Policy
 ↓
generated implementation
 ↓
validation
 ↓
sandbox
 ↓
driver
```
The key research question is not:

“Can AI write a UART driver?”

AI can obviously write UART code.

The real question is:

Can AI reduce the human specification burden while the kernel preserves a strong security boundary?

That is the experiment.

⸻

### 17. New assumptions being tested

Zinux is deliberately challenging several traditional assumptions.

Assumption 1

A driver must exist before hardware can be used.

Zinux hypothesis:

A useful driver can be generated when required.

⸻

Assumption 2

A driver must be fully specified before it can be synthesized.

Zinux hypothesis:

AI can construct useful plans from less formal hardware documentation.

⸻

Assumption 3

Generated code must be trusted if it is to control hardware.

Zinux hypothesis:

Generated code can remain untrusted while capabilities define its effective authority.

⸻

Assumption 4

A driver must be a large, permanent software component.

Zinux hypothesis:

The hardware-specific portion can be a small task-specific artifact surrounded by deterministic OS infrastructure.

⸻

Assumption 5

Automatic synthesis must solve the entire problem in one step.

Zinux hypothesis:

AI can iterate through:

plan
→ rejection
→ counterexample
→ revised plan
→ implementation

under kernel control.

⸻

### 18. What would count as success?

A successful first experiment does not require a production-quality UART driver.

A meaningful result would be:

A local AI can take ordinary UART hardware documentation and a simple task, produce a valid Driver Plan, operate within kernel-granted capabilities, generate the hardware-specific logic, and successfully execute it against a controlled UART without requiring a complete manually written formal specification.

An even stronger result would be:

The same process works after the kernel rejects unnecessary capabilities and provides counterexamples, allowing the AI to converge on a smaller valid solution.

⸻

### 19. What would count as failure?

The experiment must also be allowed to disprove the hypothesis.

Examples:

* AI requires nearly complete formal specifications anyway.
* AI cannot reliably understand register dependencies.
* Capability boundaries are insufficient to prevent dangerous device states.
* Generated code is too unreliable.
* Validation becomes as complex as writing the driver manually.
* The plan/implementation separation provides no practical advantage.
* Runtime sandboxing introduces unacceptable overhead.
* Interrupt-driven hardware becomes fundamentally unreliable.
* Hardware state cannot be inferred adequately from available documentation.

A negative result is valuable.

The goal is to discover the boundary of the model.

⸻

### 20. Long-term direction

UART is only the laboratory.

If the model works, the same architecture can be tested against increasingly difficult hardware:
```
UART
 ↓
RTC
 ↓
I²C sensor
 ↓
SPI sensor
 ↓
GPIO device
 ↓
CAN device
 ↓
motor controller
 ↓
camera
 ↓
robotic subsystem
```
The final goal is not to create an AI that knows every device.

The goal is to create an operating system where:

The system can construct the smallest hardware interface required for the task at hand, while the kernel remains the authority over what that interface is allowed to do.

⸻

### 21. Guiding principle

The project should continuously return to this:

Traditional operating systems stock drivers.

Zinux builds the capability it needs.

And:

The AI proposes. The kernel decides.