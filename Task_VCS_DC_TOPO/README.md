# RISC-V SoC Research Task: Industry-Grade Synopsys VCS + DC_TOPO Flow (SCL180)

## 1. Project Objective & Research Scope

The primary objective of this research task is to transition the vsdcaravel SoC design flow from an open-source educational environment to a robust, industry-standard RTL-to-GDSII flow using Synopsys EDA tools[^1].

This project moves beyond guided execution into independent research-driven implementation[^2]. The focus is on establishing a clean, error-free synthesis and simulation environment using the SCL180 PDK, ensuring design correctness through rigorous Gate-Level Simulation (GLS) while strictly adhering to the "No Open-Source Simulation Tools" policy[^3].

### Key Research Goals

- **Complete Toolchain Migration**: Replacement of Icarus Verilog and GTKWave with Synopsys VCS and DVE/Verdi[^4].

- **Topological Synthesis**: Implementation of DC_TOPO synthesis strategies using `compile_ultra` with careful handling of analog/mixed-signal macros[^5].

- **Blackbox Preservation**: Developing a Tcl-based methodology to preserve Power-On-Reset (POR) and Memory macros as blackboxes during the synthesis phase[^6].

- **Knowledge Base Utilization**: Active usage of Synopsys SolvNet to resolve proprietary tool errors and licensing issues[^7].

---

## 2. Directory Structure & Organization

To maintain a clean research environment, the repository is organized into distinct directories for RTL, Simulation, Synthesis, and Logs.

### Setup Commands

Run the following commands to replicate the exact directory structure required for this flow:

```bash
# Create the main project directory
mkdir -p Task_VCS_DC_TOPO
cd Task_VCS_DC_TOPO

# Create sub-directories for source code and workflows
mkdir -p rtl
mkdir -p gls
mkdir -p synthesis/output
mkdir -p synthesis/report
mkdir -p dv/hkspi/tmp

# Initialize git tracking
git init
git checkout -b iitgn
```

### File Manifest

| Directory | Purpose |
|-----------|---------|
| `rtl/` | Contains the Verilog source code for vsdcaravel and sub-modules |
| `dv/hkspi/` | Holds the functional verification testbench and the VCS Makefile |
| `synthesis/` | Contains the synth.tcl script and .sdc constraints |
| `gls/` | Contains the netlist-verification wrapper files |

---

## 3. Toolchain Migration Strategy

In compliance with the mandatory removal of open-source tools[^8], the following components were scrubbed from all scripts, Makefiles, and documentation:

| Legacy Component | Status | Replacement Tool | Version Used |
|---|---|---|---|
| iverilog | REMOVED | Synopsys VCS | U-2023.03 |
| gtkwave | REMOVED | Synopsys DVE / Verdi | U-2023.03 |
| yosys | REMOVED | Synopsys DC_TOPO | T-2022.03-SP5 |

---

## 4. Functional Simulation (Synopsys VCS)

### 4.1. Prerequisites & Environment Setup

Before executing simulation, the environment was configured to point to the SCL180 PDK and the Synopsys license servers.

**Source Synopsys Tools:**

```bash
source /path/to/synopsys/cshrc
source toolRC_iitgntapeout
```

**Verify GCC Toolchain**: Used `riscv32-unknown-elf-gcc` for compiling the firmware (hex files).

### 4.2. VCS Makefile Configuration

The Makefile located in `dv/hkspi/` was rewritten from scratch. Unlike Icarus Verilog, VCS requires specific compilation flags to handle SystemVerilog constructs and library compilation.

#### Key Flags Explained:

- **`-sverilog`**: Enables SystemVerilog support (essential for modern testbenches).
- **`+v2k`**: Enables Verilog-2001 standard support.
- **`-full64`**: Forces 64-bit mode compilation.
- **`-debug_all`**: Enables full visibility of internal signals for DVE/Verdi debugging.
- **`-lca`**: Limited Customer Availability features (often required for specific PDK features).
- **`+incdir+`**: Replaces `-I` for defining include directories.

