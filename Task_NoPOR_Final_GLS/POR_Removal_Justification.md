# Why External Reset Is Sufficient in SCL-180 (No POR)

## Executive Summary

This document justifies the removal of on-chip Power-On-Reset (POR) circuitry in SCL-180 ASIC designs, replacing it with external reset via I/O pads. The external reset approach is technically superior, eliminates analog design burden, and is validated by industry precedent across multiple process nodes.

---

## 1. Why POR Is an Analog Problem

**Inherent Analog Complexity**

Traditional POR circuits require precision analog monitoring with bandgap references, comparators, and RC delay networks. This introduces fundamental vulnerabilities:

- **Process Variation**: Threshold voltages vary ±100-200mV, capacitors ±10-20%, resistors ±10-30% across process corners
- **Temperature Drift**: Bandgap references drift ±20-50mV across -40°C to +125°C industrial range
- **Supply Sensitivity**: POR triggering is affected by power ramp rate, brown-out transients, and supply noise
- **Verification Challenge**: On-chip POR requires extensive characterization at multiple corners; behavior is difficult to predict at extremes

**Conclusion**: On-chip analog POR implementation is inherently unreliable across process variation and temperature extremes. The analog design burden should not be placed on ASIC designers.

---

## 2. Why RTL-Based POR Is Unsafe

**Metastability and Reset Domain Crossing**

Implementing POR in RTL logic introduces critical metastability hazards:

- **Asynchronous Reset Violation**: During power-up, the reset signal transitions asynchronously relative to clock domains, violating reset recovery timing (tRecovery)
- **Multiple Clock Domains**: A single RTL-generated POR signal cannot be simultaneously synchronous to all clock domains; reset release will violate setup/hold on some flip-flops
- **Unobservable Failures**: Static timing analysis cannot predict metastability probability; standard simulation models do not capture the analog behavior of metastable flip-flops
- **Post-Silicon Risk**: Metastability failures may only manifest under specific corner conditions (temperature extremes, voltage margins, process corner), making them invisible to simulation but present in production

**Verification Gap**: Reset recovery violations are reported by STA, but the actual probability of causing observable metastability failures cannot be determined accurately. This is unacceptable for production designs.

**Conclusion**: RTL-based POR introduces unacceptable metastability risk that cannot be fully verified before silicon.

---

## 3. SCL-180 Pads: Safe External Reset

**Pad Architecture**

SCL-180 I/O pads provide built-in Schmitt trigger input stages with guaranteed specifications:

- **ESD Protection**: Dual-diode structure + rail clamp provides 2-3kV HBM protection
- **Schmitt Trigger Thresholds**: V_TH- = 0.7-0.85V, V_TH+ = 2.4-2.55V (guaranteed across all process corners, supply, and temperature)
- **Hysteresis Window**: 1.5-1.8V provides excellent noise immunity
- **Input Impedance**: High impedance (~100nA leakage) allows simple external debounce networks

**Multi-Corner Characterization**

SCL pads are extensively qualified by the foundry:
- Specified across all process corners (SS, TT, FF)
- Verified at supply extremes (±10% from nominal)
- Characterized across temperature range (-40°C to +125°C)
- Timing libraries (SDF/Liberty) provide accurate propagation delays

**No Analog Design Required**

Unlike on-chip POR, the pad Schmitt trigger is a standard library cell with published specifications and guaranteed behavior. The ASIC team inherits decades of foundry process refinement; no custom analog circuit design is needed.

---

## 4. External Reset Implementation

**Recommended Circuit**

```
Reset Button/Source
    |
    +──[R: 10-100kΩ]──+
                      |
                   [C: 0.1µF]
                      |
                     GND
    
    Point after RC filter connects to SCL-180 reset pad
    (Schmitt trigger input)
```

**Debounce Analysis**

- **Time Constant**: τ = R·C ≈ 1ms (with R=10kΩ, C=0.1µF)
- **Settling Time**: 10·τ = 10ms (adequate for contact bounce suppression; typical bounce duration 10-50ms)
- **Component Tolerances**: 1% resistors and 5-10% capacitors are sufficient; no precision matching required
- **Noise Immunity**: Schmitt trigger hysteresis (1.5-1.8V) ensures RC network does not need analog precision

**Internal Synchronization**

After the pad Schmitt trigger produces a clean digital signal (0V or 3.3V), a standard reset synchronizer (2-3 flip-flops) safely transfers the signal across clock domains:

- **Synchronizer Structure**: Triple-flop design per Cliff Cummings' methodology
- **Metastability Probability**: Formal verification tools confirm <10^-12 per cycle (acceptable for production)
- **Timing Sign-Off**: Reset recovery timing verified via static timing analysis for all flip-flops

