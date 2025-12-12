# Day 1: RISC-V SoC Implementation (RTL to GLS) using SCL180 PDK

## 1. Overview
This repository documents the successful replication of the **vsdcaravel** RISC-V SoC implementation. The project involves the complete flow from Functional Simulation to Synthesis and Gate-Level Simulation (GLS) using the **SCL180 PDK** and **Synopsys Design Tools**.

* **Top Module:** `vsdcaravel`
* **PDK:** SCL180 (Semiconductor Laboratory)
* **Tools:** Synopsys DC, VCS/Icarus Verilog, GTKWave
* **Reference:** [vsdip/vsdRiscvScl180](https://github.com/vsdip/vsdRiscvScl180/tree/iitgn)

---

## 2. Functional Simulation (RTL)

Verification of the Register-Transfer Level code was performed to ensure logical correctness before synthesis.

### Steps Performed
1.  Navigate to the verification directory: `cd dv/hkspi/`.
2.  Modified `Makefile` to point to the local RISC-V GCC installation and SCL IO models.
3.  Cleaned and compiled the simulation:
    ```bash
    make clean
    make
    ```
4.  Executed the simulation using Icarus Verilog:
    ```bash
    vvp hkspi.vvp
    ```
5.  Visualized the waveform:
    ```bash
    gtkwave hkspi.vcd hkspi_tb.v
    ```

### Results
* **Console Output:** Successful execution confirmed.
* **Waveform:** Validated correct behavior of the `hkspi` block.

> **[Insert Screenshot of Functional Simulation Waveform Here]**
> *Figure 1: Functional Simulation Waveform in GTKWave*

---

## 3. Synthesis (Synopsys DC)

The design was synthesized using Synopsys Design Compiler with the SCL180 PDK.

### Execution
* **Directory:** `./synthesis/work_folder`
* **Command:** `dc_shell -f ../synth.tcl`.
* **Output:** Generated `vsdcaravel_synthsis.v` netlist.

### Synthesis Reports
Below are the key metrics extracted from the post-synthesis reports.

#### 1. Area Report
* **Total Cell Area:** 773,088.68
* **Total Design Area:** 805,879.78
* **Cell Count:** 30,961
* **Combinational Area:** ~341,952
* **Sequential Area:** ~431,036
* **Black Boxes:** 16 (Includes RAM128, housekeeping).

#### 2. Power Report (Estimates)
* **Total Dynamic Power:** 76.59 mW
* **Cell Internal Power:** 38.62 mW (50%)
* **Net Switching Power:** 37.97 mW (50%)
* **Leakage Power:** 1.13 µW.

#### 3. Quality of Results (QoR)
* **Timing Path Group:** (none)
* **Critical Path Slack:** 0.00
* **Violating Paths:** 0
* **Note:** Several timing loops were detected and disabled during optimization (specifically in `housekeeping` and `PLL` modules).

---

## 4. Gate-Level Simulation (GLS)

GLS was performed to verify the synthesized netlist against the RTL behavior.

### Setup & Netlist Modification
To enable GLS, specific modifications were made to the directory structure and the synthesized netlist to handle black-boxed modules (`RAM128`, `housekeeping`, `dummy_por`).

**1. File Preparation:**
* Copied all RTL files and wrappers to the `gl/` directory.
* Modified `clock_div.v` to include `defines.v`.

**2. Netlist Editing (`vsdcaravel_synthsis.v`):**
* **Includes:** Added the following lines to the top of the netlist:
    ```verilog
    `include "dummy_por.v"
    `include "RAM128.v"
    `include "housekeeping.v"
    ```
* **Removals:** Deleted the black-box module definitions for `RAM128` (lines 8-16) and `housekeeping` (lines ~38,599 to end) to allow the included RTL files to take precedence.
* **Power Fix:** Replaced all instances of `1'b0` with `vssa` in `vsdcaravel.v`.

**3. Makefile Configuration:**
A dedicated `Makefile` was created in `gls/` to handle the specific include paths (`-I`) and module search paths (`-y`) for the PDK, IO wrappers, and RTL.

### Execution
1.  Navigate to `gls/`.
2.  Run the simulation:
    ```bash
    make clean
    make
    vvp hkspi.vvp
    ```
3.  Visualize results:
    ```bash
    gtkwave hkspi.vcd hkspi_tb.v
    ```

### Results
* The GLS waveform matched the Functional Simulation waveform.
* Critical paths showed no unknown (`X`) states.

> **[Insert Screenshot of GLS Waveform Here]**
> *Figure 2: Gate-Level Simulation Waveform in GTKWave*

---

## 5. Issues & Resolutions

| Issue | Description | Resolution |
| :--- | :--- | :--- |
| **Blackboxes** | `RAM128`, `housekeeping`, and `dummy_por` were black-boxed during synthesis. | Removed black-box definitions from the netlist and added `` `include `` statements to link original RTL files for GLS. |
| **Power Pins** | Logic 0 tied to `1'b0` instead of ground net. | Replaced `1'b0` with `vssa` in the netlist. |
| **Timing Loops** | Combinational loops detected in `housekeeping` (wbbd_sck_reg) and `PLL`. | Tools automatically disabled timing arcs to break loops; noted for future static timing analysis. |

---

## 6. Directory Structure (Evidence)

* `dv/`: Functional verification scripts and logs.
* `synthesis/`: Synthesized netlist and reports (Area, Power, QoR).
* `gls/`: Modified netlist, Makefile, and GLS waveforms.