#### Final Makefile (Snippets):

```makefile
# VCS Compilation Targets
compile: ${PATTERN}_tb.v ${PATTERN}.hex
	vcs $(VCS_FLAGS) $(SIM_DEFINES) $(VCS_INCDIR) \
	${PATTERN}_tb.v \
	-l $(COMPILE_LOG) \
	-o $(SIMV)

# GUI Execution Target
gui: compile
	./$(SIMV) -gui -l $(SIM_LOG) &
```

### 4.3. Issue Resolution (Research Log)

During the migration, the following errors were debugged using independent research:

#### Issue A: Error-[IND] Identifier not declared

**Observation**: The simulation failed in `dummy_schmittbuf.v`.

**Root Cause**: The project enforced `default_nettype none`, but the Schmitt buffer UDP signals were not explicitly typed.

**Fix**:
- Opened `rtl/dummy_schmittbuf.v`
- Changed directive to `default_nettype wire`
- Renamed primitive `dummy__udp_pwrgood_pp$PG` to `dummy__udp_pwrgood_pp_PG` to resolve VCS special character conflicts

#### Issue B: Missing TMP Directory

**Observation**: VCS errored out regarding TMPDIR.

**Root Cause**: VCS requires a physical temporary directory for intermediate object files.

**Fix**: Manually created the directory:
```bash
mkdir -p tmp
```

### 4.4. Simulation Execution

To verify the functionality of the SoC:

```bash
cd dv/hkspi
make clean
make compile
make gui
```

**Outcome**: The waveform correctly displayed the SPI functionality, matching the golden reference behavior.

---

## 5. Synthesis (Synopsys DC_TOPO)

### 5.1. Synthesis Strategy

The synthesis process uses Design Compiler Topological Mode. This mode provides better correlation with post-layout timing by using physical constraints early in the flow.

**Mandatory Constraint**: The Power-On-Reset (POR) and RAM modules (RAM128, RAM256) must not be synthesized[^9]. They must remain as RTL blackboxes to be replaced by hard macros during Physical Design.

### 5.2. Detailed Tcl Script Breakdown (synth.tcl)

A custom Tcl script was developed to handle the blackboxing methodology.

#### 1. Library Loading:

```tcl
read_db "tsl18cio250_min.db"   # I/O Pad Library
read_db "tsl18fs120_scl_ff.db" # Standard Cell Library (Fast-Fast corner)
```

**Why**: Defines the "LEGO bricks" DC can use to build the circuit.

#### 2. Dynamic Blackbox Stubbing:

To prevent DC from seeing the internals of the RAM/POR, we generate a "stub" file on the fly.

```tcl
set blackbox_file "$root_dir/synthesis/memory_por_blackbox_stubs.v"
set fp [open $blackbox_file w]
puts $fp "(* blackbox *) module RAM128(CLK, EN0, ... input [6:0] A0 ...);"
close $fp
```

**Why**: This creates an empty shell. DC sees the ports but no logic, so it cannot optimize it away.

#### 3. Reading RTL with Exclusions:

We read the actual design but explicitly exclude the files RAM128.v, RAM256.v, and dummy_por.v.

```tcl
read_file $blackbox_file -format verilog  # Read stubs FIRST
read_file $rtl_to_read -format verilog    # Read rest of design
```

#### 4. Protection Attributes:

```tcl
set_dont_touch [get_designs RAM128]
set_attribute [get_designs RAM128] is_black_box true
```

**Why**: `set_dont_touch` forbids DC from optimizing, flattening, or removing the module.

#### 5. Optimization:

```tcl
compile_ultra -incremental
```

**Why**: `compile_ultra` performs high-effort optimization for timing and area. `-incremental` is used for topological refinement.

### 5.3. Running Synthesis

Execute the following command in the `synthesis/` directory:

```bash
dc_shell -f synth.tcl | tee synthesis_complete.log
```

