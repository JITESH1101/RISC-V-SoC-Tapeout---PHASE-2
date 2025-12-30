# Task 3: Removal of On-Chip POR and Final GLS Validation (SCL-180)

**Author**: Jitesh Reddy  
**Program**: India RISC-V SoC Tapeout Program  
**Technology Node**: SCL-180 nm  
**Tools Used**: Synopsys VCS, Synopsys DC_TOPO, Custom SCL-180 PDK  

---

## 🚀 Executive Summary & Objective

The primary objective of this task is to **formally remove the on-chip Power-On Reset (POR) logic** from the VSD Caravel-based RISC-V SoC and **validate a single external active-low reset architecture**.

In previous PDK iterations (SKY130), a behavioral `dummy_por` module was utilized to emulate power sequencing. However, for the SCL-180 tapeout, this logic has been excised to align with physical design realities. This repository documents the complete engineering flow—from RTL refactoring to final Gate-Level Simulation (GLS)—proving that:

- ✅ **No internal POR circuitry is required** for this technology node
- ✅ **SCL-180 Reset Pads are asynchronous** and available immediately upon VDD stabilization
- ✅ **The design is cleanly synthesizable** (DC_TOPO) and functionally equivalent (VCS) without internal reset generation

---

## 📋 Table of Contents

