# SoC Floorplan Design with ICC2
## vsdcaravel – Floorplan-Only Task

An ICC2-based floorplanning implementation for the vsdcaravel SoC targeting exact die dimensions (3.588 mm × 5.188 mm) with strategically distributed IO pad placement using SCL 180 nm technology.

---

## 📋 Overview

This repository implements **Task 5: SoC Floorplanning Using ICC2**, focusing exclusively on floorplan generation without progression into placement, clock tree synthesis, routing, or power distribution stages. The solution emphasizes die geometry accuracy and proper IO infrastructure reservation.

**Key Constraints:**
- Floorplan-only (strict scope boundary)
- No macros, placement, or optimization
- Synthesized netlist import for context only
- Report-based verification

---

## 🚀 Getting Started

### Setup Requirements

```
✓ Synopsys ICC2 2022.12 installation
✓ SCL 180 nm PDK reference library
✓ Pre-synthesized vsdcaravel Verilog netlist
✓ Linux shell with Tcl support
```

### Running the Flow

**Method 1: Batch Execution**
```bash
cd scripts/
icc2 -64bit -f floorplan.tcl
```

**Method 2: Interactive ICC2 Shell**
```tcl
icc2 -64bit
source scripts/floorplan.tcl
place_ports -self      # Optional: auto-distribute ports in GUI
gui_show_man_page      # Optional: visualize floorplan
```

### What Gets Generated

| Output | Purpose |
|--------|---------|
| `vsdcaravel_fp_lib/` | ICC2 design library (NDM format) |
| `floorplan_report.txt` | Die/core boundaries + port inventory |
| GUI visualization | Interactive floorplan viewer |

---

## 📐 Technical Specifications

### Die & Core Configuration

The floorplan uses **absolute coordinate definition** for reproducibility:

```
Die Extents:   [0, 0] → [3588, 5188] µm
Core Extents:  [200, 200] → [3388, 4988] µm
Core Margin:   200 µm (uniform, all edges)
Total Area:    18.606 mm²
```

**Initialization Command:**
```tcl
initialize_floorplan \
    -control_type die \
    -boundary {{0 0} {3588 5188}} \
    -core_offset {200 200 200 200}
```

This creates a rectangular die with inset core, leaving 200 µm perimeter for IO infrastructure.

### IO Region Reservation

Four **hard placement blockages** prevent standard-cell intrusion into IO bands:

```
┌─────────────────────────────────────┐
│  IO_TOP: 100 µm height              │
├─┬───────────────────────────────────┬─┤
│I│                                   │I│
│O│           CORE AREA              │O│
│_│      [200,200]→[3388,4988]       │_│
│L│                                   │R│
│E│                                   │I│
│F│                                   │G│
│T│                                   │H│
│ │                                   │T│
├─┴───────────────────────────────────┴─┤
│  IO_BOTTOM: 100 µm height           │
└─────────────────────────────────────┘
```

**Blockage Coordinates:**

| Region | Boundary | Size |
|--------|----------|------|
| Bottom | [0, 0] → [3588, 100] | Full width × 100 µm |
| Top | [0, 5088] → [3588, 5188] | Full width × 100 µm |
| Left | [0, 100] → [100, 5088] | 100 µm × core height |
| Right | [3488, 100] → [3588, 5088] | 100 µm × core height |

Each blockage is declared as `type hard`, creating permanent no-placement zones.

---

## 🔧 Script Architecture

The `floorplan.tcl` automation is organized into five sequential phases:

### Phase 1️⃣ - Initialization

```tcl
set DESIGN_NAME      vsdcaravel
set DESIGN_LIBRARY   vsdcaravel_fp_lib
set REF_LIB "/path/to/lib.ndm"
```

Establishes naming convention and references. The unified NDM library contains all technology and cell information from SCL 180 nm PDK.

### Phase 2️⃣ - Library Setup

```tcl
# Clean old runs
if {[file exists $DESIGN_LIBRARY]} {
    file delete -force $DESIGN_LIBRARY
}

# Create fresh ICC2 library
create_lib $DESIGN_LIBRARY -ref_libs $REF_LIB
```

Ensures reproducible execution by removing stale design data before library instantiation.

### Phase 3️⃣ - Design Import

```tcl
read_verilog -top $DESIGN_NAME \
  "/path/to/vsdcaravel_synthesis.v"
current_design $DESIGN_NAME
```
<img width="1680" height="1050" alt="Screenshot from 2025-12-19 19-14-31" src="https://github.com/user-attachments/assets/92ad6948-197b-4afa-93f3-43a157bac7b7" />


Loads the pre-synthesized netlist. Unresolved hierarchies (if any) are acceptable at floorplan stage—we're establishing die geometry, not validating timing.

### Phase 4️⃣ - Geometric Definition

```tcl
# Die + Core boundaries
initialize_floorplan \
    -control_type die \
    -boundary {{0 0} {3588 5188}} \
    -core_offset {200 200 200 200}

# IO region blockages
create_placement_blockage \
  -name IO_BOTTOM -type hard \
  -boundary {{0 0} {3588 100}}
# ... (repeat for TOP, LEFT, RIGHT)
```


This phase creates all spatial constraints. **No placement or routing commands follow.**

<img width="1680" height="1050" alt="Screenshot from 2025-12-19 19-15-03" src="https://github.com/user-attachments/assets/ac9e05f9-c250-4b4f-8c48-86ba70732eb2" />


### Phase 5️⃣ - Verification & Reporting