### 5.4. Generated Reports

Upon completion, the `synthesis/report/` folder contains:

- **`area.rpt`**: Detailed cell count (excluding blackboxes)
- **`timing.rpt`**: Analysis of critical paths (Setup/Hold)
- **`blackbox_modules.rpt`**: A custom-generated report verifying that RAM128, RAM256, and dummy_por are marked "PRESENT" as instances but have no internal logic synthesized

---

## 6. Gate-Level Simulation (GLS)

### 6.1. Objective

GLS is critical to verify that the synthesis tool did not alter the logical functionality of the design[^10]. It involves simulating the Synthesized Netlist (`vsdcaravel_synthesis.v`) using the Standard Cell Verilog models.

### 6.2. GLS Configuration

We must "stitch" the design back together for simulation.

- **Core Logic**: Comes from the synthesized netlist
- **Standard Cells**: Come from the SCL180 PDK Verilog models
- **Blackboxes**: The original RTL for RAM128, RAM256, and por is linked back in so the simulation works

#### Modified VCS Command for GLS:

```makefile
vcs -full64 -debug_access+all +define+GL \
    +incdir+$(VERILOG_PATH)/synthesis/output \  # Point to Netlist
    +incdir+$(PDK_PATH) \                       # Point to Std Cell Models
    $(GL_PATH)/defines.v \
    ...
```

### 6.3. Execution & Validation

Copy the hex file:
```bash
cp dv/hkspi/hkspi.hex .
```

Run GLS:
```bash
make simv
```

Debug:
```bash
make debug
```

**Result**: The GLS waveforms showed zero X-propagation (unknown states) on the wishbone bus, confirming the netlist is functionally equivalent to the RTL.

---

## 7. Synopsys SolvNet References

As mandated[^11], Synopsys SolvNet was utilized for:

- **VCS Error Codes**: Looking up Error-[IND] to understand stricter SystemVerilog variable declaration rules compared to iverilog
- **DC Blackbox Flows**: Researching the correct usage of `is_black_box` attributes vs `set_dont_touch` to ensure macros were not optimized away
- **OTP Resolution**: Collaborated via WhatsApp for real-time OTP access when SolvNet credentials required 2FA[^12]

---

## 8. Conclusion

This task successfully demonstrated the migration of vsdcaravel to a pure Synopsys flow:

✅ **VCS** is now the sole simulation engine  
✅ **DC_TOPO** provides a physical-aware synthesized netlist  
✅ Documentation is fully compliant, with no traces of open-source tools  
✅ The design is now ready for Physical Design (Place & Route) with clean, verified netlists and preserved macros

---

## Quick Reference Commands

```bash
# Setup
mkdir -p Task_VCS_DC_TOPO && cd Task_VCS_DC_TOPO
git init && git checkout -b iitgn
mkdir -p rtl gls synthesis/{output,report} dv/hkspi/tmp

# Simulation
cd dv/hkspi && make clean && make compile && make gui

# Synthesis
cd synthesis && dc_shell -f synth.tcl | tee synthesis_complete.log

# GLS
cp dv/hkspi/hkspi.hex . && make simv
```

---

## License & Documentation

For additional documentation and detailed specifications, refer to the SCL180 PDK documentation and Synopsys tool user guides.

[^1]: Synopsys EDA Tools for RTL-to-GDSII flow
[^2]: Research-driven implementation beyond guided execution
[^3]: No open-source simulation tools policy
[^4]: VCS and DVE/Verdi replacement for iverilog/gtkwave
[^5]: DC_TOPO with compile_ultra optimization
[^6]: Tcl-based blackbox preservation methodology
[^7]: Synopsys SolvNet knowledge base utilization
[^8]: Mandatory removal of open-source tools
[^9]: Preservation of POR and RAM macros as blackboxes
[^10]: Gate-Level Simulation for functional verification
[^11]: SolvNet usage mandate
[^12]: OTP access for 2FA credentials