1. [Executive Summary & Objective](#-executive-summary--objective)
2. [Context & Engineering Rationale](#-context--engineering-rationale)
3. [Phase-1: Pre-Design Analysis](#-phase-1-pre-design-analysis)
4. [Phase-2: RTL Refactoring Strategy](#️-phase-2-rtl-refactoring-strategy)
5. [Phase-3: DC_TOPO Synthesis Results](#-phase-3-dc_topo-synthesis-results)
6. [Phase-4: Final Gate-Level Simulation (GLS)](#-phase-4-final-gate-level-simulation-gls)
7. [Engineering Deliverables & Justification](#-engineering-deliverables--justification)
8. [Directory Structure](#directory-structure)

---

## 🧠 Context & Engineering Rationale

### Why Remove POR?

The decision to move to an external-only reset strategy is based on three critical technical factors:

#### 1. The "Analog" Reality

True POR circuits are **analog macros** requiring hysteresis and voltage references. Writing a "digital POR" in Verilog (using counters or delays) is functionally incorrect for a real chip and leads to synthesis hazards.

#### 2. Pad Reliability

Detailed analysis of the SCL-180 I/O library confirms that the **input pads do not require internal enable signals or POR-driven gating**. The reset path is transparent from the pin to the core.

#### 3. Architectural Safety

**Board-level reset supervisors are industry standard**. Relying on an explicit external pin eliminates the risk of an on-chip POR releasing reset prematurely before the power rail is stable.

---

## 📊 Phase-1: Pre-Design Analysis

Before modifying the RTL, a comprehensive dependency analysis was conducted. The findings are documented in the following deliverables:

### 📄 POR_Usage_Analysis.md

Traces every instance of `porb_h`, `porb_l`, and `dummy_por` in the legacy `vsdcaravel.v` netlist.

**Contents:**
- Complete module instantiation audit
- Signal fan-out analysis
- Block-by-block reset dependency mapping
- Clear separation between POR-driven and generic reset logic

### 📄 PAD_Reset_Analysis.md

A critical review of SCL-180 pad datasheets, contrasting them with SKY130 requirements.

**Contents:**
- SCL-180 I/O pad datasheet analysis
- Power-up sequencing characterization
- Detailed SCL-180 vs SKY130 comparison
- Risk assessment and board-level mitigation strategies

---

## 🛠️ Phase-2: RTL Refactoring Strategy


First clone the following github repo for the code base 

<img width="1680" height="1050" alt="git_clone" src="https://github.com/user-attachments/assets/c3829d8d-706e-4f66-aaf4-79c6c9198142" />

Now search for every instance in the design where dummy_por and its corresponding signals are used

<img width="1068" height="225" alt="Screenshot from 2025-12-15 10-46-44" src="https://github.com/user-attachments/assets/d7414ab2-0b4d-4e08-9933-ae4be2c34f91" />

<img width="1040" height="765" alt="Screenshot from 2025-12-15 10-47-38" src="https://github.com/user-attachments/assets/4e7cbed3-22cd-4489-b331-5d2415490286" />

<img width="1044" height="400" alt="Screenshot from 2025-12-15 10-48-30" src="https://github.com/user-attachments/assets/9c4e4f22-20cc-4242-94fb-d35450e6cbd9" />

<img width="1053" height="411" alt="Screenshot from 2025-12-15 10-49-18" src="https://github.com/user-attachments/assets/d2703231-bf9b-45ec-a7c4-d52b876cf0f6" />


### Modifications Implemented

The `dummy_por` module, which previously utilized non-synthesizable delays to mimic startup, was completely removed. The top-level `vsdcaravel.v` and housekeeping logic were refactored to accept a single global input: `input reset_n`.

### Legacy Signal Compatibility

To maintain compatibility with the internal SoC hierarchy without rewriting every sub-module, a direct wire-mapping strategy was implemented. Legacy POR signal names are now aliases for the external reset pin.

```verilog
// ---------------------------------------------------------
// POR REMOVAL: DIRECT MAPPING STRATEGY
// ---------------------------------------------------------

input reset_n;  // Single External Active-Low Reset

// Mapping legacy POR names to the external pin
assign porb_h = reset_n;  // Power-on-Reset Bar (High Voltage Domain)
assign porb_l = reset_n;  // Power-on-Reset Bar (Low Voltage Domain)
assign rstb_h = reset_n;  // System Reset Bar

// Inversion for active-high legacy sinks
assign por_l  = ~reset_n; 
```

### RTL Verification (VCS)


Verification was performed to ensure that removing the internal delay logic did not break the reset sequence.

#### Simulation Command

```bash
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
    +incdir+../ +incdir+../../rtl +incdir+../../rtl/scl180_wrapper \
    +incdir+/home/Synopsys/pdk/SCL_PDK_3/SCLPDK_V3.0_KIT/scl180/iopad/cio250/6M1L/verilog/tsl18cio250/zero \
    +define+FUNCTIONAL +define+SIM \
    hkspi_tb.v -o simv

./simv -no_save +define+DUMP_VCD=1 | tee sim_log.txt
```

<img width="1680" height="1050" alt="rtl_make_compile" src="https://github.com/user-attachments/assets/4032fd40-0b6e-433d-966e-79c733ddb874" />

<img width="1680" height="1050" alt="rtl_make_sim" src="https://github.com/user-attachments/assets/62c2681a-c821-4729-b468-d1716081293f" />



#### Results

- **Reset Timing**: The waveform confirms `reset_n` releases at 1000ns exactly as driven by the testbench
- **State Integrity**: Register read/write operations (Reg 0 to 18) function correctly immediately after reset release


<img width="1680" height="1050" alt="rtl_waveform" src="https://github.com/user-attachments/assets/a35b0132-751d-42b8-9c85-3c765ba051e8" />

---

## 🏭 Phase-3: DC_TOPO Synthesis Results

The design was synthesized using Synopsys Design Compiler (DC_TOPO) with the SCL-180 standard cell library. The goal was to prove that removing the POR blackbox results in a clean netlist with no inferred latches.

### Synthesis Execution

```bash
cd synthesis/work_folder
dc_shell -f synth.tcl
```

### Key Design Characteristics

| Metric | Count/Value | Significance |
|--------|-------------|--------------|
| **Total Ports** | 12,749 | I/O Boundary defined |
| **Total Nets** | 37,554 | Connectivity established |
| **Sequential Cells** | 6,882 | 100% reset via `reset_n` |
| **Combinational Cells** | 18,422 | Logic density |
| **Macros / Black Boxes** | 16 | No hidden POR macros |
| **Total Cell Area** | 773,088.68 µm² | Optimized SCL-180 footprint |

### Quality Checks

✅ **No Unresolved References**: All modules bound to SCL-180 cells  
✅ **No Inferred Latches**: Reset removal did not create unintentional storage elements  
✅ **Clean Reset Tree**: Reports confirm `reset_n` drives the set/reset pins of all flops  

<img width="1680" height="1050" alt="synthesis" src="https://github.com/user-attachments/assets/b445022f-efed-43c8-9f5e-76dda9b1c9a1" />


```bash
start_gui
```

- schematic view

<img width="755" height="664" alt="schematic" src="https://github.com/user-attachments/assets/0e918938-5848-46fe-a437-479cfecd8467" />

- padframe

<img width="564" height="663" alt="pad_Frame" src="https://github.com/user-attachments/assets/5b808149-ef56-4f11-9ca5-3cfd52647031" />


- chip_io

<img width="549" height="664" alt="chip_io" src="https://github.com/user-attachments/assets/0f886f88-6666-4452-8bdc-ac7df3f6c030" />


---

## 🧪 Phase-4: Final Gate-Level Simulation (GLS)

### Objective

GLS acts as the **"Final Proof"**. It validates that the synthesized netlist (which now lacks the behavioral POR) functions correctly when the reset is applied externally in a simulation environment using SCL-180 functional models.

### Checklist & Observations

- **Reset Assertion**: The `reset_n` signal is held low during the initialization phase (0 to 1000ns). No X-propagation was observed on output pins.

- **Reset De-assertion**: Upon release, the internal clock tree activates immediately.

- **Functional Equivalence**: The SPI register tests passed, matching the RTL behavior exactly.

<img width="1680" height="1050" alt="gls_output" src="https://github.com/user-attachments/assets/07e3d016-e9b2-4c31-b629-2a99a45e7858" />

<img width="1680" height="1050" alt="gls_sim" src="https://github.com/user-attachments/assets/ff3597cb-3f1f-4976-9a24-1b884115eb0d" />


<img width="1680" height="1050" alt="gls_waveform" src="https://github.com/user-attachments/assets/b10b77e4-1edd-4aab-878a-f1585efca98a" />


---

## 📝 Engineering Deliverables & Justification

Per the task requirements, the following documentation is included to support the design review:

### 📄 POR_Removal_Justification.md

The mandatory **"Final Decision Document"**. It details:

- **Why POR is an analog problem**, not a digital one
- **Why RTL-based POR is unsafe** for tapeout
- **Risks considered** (e.g., Early Reset Release) and **mitigations**
- **Comparison with industry best practices**
- **SCL-180 vs SKY130** architectural differences

### Summary of Key Arguments

#### Why POR Is Fundamentally Analog

True POR circuits require:
- Voltage comparators (not synthesizable)
- Hysteresis and noise immunity (not possible in RTL)
- Independent timing references (cannot be replicated with logic)

#### Why RTL-Based POR Is Unsafe

- ❌ Circular dependency: POR logic needs clock, but clock may not be stable during power-up
- ❌ No hysteresis: Susceptible to VDD noise, causing spurious reset releases
- ❌ Unverifiable timing: Flip-flop delay assumptions are process-dependent and undocumented
- ❌ Synthesis undefined: Tools cannot synthesize power-edge detection

#### Risk Mitigation Strategy

| Risk | Mitigation |
|------|-----------|
| **Early Reset Release** | Board-level reset supervisor with hysteresis |
| **Power-up X-States** | Reset held low during VDD ramp-up |
| **Reset Pin Noise** | Pull-down resistor + RC filter on board |
| **Missing Reset** | Supervisor watchdog timer (standard feature) |

The full working logic flow of the design is as follows 

<img width="962" height="654" alt="Screenshot from 2025-12-16 20-03-56" src="https://github.com/user-attachments/assets/6ff5196b-0053-48f9-953c-f4e619b8bce4" />

---

## 📂 Directory Structure

```
Task_NoPOR_Final_GLS/
│
├── README.md                          # Project Summary (This file)
│
├── docs/                              # Engineering Documentation
│   ├── POR_Usage_Analysis.md          # Phase-1: Dependency mapping
│   ├── PAD_Reset_Analysis.md          # Phase-1: Pad-level analysis
│   └── POR_Removal_Justification.md   # Phase-5: Technical justification
│
├── rtl/                               # Refactored POR-free Verilog source
│   ├── vsdcaravel.v                   # Top-level SoC (POR-free)
│   ├── housekeeping/
│   └── scl180_wrapper/
│
├── synthesis/                         # DC_TOPO work folder, logs, and netlists
│   ├── work_folder/
│   │   ├── synth.tcl                  # Synthesis script
│   │   ├── synth.log                  # DC_TOPO execution log
│   │   ├── synth.ddc                  # Compiled design
│   │   └── reports/
│   │       ├── area_report.txt
│   │       ├── timing_report.txt
│   │       └── power_report.txt
│   └── netlist/
│       ├── vsdcaravel.v               # Synthesized netlist
│       └── vsdcaravel.sdc             # Constraints
│
├── gls/                               # VCS Gate-Level Simulation
│   ├── gls_tb.v                       # GLS testbench
│   ├── gls_sim.log                    # VCS execution log
│   ├── gls_sim.vpd                    # Waveform (VPD format)
│   ├── gls_sim.fsdb                   # Waveform (FSDB format)
│   └── test_results.txt               # Pass/fail summary
│
├── dv/                                # Design Verification
│   ├── hkspi/
│   │   ├── hkspi_tb.v                 # RTL testbench
│   │   ├── hkspi.vcd                  # RTL simulation waveform
│   │   └── sim_log.txt
│   └── [other testbenches]
│
├── waveforms/                         # Visual Evidence
│   ├── rtl_reset_behavior.md          # RTL reset analysis
│   ├── gls_reset_behavior.md          # GLS reset analysis
│   └── screenshots/
│       ├── rtl_sim_reset.png
│       └── gls_sim_reset.png
│
└── evidence/                          # Supporting Documentation
    ├── synthesis_screenshots/
    ├── gls_waveforms/
    └── netlist_proof/
```

---

## ✅ Verification Summary

### RTL Simulation Status: ✅ PASSED
- Reset assertion/de-assertion behavior verified
- All register operations functional
- No timing violations detected

### Synthesis Status: ✅ PASSED
- All modules successfully mapped to SCL-180 cells
- No unresolved references
- Zero `dummy_por` instances in netlist
- No inferred latches

### GLS Status: ✅ PASSED
- Functional equivalence verified with RTL
- Clean reset propagation (no glitches)
- All test vectors passed
- Waveforms show expected behavior

---

## 📚 Quick Reference

| Phase | Deliverable | Status |
|-------|-------------|--------|
| Phase-1 | POR_Usage_Analysis.md | ✅ Complete |
| Phase-1 | PAD_Reset_Analysis.md | ✅ Complete |
| Phase-2 | POR-free RTL | ✅ Verified |
| Phase-3 | DC_TOPO Synthesis | ✅ Clean Netlist |
| Phase-4 | Gate-Level Simulation | ✅ Functional Match |
| Phase-5 | POR_Removal_Justification.md | ✅ Complete |

---

## 🎯 Key Takeaways

1. **POR is Analog**: Attempting to implement POR in digital RTL is fundamentally flawed
2. **SCL-180 Supports External Reset**: Pad analysis confirms no internal POR requirement
3. **Clean Synthesis**: Netlist contains zero POR logic instances
4. **Functional Verification**: GLS proves external reset architecture works correctly
5. **Industry Aligned**: External reset supervision is the standard approach in modern ASICs

---
