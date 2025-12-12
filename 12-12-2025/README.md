# RISC-V SoC Implementation (RTL to GLS) using SCL180 PDK

## 1. Overview
This repository documents the successful replication of the **vsdcaravel** RISC-V SoC implementation. The project involves the complete flow from Functional Simulation to Synthesis and Gate-Level Simulation (GLS) using the **SCL180 PDK** and **Synopsys Design Tools**.

* **Top Module:** `vsdcaravel`
* **PDK:** SCL180 (Semiconductor Laboratory)
* **Tools:** Synopsys DC, VCS/Icarus Verilog, GTKWave
* **Reference:** [vsdip/vsdRiscvScl180](https://github.com/vsdip/vsdRiscvScl180/tree/iitgn)

To get started , clone the following directory

```
git clone https://github.com/vsdip/vsdRiscvScl180.git
cd vsdRiscvScl180
```

![git_clone](https://github.com/user-attachments/assets/e2962ac2-7878-4b88-b769-b5accd04788e)

Now we create a makefile for Rtl simulation 

![make_rtl](https://github.com/user-attachments/assets/d17027f8-6907-4cb8-a49c-adb62b405f3b)

here , we need to add the gcc path for that , to know where gcc is on our system , enter the following command

```
which gcc
```

![gcc_path](https://github.com/user-attachments/assets/0638af44-2ff2-40d0-99d1-21514a118b15)


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
    
![make](https://github.com/user-attachments/assets/a811b57a-d4f6-4930-a48c-a331a05c6b45)

    
4.  Executed the simulation using Icarus Verilog:
    ```bash
    vvp hkspi.vvp
    ```

    ![rtl_pass](https://github.com/user-attachments/assets/d16b7af2-cb94-41de-ba2a-0d2a41661e2e)

5.  Visualized the waveform:
    ```bash
    gtkwave hkspi.vcd hkspi_tb.v
    ```
    ![rtl_waveform](https://github.com/user-attachments/assets/5d13f6aa-14e7-462f-8e51-4a4e8c43ae24)


### Results
* **Console Output:** Successful execution confirmed.
* **Waveform:** Validated correct behavior of the `hkspi` block.
---

## 3. Synthesis (Synopsys DC)

The design was synthesized using Synopsys Design Compiler with the SCL180 PDK.

### Execution
* **Directory:** `./synthesis/work_folder`
* **Command:** `dc_shell -f ../synth.tcl`.
* **Output:** Generated `vsdcaravel_synthsis.v` netlist.

![synthesis_pass](https://github.com/user-attachments/assets/27acffcd-d41c-4283-907a-50b48f5f79fd)

![schematic](https://github.com/user-attachments/assets/3405fe1b-5395-480c-a6f9-c07499a1d0b2)

### Synthesis Reports
Below are the key metrics extracted from the post-synthesis reports.

#### 1. Area Report

![area](https://github.com/user-attachments/assets/b422df14-b5b3-4ce4-a800-449fbd0a2501)


#### 2. Power Report (Estimates)

![power](https://github.com/user-attachments/assets/3128742c-d506-4ee3-ab78-83482d1443e2)


#### 3. Quality of Results (QoR)

![qor](https://github.com/user-attachments/assets/dfa33a76-88bc-4676-bcf8-ddd4fe2208f6)


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
  ![gls_pass](https://github.com/user-attachments/assets/6c258331-f6a9-4a8f-b635-d32b2c297c73)

    
3.  Visualize results:
    ```bash
    gtkwave hkspi.vcd hkspi_tb.v
    ```
![gls_waveform](https://github.com/user-attachments/assets/304a5f7c-e163-45c5-88a8-99573c58c32f)


### Results
* The GLS waveform matched the Functional Simulation waveform.
* Critical paths showed no unknown (`X`) states.

---

## 5. Issues & Resolutions

| Issue | Description | Resolution |
| :--- | :--- | :--- |
| **Blackboxes** | `RAM128`, `housekeeping`, and `dummy_por` were black-boxed during synthesis. | Removed black-box definitions from the netlist and added `` `include `` statements to link original RTL files for GLS. |
| **Power Pins** | Logic 0 tied to `1'b0` instead of ground net. | Replaced `1'b0` with `vssa` in the netlist. |
| **Timing Loops** | Combinational loops detected in `housekeeping` (wbbd_sck_reg) and `PLL`. | Tools automatically disabled timing arcs to break loops; noted for future static timing analysis. |

---
