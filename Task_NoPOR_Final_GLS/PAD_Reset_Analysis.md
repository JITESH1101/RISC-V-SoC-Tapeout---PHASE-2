# SCL-180 PAD Reset Analysis

**Date:** December 15, 2025  
**Design:** VSD RISC-V SoC on SCL-180 PDK  
**Goal:** Determine if SCL-180 reset pad requires internal enable, POR gating, and power-up sequencing constraints. Contrast with SKY130 to justify external reset-only architecture.

---

## Executive Summary

The SCL-180 reset pad (PC3D21) is a **simple CMOS input buffer** with only PAD and CIN (core input) ports. Unlike SKY130's XRES pad which required POR-driven enables (ENABLE_H, ENABLE_VDDA_H, etc.), the SCL-180 pad has **no internal enable, no POR gating requirement, and no pad-level power-up constraints**. Reset is asynchronous and available immediately after VDD becomes valid. An external reset-only architecture is therefore safe and sufficient for SCL-180.

---

## 1. Reset Pad Behavior in SCL-180

### 1.1 Actual Reset Pad Used: PC3D21

From the repository **rtl/chip_io.v**, the instantiated SCL-180 reset pad is:

```verilog
pc3d21 resetb_pad (
    .PAD(resetb),
    .CIN(resetb_core_h)
);
```

**Key Observations:**
- **Only two ports:** `.PAD()` and `.CIN()`
- **No enable pins:** There is no `.ENABLE_H`, `.ENABLE_VDDA_H`, or `.ENABLE_VSWITCH_H`
- **No POR control:** There is no `.ENABLE_VDDIO` or power-gating inputs
- **Direct buffering:** The pad simply buffers the external reset signal (resetb) to the core logic (resetb_core_h)

### 1.2 Comparison with SKY130 XRES Pad (Commented Out)

In the same file **rtl/chip_io.v**, the legacy SKY130 XRES reset pad (now commented out) shows the stark difference:

```verilog
/* sky130_fd_io__top_xres4v2 resetb_pad (
    ...
    .ENABLE_H(porb_h),           // POR-driven enable
    .EN_VDDIO_SIG_H(...),
    .INP_SEL_H(...),
    .FILT_IN_H(...),
    .PULLUP_H(...),
    ...
); */
```

**Why this matters:**
- SKY130 XRES required `.ENABLE_H` tied to `porb_h` (Power-On-Reset signal)
- SKY130 XRES had internal glitch filtering (FILT_IN_H) and pullup controls requiring POR sequencing
- SCL-180 PC3D21 has **none of these pins**, implying no POR-driven control is needed

### 1.3 Direct Answers for SCL-180 Reset Pad

| Question | Answer | Justification |
|----------|--------|---------------|
| **Internal enable required?** | **No** | PC3D21 instantiation shows only `.PAD` and `.CIN`; no enable port exists. |
| **POR-driven gating required?** | **No** | No `.ENABLE_H`, `.ENABLE_VDDA_H`, or POR-related pins in the pad instantiation. |
| **Is reset asynchronous?** | **Yes** | `resetb_core_h` is connected directly to asynchronous reset logic in housekeeping and clock domains; no synchronizer is interposed. |
| **Available immediately after VDD?** | **Yes** | Since the pad has no enable or power-good qualification, it buffers the external reset as soon as VDD is valid and the pad is out of power-up undefined state. |
| **Power-up constraints mandating POR?** | **No** | No PDK comments, pad datasheet restrictions, or additional RTL constraints enforce POR usage at the pad level for SCL-180. |

---

## 2. General SCL-180 I/O Pad Interfaces vs SKY130

### 2.1 SCL-180 Pad Wrappers: No POR Pins

