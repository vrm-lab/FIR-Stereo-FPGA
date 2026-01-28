# Design Rationale

This document explains several architectural design choices made in the
Stereo FIR AXI reference design.

The intent is to clarify **why certain decisions were made**, not to
impose limitations on future extensions.

---

## FIR Tap Count Selection (129 Taps)

The default implementation uses **129 FIR taps**.

This choice is intentional and motivated by several practical reasons:

- **Odd tap count**
  - Allows symmetric linear-phase FIR designs with a clear center tap
  - Commonly used in audio FIR filters (e.g., low-pass, high-pass)

- **Representative complexity**
  - Large enough to demonstrate:
    - Deep FIR pipelines
    - Accumulator growth
    - Coefficient memory access
  - Small enough to remain:
    - Simulation-friendly
    - Synthesis-friendly on mid-range devices

- **Architecture-driven, not algorithm-driven**
  - The FIR core is fully parameterizable
  - 129 taps serves as a realistic default, not a hard requirement

The tap count can be reduced or increased by changing the `NTAPS` parameter
in the RTL and regenerating the AXI IP.

---

## AXI-Lite Address Width Considerations

The AXI-Lite interface maps FIR coefficients as a linear memory space:

- Each tap occupies **one 32-bit AXI-Lite word**
- Address stride: **4 bytes per tap**

With the current address width configuration:

- Up to **256 taps** can be addressed safely
- This corresponds to:

0x10 + 4 × (256 − 1) = 0x40C

If a design requires **more than 256 taps**:

- The AXI-Lite address width (`C_S_AXI_ADDR_WIDTH`) must be increased
- No architectural changes are required beyond address decoding
- FIR core logic itself is not affected

This keeps the design scalable without complicating the default configuration.

---

## No Built-In Coefficient Generator

This repository **does not include**:
- Python-based coefficient generators
- MATLAB scripts for FIR design
- Windowing or frequency-domain design utilities

This is a deliberate design decision.

### Rationale

- The primary focus of this repository is:
- **Hardware architecture**
- **AXI-based system integration**
- **Deterministic DSP behavior**

- FIR coefficient generation is:
- A well-established problem
- Highly application-specific
- Better handled by external tools (Python, MATLAB, SciPy, etc.)

Including a coefficient generator would:
- Shift focus away from the hardware design
- Create unnecessary coupling to specific DSP workflows
- Increase maintenance burden without improving architectural clarity

---

## Intended Usage Model

Users are expected to:
1. Design FIR coefficients using their preferred tools
2. Quantize coefficients to signed **Q1.15**
3. Load coefficients via AXI-Lite at runtime

This approach keeps the repository:
- Tool-agnostic
- Architecture-centric
- Easy to adapt for different applications

---

## Summary

- **129 taps** is a practical default, not a limitation
- The AXI-Lite interface is scalable beyond 256 taps if required
- FIR coefficient generation is intentionally left to the user
- The repository emphasizes **architecture over algorithm design**
