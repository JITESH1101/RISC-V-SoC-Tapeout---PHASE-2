# VSD Caravel Power-On-Reset (POR) Dependency Analysis - Phase-1 Report

**Project**: vsdCaravel / Openframe RISC-V SoC (SCL180 PDK)  
**Analysis Type**: Power-On-Reset Study (Research Phase)   
**Date**: December 15, 2025 

---

## Table of Contents

1. [Introduction](#introduction)
2. [POR Generation and Signals](#por-generation-and-signals)
3. [POR Signal Definitions](#por-signal-definitions)
4. [dummy_por: Source of POR Signals](#dummy_por-source-of-por-signals)
5. [Top-Level POR Routing and Architecture](#top-level-por-routing-and-architecture)
6. [Padframe and IO Safety](#padframe-and-io-safety)
7. [POR Usage in Code](#por-usage-in-code)
8. [Housekeeping Logic and Core Integration](#housekeeping-logic-and-core-integration)
9. [POR Dependency Map](#por-dependency-map)
10. [POR vs Generic Reset](#por-vs-generic-reset)
11. [Key Conclusions](#key-conclusions)
12. [Recommendations](#recommendations)
13. [Phase-1 Status and Next Steps](#phase-1-status-and-next-steps)

---

## Introduction

Power-On Reset (POR) is a critical circuit in digital systems. It ensures that all digital and analog circuits start in a known, safe state immediately after power is applied. 

In the VSD Caravel and Openframe designs, POR is generated in the padframe and then distributed to internal logic and user project interfaces. This report documents the current understanding of POR usage in the design, highlighting:

- Where the dummy POR model is applied
- What signals are involved
- Which blocks actually depend on POR versus generic reset signals
- The architectural separation between power-on initialization and functional resets

All analysis is grounded in actual RTL code with explicit file and line number references from comprehensive grep analysis of the vsdCaravel codebase.

---

## POR Generation and Signals

### 2.1 POR Signals Overview

The following three signals are generated and distributed throughout the design:

| Signal | Domain | Polarity | Description |
|--------|--------|----------|-------------|
| `porb_h` | 3.3 V | Active-low | Primary POR for the high-voltage (3.3 V) padframe domain |
| `porb_l` | 1.8 V | Active-low | Level-shifted POR for the low-voltage (1.8 V) core domain |
| `por_l` | 1.8 V | Active-high | Inverted POR (derived from porb_l) for alternate logic usage |

**Generation Source**: These signals are generated in `dummy_por.v` (behavioral model for simulation) and distributed throughout the design hierarchy.

**Key Files Referenced**:
- `dummy_por.v:27-29` - Signal declarations
- `caravel_core.v:60-61` - POR outputs
- `vsdcaravel.v:175-177` - POR distribution

### 2.2 Signal Relationships

```verilog
// From dummy_por.v (lines 80, 83)
assign porb_l = porb_h;  // Direct assignment (level shift in padframe)
assign por_l  = ~porb_l;  // Inverted version for flexibility
```

### 2.3 Power-On vs Power-Off States

| State | `porb_h` | `porb_l` | `por_l` | System Status |
|-------|----------|----------|---------|--------------|
| Power off / Ramping | 0 | 0 | 1 | **POR ACTIVE** - All logic in safe state |
| Power stable | 1 | 1 | 0 | **POR RELEASED** - System operational |

### 2.4 POR vs Reset

| Signal Type | Use Case | Triggered By | Typical Behavior |
|-------------|----------|--------------|-----------------|
| **POR** (`porb_h`, `porb_l`, `por_l`) | Initialize pad and GPIO states; guarantee known startup values; enable internal clocks safely | Power supply rise | Hardware-enforced, cannot be overridden by software |
| **Reset** (`rstb_h`, `rstb_l`) | User-triggered reset; can restart logic without cycling power; drives standard resettable flip-flops | External reset pad or software command | Software-visible and controllable |

**Key Observation**: POR is **padframe-initiated** and ensures electrical safety during power ramp. Reset signals are **independent** and derived from the external reset pad, used for functional logic restart.

---

## POR Signal Definitions

### Signal Purpose and Usage

**`porb_h` (3.3V Active-Low POR)**

- **Domain**: 3.3V padframe supply
- **Primary Function**: Control GPIO pad enables during power-up
- **Safety Purpose**: Prevents digital outputs from floating or glitching when the supply is ramping
- **Consumer Blocks**: All I/O pad macros, GPIO buffers, pad output enable circuits
- **RTL Reference**: `chip_io.v:116` - `assign mprj_io_enh = {MPRJ_IO_PADS{porb_h}};`

**`porb_l` (1.8V Active-Low POR)**

- **Domain**: 1.8V core supply (level-shifted from `porb_h`)
- **Primary Function**: Control core logic initialization and housekeeping blocks
- **Safety Purpose**: Ensures internal logic starts in known state before software execution
- **Consumer Blocks**: Housekeeping SPI, GPIO configuration loader, core registers
- **RTL Reference**: `caravel_core.v:528,591` - Housekeeping async reset connections

**`por_l` (1.8V Active-High POR - Inverted)**

- **Domain**: 1.8V core supply
- **Primary Function**: Provide inverted polarity for synchronization and alternative logic styles
- **Safety Purpose**: Flexibility in clock domain crossing and reset distribution
- **Consumer Blocks**: Core clocking, reset distribution networks
- **RTL Reference**: `caravel_core.v:61` - `output por_l`

---

## dummy_por: Source of POR Signals

### 3.1 Purpose and Role

`dummy_por` is a **behavioral stand-in** for the real analog POR circuit. It includes:

- **Soft-start RC charging**: ~15ms in production, 500ns in simulation
- **Schmitt trigger hysteresis**: Two stages for noise immunity
- **Voltage-dependent release**: Monitors power supply status

**Important**: In production, this will be replaced with an actual analog POR circuit. The behavioral model is essential for simulation verification.

### 3.2 RTL Location and Instantiation

**Files**: `dummy_por.v`, `gl/dummy_por.v`

**Key Lines**:
- Line 27: `output porb_h,` - Primary 3.3V POR output
- Line 28: `output porb_l,` - Level-shifted 1.8V POR output
- Line 29: `output por_l` - Inverted POR output
- Line 76: `.X(porb_h)` - Schmitt trigger #2 output
- Line 80: `assign porb_l = porb_h;` - Direct assignment (padframe shifter)
- Line 83: `assign por_l = ~porb_l;` - Inversion

**Inclusion**: `dummy_por` is included in:
- Behavioral simulations via `caravel_netlist.v`
- Not directly instantiated in `vsdcaravel.v` (sourced from `caravel_core`)

### 3.3 POR Generation Mechanism

```
Step 1: Power supply rises
        vddio (3.3V) and vccd (1.8V) ramping up
        │
Step 2: Soft-start capacitor charges (via RC network)
        Delay: ~15ms production, 500ns simulation
        │
Step 3: Capacitor voltage crosses Schmitt trigger threshold
        First Schmitt trigger transitions
        │
Step 4: Intermediate signal propagates
        First stage output → Second stage input
        │
Step 5: Second Schmitt trigger outputs porb_h
        Primary 3.3V POR signal released
        │
Step 6: Derived signals generated
        porb_l = porb_h (logically, physically level-shifted)
        por_l = ~porb_l (inverted for flexibility)
        │
Step 7: All three POR signals propagate to design
        ✓ POR RELEASED - System operational
```

### 3.4 Why dummy_por Exists

| Reason | Explanation |
|--------|-------------|
| **Analog modeling** | True POR circuit is analog; not synthesizable to RTL |
| **Simulation safety** | Prevents spurious I/O enables during power ramp-up |
| **Deterministic boot** | Guarantees POR release sequence and timing |
| **Verification enablement** | Allows functional verification before physical implementation |

---

## Top-Level POR Routing and Architecture

### 4.1 Signal Declaration and Routing

**File**: `vsdcaravel.v`  
**Lines**: 175-177 (declarations), 254, 312 (connections)

```verilog
// Signal declarations
wire porb_h;
wire porb_l;
wire por_l;

// Connections in module instantiations
chip_io (
    .porb_h(porb_h),      // Receives 3.3V POR from pad ring
    .por(por_l),          // Provides inverted POR
    ...
);

caravel_core (
    .porb_h(porb_h),      // Receives 3.3V POR
    .porb_l(porb_l),      // Receives 1.8V POR
    .por_l(por_l),        // Receives inverted POR
    ...
);
```

### 4.2 Architectural Role

**vsdcaravel.v is a distribution layer, not a logic consumer:**

- It **receives** POR signals from `caravel_core` or pad interface
- It **routes** them to both core and padframe
- It **does not transform or generate** POR signals
- No functional logic depends directly on POR at this level

### 4.3 Design Hierarchy

```
dummy_por (generation in caravel_core)
    ↓
caravel_core (export: porb_h, porb_l, por_l)
    ↓
vsdcaravel (distribution layer)
    ↓
├─→ chip_io (padframe interface)
│   └─→ pads, mprj_io (user pad enables)
│
├─→ caravel_openframe (openframe wrapper)
│   └─→ __openframe_project_wrapper (user project interface)
│
└─→ mgmt_core (pass-through)
    └─→ porb_h_out, por_l_out (transparent pass-through)
```

---

## Padframe and IO Safety

### 5.1 Core POR Responsibility: Pad Enable Control

POR's **primary critical function** is to safely control I/O pad enables during power ramp-up.

**Files and Lines with grep verification**:
- `chip_io.v`: Lines 64, 112, 116, 1122, 1199 - Pad enable assignment and pass-through
- `mprj_io.v`: Lines 40, 86, 117 - User I/O pad macro connections
- `pads.v`: Lines 87, 89, 130, 132, 163, 165, 205, 207 - Individual pad enable signals

### 5.2 Pad Enable Formula

**File**: `chip_io.v`  
**Line**: 116

```verilog
assign mprj_io_enh = {`MPRJ_IO_PADS{porb_h}};
```

**Meaning**: All 38 user I/O pad enables are directly driven by `porb_h`:
- When `porb_h = 0` (POR active): All pads DISABLED
- When `porb_h = 1` (POR released): Pads ENABLED and under control logic

### 5.3 Pad Macro Enable Connections

**File**: `pads.v` (multiple instances)

```verilog
.ENABLE_H(porb_h)        // Hard enable in 3.3V pad
.ENABLE_VDDA_H(porb_h)   // Analog pad power enable
```

**File**: `mprj_io.v`

```verilog
input porb_h;
...
.ENABLE_VDDA_H(porb_h),
```

### 5.4 Why This Cannot Be Replaced by Functional Reset

🚨 **Critical Safety Finding**: Pad enable is a **hardware power-domain control**, not a software-resettable signal.

**Prevents**:
- **Back-powering** through I/O drivers when supplies are off - Avoids latch-up and signal distortion
- **I/O contention** during power ramp-up - Prevents simultaneous drive conflicts
- **Leakage current** through disabled pad drivers - Minimizes power loss and heat

**Electrical Impact**: 
- If pads remain enabled during power ramp-up, floating inputs can cause oscillations
- Cross-coupled latches in pad ESD structures could latch up
- Analog pads could be damaged by half-powered states

**Conclusion**: POR in the padframe is **essential for electrical safety** and **cannot be replaced** by functional reset or software control.

---

## POR Usage in Code

### 6.1 openframe_project_wrapper.v

**File**: `__openframe_project_wrapper.v`  
**Lines**: 51-53 (inputs), 120-122 (pass-through)

```verilog
// POR inputs to user project wrapper
input   porb_h,     // 3.3V POR
input   porb_l,     // 1.8V POR
input   por_l,      // Inverted POR

// Connections to user logic
.porb_h(porb_h),
.porb_l(porb_l),
.por_l(por_l),
```

**Observations**:
- POR signals are inputs to the wrapper
- They are not modified or generated inside the wrapper
- They are fanned out to user project logic, including GPIO and analog I/O controls
- GPIO pads depend on POR for safe initialization
- User logic may optionally use POR signals

### 6.2 caravel_openframe.v

**File**: `caravel_openframe.v`  
**Lines**: 130-132 (declarations), 193-195, 241-243 (connections)

```verilog
// POR signal declarations
wire porb_h;
wire porb_l;
wire por_l;

// POR connections
.porb_h(porb_h),
.porb_l(porb_l),
.por_l(por_l),
```

**Confirms**:
- POR is generated in `chip_io_openframe` and exported to user project wrapper
- Internal GPIO control wires depend on POR for initialization
- POR signals gate GPIO initialization, but do not reset internal flip-flops
- Reset signals are derived from resetb pad and separate from POR

### 6.3 mgmt_core.v Pass-Through

**File**: `mgmt_core.v`  
**Lines**: 83-86 (por_l), 1828-1829 (pass-through)

```verilog
// POR signals simply passed through
input  wire porb_h_in;
output wire porb_h_out;
assign porb_h_out = porb_h_in;

input  wire por_l_in;
output wire por_l_out;
assign por_l_out = por_l_in;
```

**Key Finding**: Management core **propagates POR transparently** with no transformation, confirming POR is a **global invariant** throughout the design.

---

## Housekeeping Logic and Core Integration

### 7.1 Housekeeping as POR-Dependent Block

**File**: `housekeeping.v` (full SPI and pad configuration control)  
**Reference**: `caravel_core.v:528, 591` - POR connection lines

```verilog
// caravel_core.v connections
.porb(porb_l),  // Direct POR to housekeeping modules
```

**Critical Finding**: Housekeeping uses **POR only** (not functional reset) for initialization and safety-critical operations.

### 7.2 Housekeeping Reset Pattern

Housekeeping follows an asynchronous reset pattern:

```verilog
// Typical async reset pattern (inferred from usage)
always @(posedge clk or negedge porb_l) begin
    if (porb_l == 1'b0) begin
        // Initialize registers to safe defaults
        // Reset state machines to IDLE
        // Clear configuration memory
        // Disable all outputs
    end
end
```

### 7.3 Housekeeping-Controlled Systems

| System | POR Dependency | Why |
|--------|---|---|
| **SPI Interface** | ✅ YES | Must process configuration commands only after POR release |
| **Flash Interface** | ✅ YES | Flash must not be accessed until supplies are stable |
| **GPIO Configuration** | ✅ YES | GPIO defaults must be loaded after POR release |
| **Clock/PLL Control** | ✅ YES | PLL and clock mux must not glitch during power ramp |
| **Pad Defaults** | ✅ YES | Output drivers must be in safe state (disabled/tri-state) |

### 7.4 Why POR-Only Design for Housekeeping

**Housekeeping must guarantee safe defaults** regardless of CPU or software state:

- **Before CPU reset is released**: Housekeeping controls pad safety
- **Before software is alive**: Housekeeping initializes all defaults
- **During power ramp**: Housekeeping prevents flash corruption and clock glitches

**Risk if functional reset were used instead**:
- Software bug or stuck CPU could corrupt flash (uncontrolled SPI access)
- Disable critical clocks (halting entire system)
- Leave pads in unsafe states (floating outputs, leakage)

**Design Philosophy**: **Separation of concerns** - POR (hardware safety) vs Reset (software control)

---

## POR Dependency Map

### 8.1 Complete Dependency Chain

```
         ┌─────────────────────────────────────┐
         │   Power Supply Rise (vddio, vccd)   │
         └────────────────┬────────────────────┘
                          │
              ┌───────────▼──────────┐
              │   dummy_por.v        │
              │ (Soft-start + Schmitt)
              └───────────┬──────────┘
                          │
            ┌─────────────┼─────────────┐
            │             │             │
        ┌───▼──┐      ┌───▼──┐     ┌───▼──┐
        │porb_h│      │porb_l│     │por_l │
        │(3.3V)│      │(1.8V)│     │(1.8V)│
        │Act-L │      │Act-L │     │Act-H │
        └───┬──┘      └───┬──┘     └───┬──┘
            │             │             │
        ┌───▼─────────────┼─────────────▼────┐
        │  chip_io        │                   │
        │  Padframe       │   caravel_core    │
        │  Pad ENABLE     │   POR Generation  │
        │  Gating         │   & Distribution  │
        └────────┬────────┼───────────────────┘
                 │        │
             ┌───▼────┐   │ porb_l / por_l
             │ pads / │   │
             │mprj_io │   │
             │(38)    │   │
             └────────┘   │
                          ├─→ Housekeeping (SPI, GPIO config)
                          ├─→ Clock/PLL Control
                          ├─→ Core Registers
                          └─→ Openframe Wrapper
```

### 8.2 Signal Flow Summary

1. **POR generated** in `dummy_por` via soft-start + Schmitt triggers
2. **Propagates outward** through `caravel_core` → `vsdcaravel`
3. **Into padframe** (`chip_io` → `mprj_io`, `pads`) for pad enable gating (critical safety)
4. **Into housekeeping** for safe initialization before software
5. **Into management core** for boot defaults
6. **Into openframe wrapper** for user project hierarchy

---

## POR vs Generic Reset

### 9.1 Complete Dependency Matrix

| Block | `porb_h`/`porb_l`/`por_l` | `rstb` (functional) | Reason |
|-------|---|---|---|
| **dummy_por** | ✅ Generated | ❌ N/A | Power sensing circuit |
| **pads / mprj_io** | ✅ ENABLE gating | ❌ Not used | Electrical safety - pad power domain |
| **chip_io** | ✅ Pad enable control | ❌ Not used | Hardware power domain gating |
| **housekeeping** | ✅ Register init | ❌ Not used | Always-on safety logic (before software) |
| **mgmt_core** (init) | ✅ Safe defaults | ❌ Not used | Boot-time power domain initialization |
| **mgmt_core** (CPU) | ✅ Power domain | ✅ CPU reset | Boot sequence + software control |
| **user project** | ❌ Not used | ✅ Functional reset | User logic functional restart only |
| **openframe_wrapper** | ✅ Exposed | ⚠️ Optional | User may wire POR or reset independently |

### 9.2 Key Distinctions

**POR-hard (cannot be replaced by functional reset):**
- Pad enable/disable control
- Housekeeping initialization
- Hardware power domain control
- Flash safety mechanisms

**POR-optional (can use functional reset if needed):**
- Management core CPU operation
- Some internal state machine resets

**Reset-only (no POR dependency):**
- User project logic (functional restart)
- Software-controlled resets

---

## Key Conclusions

### 10.1 POR is a Power-Validity Invariant, Not a User-Controllable Reset

- **Generated automatically** based on power supply status
- **Cannot be overridden** by software or reset signals
- **Represents a hardware invariant**: "All power supplies are stable and within nominal range"
- **Enforced by hardware**, not by logic design

### 10.2 Padframe and IO Logic Are POR-Hard-Dependent

- Pad enable/disable is **directly gated by `porb_h`** (line `chip_io.v:116`)
- All 38 user pads automatically disabled when `porb_h = 0`
- This is **electrical safety**, not functional reset
- Cannot be replaced or worked around by software-controlled reset

### 10.3 Housekeeping Cannot Function Without POR

- Uses `porb_l` as its **primary and only reset source** (lines `caravel_core.v:528, 591`)
- Initializes all safety-critical functions on POR release
- Must operate **before software is alive** or any functional reset occurs
- Prevents flash corruption and clock glitches during power ramp

### 10.4 dummy_por Is Essential Simulation Infrastructure

- Behavioral model in `dummy_por.v:27-29, 76, 80, 83`
- Not part of production RTL (will be replaced by analog circuit)
- Essential for behavioral and gate-level simulation
- Enables verification of power-up sequences without physical hardware

### 10.5 Functional Reset (rstb/resetb) Is Intentionally Separate from POR

- **Separation of concerns**: POR (hardware safety) vs Reset (software control)
- Prevents **firmware bugs from compromising electrical safety**
- Allows **CPU restart without affecting pad or flash safety**
- Enables independent software control of internal logic

### 10.6 Three-Signal POR Enables Flexible Design

| Signal | Domain | Role | Use Case |
|--------|--------|------|----------|
| `porb_h` | 3.3V | Pad domain safety | GPIO and analog pad enable control |
| `porb_l` | 1.8V | Core initialization | Housekeeping and boot defaults |
| `por_l` | 1.8V inverted | Synchronization flexibility | Clock domain crossing, alternate logic styles |

This **flexibility minimizes circuit complexity** while **maintaining safety guarantees** across both high-voltage and low-voltage domains.

---