From **rtl/scl180_wrapper/** directory, all instantiated SCL-180 pad wrappers expose only basic control pins, with **no ENABLE_H or POR-related ports**:

#### PC3B03ED (Bidirectional Pad)
```verilog
module pc3b03ed_wrapper(OUT, PAD, IN, INPUT_DIS, OUT_EN_N, dm);
    output IN;
    input  OUT, INPUT_DIS, OUT_EN_N;
    inout  PAD;
    input  [2:0] dm;
    
    pc3b03ed pad(
        .CIN(IN),
        .OEN(output_EN_N),
        .RENB(pull_down_enb),
        .I(OUT),
        .PAD(PAD)
    );
endmodule
```
**Control pins:** `INPUT_DIS`, `OUT_EN_N`, `dm` (drive mode) — **no ENABLE_H**

#### PC3D01 (Input Only Pad)
```verilog
module pc3d01_wrapper(output IN, input PAD);
    pc3d01 pad(.CIN(IN), .PAD(PAD));
endmodule
```
**Control pins:** None beyond the pad itself — **no ENABLE_H, no POR pins**

#### PT3B02 (Tristate Output)
```verilog
module pt3b02_wrapper(output IN, inout PAD, input OE_N);
    pt3b02 pad(.CIN(IN), .OEN(OE_N), .I(), .PAD(PAD));
endmodule
```
**Control pins:** `OE_N` (output enable) — **no ENABLE_H or power gating**

#### PC3D21 (Reset Input Pad)
```verilog
pc3d21 pad(
    .PAD(resetb),
    .CIN(resetb_core_h)
);
```
**Control pins:** None — **purely a simple input buffer**

### 2.2 SKY130 Pads in Legacy Code (Not Instantiated for SCL-180)

From **rtl/pads.v**, legacy SKY130 pad macros still present in the codebase (but NOT used in the SCL-180 build):

```verilog
// SKY130 GPIO pad example (commented out for SCL-180):
sky130_fd_io__top_gpio_ovtv2 gpio_pad (
    .ENABLE_H(porb_h),            // POR-controlled
    .ENABLE_INP_H(porb_h),        // POR-controlled
    .ENABLE_VDDA_H(porb_h),       // POR-controlled
    .ENABLE_VSWITCH_H(porb_h),    // POR-controlled
    .ENABLE_VDDIO(vddio_h),       // Power sequencing
    ...
);
```

**Critical difference:**
- SKY130 pads have **multiple ENABLE pins driven by POR**
- SCL-180 active instantiations have **no such enable pins**
- This means SCL-180 pads do not rely on POR for sequencing

### 2.3 Level Shifting: Built Into Pads, Not Part of POR

From **rtl/dummy_por.v**:

```verilog
// Comment in the file explicitly states:
// "since SCL180 has level-shifters already available in I/O pads"

assign porb_l = porb_h;  // Direct assignment, no level shifting needed
```

**Implication:**
- SCL-180 pad macros **include internal level shifters** for voltage-domain translation (1.8V / 3.3V / 5V)
- POR logic does **not** perform level shifting; it just provides a digital reset signal
- This is opposite to SKY130, where some pads required POR-driven enables to properly sequence level shifters

---

## 3. Why POR Was Mandatory in SKY130

### 3.1 SKY130 Pad Architecture Constraints

In Caravel (SKY130), the padding and reset architecture required POR because:

1. **Pad Enable Sequencing:** GPIO and XRES pads exposed `ENABLE_H`, `ENABLE_VDDA_H`, `ENABLE_VSWITCH_H` pins that **must be driven by POR** to turn on the pad's input and output buffers at the right time.

2. **Reset Pad Dependencies:** The XRES reset pad (now commented out in the codebase) had internal glitch filtering and pullup controls that depended on POR timing:
   ```verilog
   .ENABLE_H(porb_h),      // POR enable for internal circuits
   .FILT_IN_H(...),         // POR-driven glitch filter
   .PULLUP_H(...),          // POR-driven pullup control
   ```

3. **Power Supply Sequencing:** SKY130 allowed IO and core supplies to ramp at different rates. POR had to gate pad control until both supplies were in spec, preventing undefined behavior at power-up.

4. **Flop Reset Requirement:** Without proper POR reset, internal flops, clock generators, and PLLs on SKY130 could power up in metastable or undefined states, requiring a proper reset pulse from POR.

### 3.2 SKY130 Conclusion

In SKY130:
- **POR was architecturally mandatory** because pad behavior depended on POR-driven enables
- Failing to use POR or to properly sequence it would violate the pad interface contract
- The XRES reset pad itself relied on POR for correct filtering and pullup behavior
- External reset alone was **insufficient** without POR enabling the pads

---

## 4. Why POR Is Not Mandatory in SCL-180

### 4.1 SCL-180 Pad Architecture: No Mandatory Enables

The evidence from the codebase clearly shows SCL-180 pads are fundamentally different:

1. **No ENABLE_H Pins in Active Instantiations**
   - All active SCL-180 pad wrappers (pc3b03ed_wrapper, pc3d01_wrapper, pt3b02_wrapper, pc3d21) expose only data and simple control signals (OE_N, INPUT_DIS)
   - There is **no ENABLE_H, ENABLE_VDDA_H, or ENABLE_VSWITCH_H** port
   - Legacy SKY130 macros with `.ENABLE_H(porb_h)` exist in rtl/pads.v but are **not instantiated** in the SCL-180 configuration

2. **Reset Pad is a Simple Buffer**
   - PC3D21 is instantiated with only `.PAD(resetb)` and `.CIN(resetb_core_h)`
   - No POR enable pin, no power-good pin, no glitch filter enable
   - It is purely a CMOS input buffer with no POR dependencies

3. **Level Shifting Built Into Pads**
   - SCL-180 pad macros already contain internal level shifters for voltage-domain translation
   - POR logic is not involved in level shifting
   - This is handled at the pad level, not at the POR/reset level

4. **Design Explicitly States No On-Chip POR**
   - Comments in **rtl/chip_io.v** state the design uses a "digital reset input **due to the lack of an on-board power-on-reset circuit**"
   - The repository intentionally **shifted responsibility to external reset** circuitry
   - The XRES pad (which needed POR) was replaced by PC3D21 (which does not)

5. **No Power-Up Constraints in PDK or RTL**
   - The attached SCL-180 General Information document and Readme specify allowed voltage domains, ESD guidelines, and legal device combinations
   - **There is no statement mandating POR usage or tying GDS acceptance to POR inclusion**
   - No RTL glue or comments enforce a specific power-up sequence dependency on an on-chip POR

6. **Testbench Confirms External Reset Responsibility**
   - In **hkspi testbench**, RSTB (reset) is driven directly from the testbench to control reset behavior
   - There is **no reliance on internal POR** for the design to initialize correctly
   - The design already assumes **external reset is responsible for sequencing**

### 4.2 SCL-180 Conclusion

In SCL-180:
- **POR is not mandatory at the pad level** because pads lack ENABLE_H-type pins
- Reset pad (PC3D21) is a simple asynchronous buffer with no POR dependencies
- Level shifting and voltage-domain handling are **inside the pad macro**, not driven by POR
- An **external reset-only strategy is architecturally sufficient**, provided that board-level circuitry correctly asserts reset while supplies ramp and holds it until VDD is valid and clocks are stable
- POR may still be useful for **digital reset distribution** within the core (e.g., for housekeeping, clock trees) but is **not required by the pad interface**

---

## 5. Direct Answers to Task Questions

### Does the reset pad require an internal enable?

**Answer: No**

The SCL-180 reset pad (PC3D21) is instantiated in **rtl/chip_io.v** with only `.PAD(resetb)` and `.CIN(resetb_core_h)`. There is **no `.ENABLE_H`, `.ENABLE_L`, or similar control pin** in the instantiation. The pad has no internal enable signal that must be asserted for the reset to be active.

In contrast, the commented-out SKY130 XRES pad explicitly required `.ENABLE_H(porb_h)`, demonstrating that SKY130 reset needed an enable but SCL-180 does not.

---

### Does the reset pad require POR-driven gating?

**Answer: No**

The SCL-180 PC3D21 pad instantiation contains **no POR-related ports**. The commented SKY130 equivalent shows multiple POR-driven pins (`.ENABLE_H(porb_h)`, `.FILT_IN_H(...)`, `.PULLUP_H(...)`), none of which exist in the SCL-180 version. 

The repository explicitly notes that the design uses "a digital reset input due to the lack of an on-board power-on-reset circuit," confirming that **POR is not gating the reset pad**. If POR is generated internally (in core logic via dummy_por.v), it is **not fed back into the pad**; it serves only as a digital reset signal downstream.

---

### Is the reset pin asynchronous?

**Answer: Yes**

The reset signal `resetb_core_h` (output from PC3D21) is connected directly to asynchronous reset inputs in the housekeeping block and clock domain logic. There is **no synchronizer, no gray counter, or any clocked logic** interposing between the external reset pin and its use as an async reset. The pad itself presents the signal asynchronously to the core.

---

### Is the reset pin available immediately after VDD?

**Answer: Yes**

Since PC3D21 has **no enable or power-good qualification**, the pad begins buffering the external reset signal as soon as:
1. VDD (core supply) reaches its valid operating level
2. VDDO (IO supply) reaches its valid operating level  
3. The pad exits its power-up undefined state

There is **no extra gating or delay** documented at the pad level. Any additional analog behavior (internal filtering, ESD clamps, etc.) is inside the PC3D21 macro, but it does not prevent the reset from propagating to `resetb_core_h` immediately when supplies are valid.

The only requirement is that **external reset circuitry** (board supervisor or RC network) holds `resetb` asserted while supplies ramp and clocks stabilize.

---

### Are there documented power-up sequencing constraints that mandate a POR?

**Answer: No**

1. **PDK Level:** The attached SCL-180 General Information and Readme documents specify legal voltage combinations, ESD compliance, and available power-detection cells (POK1818, POK5050, etc.), but they **do not state that a POR macro is mandatory** or that GDS will be rejected without one.

2. **RTL Level:** The repository contains **no RTL comments or constraints** that tie the reset pad or any other pad to a mandatory POR macro. The code explicitly states that the design lacks "an on-board power-on-reset circuit," confirming the absence of a POR requirement.

3. **Pad Level:** PC3D21 has **no POR-driven enable pins**, so there is no pad-level constraint forcing a particular power-up sequence.

4. **Power Supply Sequencing:** Unlike SKY130 (which allowed IO and core supplies to sequence independently and required POR gating to handle this), **SCL-180 assumes standard power-supply ramps** where both IO and core supplies reach valid levels together. No special sequencing constraint is imposed by the PDK.

**Conclusion:** POR is entirely optional on SCL-180 at the pad level. If POR is used internally for robustness (e.g., to reset internal counters or flops), it is a design choice, not a PDK requirement.

---

## 6. Why POR Was Mandatory in SKY130 But Not in SCL-180

### SKY130 (Caravel) Architecture

| Aspect | SKY130 | SCL-180 |
|--------|--------|---------|
| **Reset Pad Type** | `sky130_fd_io__top_xres4v2` with ENABLE_H, FILT_IN_H, PULLUP_H | `pc3d21` with only PAD and CIN |
| **Pad Enable Pins** | `.ENABLE_H(porb_h)`, `.ENABLE_VDDA_H(porb_h)`, `.ENABLE_VSWITCH_H(porb_h)` | None; pads always on (no ENABLE_H port) |
| **Reset Pad Dependencies** | Requires POR enable for internal filtering, pullups, and level shifters | Simple buffer; no POR dependencies |
| **GPIO Pad Control** | GPIO pads require `.ENABLE_H(porb_h)` to enable input/output buffers | GPIO pads (e.g., pc3b03ed) use only OE_N; no ENABLE_H |
| **Level Shifter Control** | POR may drive level-shifter enable for voltage-domain isolation | Level shifters built into pad macro; not POR-controlled |
| **Power Supply Sequencing** | IO and core supplies could sequence independently; POR gates pads until both valid | Standard synchronized ramp; no independent sequencing |
| **Flop Reset** | Flops could power up undefined without POR reset | Flops expected to be reset by external reset or internal logic |
| **Design Requirement** | POR was **architecturally mandatory** to sequence pad enables correctly | POR is **optional**; external reset is sufficient for pads |

### Key Insight: Pad Interface Philosophy

**SKY130:**
- Pads are "off" at power-up; must be enabled via ENABLE pins
- Reset pad requires POR enable to function
- Therefore, **POR is mandatory** to bring pads online correctly

**SCL-180:**
- Pads are "on" as soon as power is valid; no ENABLE pins
- Reset pad is a simple buffer with no POR dependencies
- Therefore, **POR is optional**; external reset is sufficient

---

## 7. References

### Repository Files Analyzed

1. **rtl/chip_io.v**
   - Instantiation of PC3D21 reset pad (no ENABLE_H pins)
   - Commented SKY130 XRES pad showing ENABLE_H(porb_h) dependency
   - Design comments stating "lack of an on-board power-on-reset circuit"

2. **rtl/scl180_wrapper/pc3b03ed_wrapper.v**
   - SCL-180 bidirectional pad with INPUT_DIS, OUT_EN_N, dm controls (no ENABLE_H)

3. **rtl/scl180_wrapper/pc3d01_wrapper.v**
   - SCL-180 input-only pad with minimal control

4. **rtl/scl180_wrapper/pt3b02_wrapper.v**
   - SCL-180 tristate output pad with OE_N control (no ENABLE_H)

5. **rtl/dummy_por.v**
   - Comment: "since SCL180 has level-shifters already available in I/O pads"
   - Confirms level shifting is in pad macro, not in POR logic

6. **rtl/pads.v**
   - Legacy SKY130 pad macros with .ENABLE_H(porb_h) and related enables
   - Demonstrates what SKY130 required vs. what SCL-180 does not

7. **rtl/caravel_netlists.v**
   - Inclusion of pc3d21.v as the instantiated reset pad cell

8. **SCL-180 PDK Documentation**
   - General Information and Guidelines on IOPAD 0.18µm SCL18SL (Rev 2023.01)
   - Readme Document of SCL 180nm PDK Version 3.0 (SCLPDKV3.0, Dec 2023)
   - Both documents list available IO pads and voltage domains but **do not mandate POR usage**

---

## Conclusion

The SCL-180 reset pad (PC3D21) is a **simple CMOS input buffer** that requires:

- ✅ **No internal enable**
- ✅ **No POR-driven gating**
- ✅ **Asynchronous reset behavior**
- ✅ **Immediate availability after VDD**
- ✅ **No power-up sequencing constraints mandating POR**

An **external reset-only architecture is safe and sufficient** for SCL-180, provided that board-level circuitry asserts and sequences reset correctly during power-up. This is fundamentally different from SKY130, where pad enables were POR-driven and made POR architecturally mandatory.

SCL-180's pad-less POR requirement reflects a **cleaner, simpler IO pad design** that does not couple pad behavior to on-chip analog circuitry, making the design more robust and easier to integrate with external reset supervisors.