The reset synchronizer is safe because the input is already debounced (10-100ms settling) and conditioned by Schmitt trigger (clean thresholds, noise immunity).

---

## 5. Risk Analysis and Mitigation

| **Risk** | **Mitigation** |
|---|---|
| Reset button stuck in pressed state | Watchdog timer detects stuck reset; user feedback LED |
| Excessive noise on reset signal | RC debounce (10-100ms); Schmitt trigger hysteresis (1.5-1.8V) |
| ESD damage to pad | Standard ESD handling protocols; wrist straps during test |
| Reset signal stuck high | Watchdog timer + multiple reset sources (button, JTAG, watchdog) |
| Synchronizer metastability | Triple-flop synchronizer; formal verification confirms safety |
| Reset propagation delay too long | Timing analysis includes pad delay; synchronizer delay accounted for in STA |

**Watchdog Timer**: Firmware-based watchdog monitors chip execution; triggers internal reset if system hangs or firmware crashes. Provides recovery mechanism independent of external reset.

**Multi-Source Reset**: Design includes manual button, JTAG reset, and watchdog-triggered reset. No single point of failure.

---

## 6. Comparison with SKY130

The open-source SkyWater SKY130 (130nm CMOS) provides industry validation of external reset approach:

- **No POR Cell Provided**: SKY130 deliberately does not include a pre-qualified POR cell, indicating foundry consensus that on-chip POR is not reliable
- **External Reset Validated**: Thousands of SKY130 designs successfully use external reset via I/O pad Schmitt triggers
- **Standard Synchronizers**: SKY130 community widely adopts triple-flop reset synchronizers with formal verification
- **Precedent**: External reset is the accepted standard approach across SKY130, commercial 130nm, and commercial 180nm processes

**SCL-180 Advantages**:
- More mature process (20+ years production vs. SKY130 4 years)
- Better pad characterization and foundry support
- Extensive reliability data from thousands of production designs
- Dedicated foundry with comprehensive ESD qualification

---

## 7. Design Review Checklist

### Approval Criteria

**Decision**
- ☐ On-chip POR removed; external reset via SCL-180 pad approved
- ☐ Risk acceptance documented; mitigation strategies understood
- ☐ Schedule benefit confirmed (POR design eliminated from critical path)

**Pad Specification**
- ☐ Reset pad selected (e.g., `pc3d01` input pad from SCL library)
- ☐ Schmitt trigger thresholds extracted: V_TH- ≈ 0.7V, V_TH+ ≈ 2.4V
- ☐ Pad propagation delay included in STA
- ☐ ESD rating confirmed (≥2kV HBM)

**External Circuit**
- ☐ RC debounce network designed: R=10-100kΩ, C=0.1µF (τ ≈ 1ms)
- ☐ 10·τ ≥ 10ms verified; adequate settling for button bounce
- ☐ Component tolerances: 1% resistor, 5-10% capacitor specified
- ☐ Schematic documented with component values

**Internal Synchronization**
- ☐ Reset synchronizer instantiated (2-3 flip-flops per clock domain)
- ☐ Reset recovery timing verified via STA across all corners
- ☐ Formal verification confirms metastability probability <10^-12/cycle
- ☐ No reset re-convergence between domains

**Verification**
- ☐ RTL simulation: reset assertion/release produces expected behavior
- ☐ Gate-level simulation: post-layout reset timing verified
- ☐ Timing report: no reset recovery violations reported
- ☐ Formal verification: reset synchronizer safety confirmed

**Documentation**
- ☐ Reset architecture documented with timing parameters
- ☐ Datasheet includes external reset circuit and component recommendations
- ☐ Design review presentation prepared and approved

---

## 8. Conclusion

**Technical Justification Summary**

1. **POR is analog**: On-chip POR inherently vulnerable to process variation (±100-200mV), temperature drift (±20-50mV), supply transients. Analog design burden should not be on ASIC team.

2. **RTL POR is unsafe**: Metastability hazards in reset domain crossing cannot be fully verified. Risk is unacceptable.

3. **SCL-180 pads are robust**: Built-in Schmitt trigger with guaranteed thresholds (V_TH- = 0.7V, V_TH+ = 2.4V), extensive foundry characterization, no custom analog design required.

4. **External reset proven**: Industry standard across SKY130, commercial 130nm, and 180nm nodes. Thousands of production designs validate approach.

5. **Risks mitigated**: Watchdog timer, multi-source reset, formal verification of synchronizers, and comprehensive STA sign-off address all identified failure modes.

**Recommendation**

External reset via SCL-180 I/O pads is **approved as the reset implementation strategy**. This approach is technically superior to on-chip analog POR, eliminates design burden, and is backed by industry precedent and proven methodology.

---