```tcl
redirect -file ../reports/floorplan_report.txt {
    puts "===== FLOORPLAN GEOMETRY ====="
    puts "Die Area  : 0 0 3588 5188  (microns)"
    puts "Core Area : 200 200 3388 4988  (microns)"
    puts "\n===== TOP LEVEL PORTS ====="
    get_ports
}
```

<img width="1680" height="1050" alt="Screenshot from 2025-12-19 19-15-03" src="https://github.com/user-attachments/assets/d3bef652-0b48-4416-87e1-9f73e7fda284" />


Generates audit trail documenting die/core extents and port list for downstream verification.

---

## 📊 Port Placement & Visualization

### Automatic Port Distribution

After script execution, ports are auto-placed using:

```tcl
place_ports -self
```
<img width="1680" height="1050" alt="Screenshot from 2025-12-19 19-20-26" src="https://github.com/user-attachments/assets/0888a276-4af8-4e30-b475-4366e5bf8e30" />

<img width="1680" height="1050" alt="Screenshot from 2025-12-19 19-20-14" src="https://github.com/user-attachments/assets/d6ec434a-0eb3-4257-b81f-adc53953ca4e" />


This command:
- Analyzes top-level port list
- Calculates perimeter distribution
- Places port instances along die edges
- Respects IO region blockages

### GUI Inspection Commands

```tcl
# Show interactive floorplan
gui_show_man_page

# Query port assignments
get_ports

# List blockage definitions
get_placement_blockages

# Zoom to design extents
zoom_extents
```

Expected visualization shows:
- ✓ Cyan die boundary outline
- ✓ Blue core region rectangle
- ✓ Gray shaded blockage areas (IO regions)
- ✓ Port markers along four edges

---

## ✅ Verification Workflow

### Automated Checks

Run these commands in ICC2 to verify correctness:

```tcl
# Check die size
get_floorplan -all

# Validate core boundaries
get_core_bounds

# List all blockages
get_placement_blockages -all

# Count and inspect ports
llength [get_ports]
```

### Visual Inspection Checklist

- [ ] Die boundary is rectangular with no concavities
- [ ] Core region is inset 200 µm from all die edges
- [ ] IO blockages form continuous bands (no gaps)
- [ ] Blockage bands don't overlap die boundary
- [ ] Port count matches top-level port declarations
- [ ] Ports align to nearest IO edge (no internal floating)
- [ ] No error messages in ICC2 transcript

### Report Verification

Check `floorplan_report.txt` contains:
```
===== FLOORPLAN GEOMETRY =====
Die Area  : 0 0 3588 5188  (microns)
Core Area : 200 200 3388 4988  (microns)

===== TOP LEVEL PORTS =====
[full port list]
```

---

## 📁 Repository Structure

```
Task_Floorplan_ICC2/
│
├── scripts/
│   └── floorplan.tcl              ← Main ICC2 automation script
│
├── reports/
│   └── floorplan_report.txt       ← Generated floorplan summary
│
├── images/
│   └── floorplan_screenshot.png   ← GUI visualization proof
│
└── README.md                       ← This file
```

---

## 🔄 Modifications from Reference Flow

The ICC2 workshop reference script (raven_wrapper) required significant adaptations:

| Element | Reference | This Implementation |
|---------|-----------|---------------------|
| **Design** | raven_wrapper | vsdcaravel |
| **PDK** | Generic Nangate | SCL 180 nm |
| **Netlist** | Generated internally | Pre-synthesized .v file |
| **Die Control** | Macro-driven | Explicit coordinate pair |
| **Core Margin** | Per-side variables | Uniform 200 µm constant |
| **IO Strategy** | Named regions | Hard blockages |
| **Flow Extent** | Through P&R | Stops post-floorplan |
| **Output Scope** | Full library | Minimal (report + library) |

---

## 🛠️ Troubleshooting Guide

### Error: "Reference library not found"
```
Cause: REF_LIB path is incorrect or file doesn't exist
Fix:   verify absolute path and check file permissions
       use: file exists /path/to/lib.ndm
```

### Error: "Unresolved cell references in netlist"
```
Cause: Netlist uses cells not in reference library
Fix:   This is expected in floorplan-only mode
       Add -continue_on_error flag if needed
```

### Error: "Blockage boundaries invalid"
```
Cause: Coordinate values exceed die extents
Fix:   Verify all blockage coordinates stay within [0,3588]×[0,5188]
       Check for left/right overlap: 100 + 3488 = 3588 ✓
```

### Ports not visible in GUI
```
Cause: Ports exist but not placed with coordinates
Fix:   Run: place_ports -self
       Then: gui_show_man_page
       Regenerate visualization
```

### Script execution hangs
```
Cause: ICC2 waiting for interactive input or library lock
Fix:   Kill process: pkill icc2
       Check for stale locks: rm -f vsdcaravel_fp_lib/.icv_lock
       Retry: icc2 -64bit -f floorplan.tcl
```

---

## 📝 Design Rationale

### Why Floorplan-Only Scope?

**Separation of Concerns**
- Die geometry and IO strategy are independent of placement algorithms
- Allows parallel physical design exploration

**Design Reusability**
- Floorplan serves as baseline for multiple place-and-route attempts
- Early catch of geometric infeasibility

**Learning Focus**
- Core ICC2 floorplanning concepts remain transparent
- Avoids optimization complexity in initial learning

**Resource Efficiency**
- Short execution time (seconds vs. hours)
- Enables iterative experimentation

### Memory Organization

vsdcaravel includes RAM128 and RAM256 memories that are **synthesized into distributed logic** rather than hard macros. Benefits:

- Simplifies floorplan (no macro placement logic)
- Allows placement algorithm full flexibility
- Trades area efficiency for design convenience

---
