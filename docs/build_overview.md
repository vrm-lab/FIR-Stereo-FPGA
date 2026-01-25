# Build Overview

This document describes the high-level build flow for the
Stereo FIR Filter reference design.

---

## Vivado

1. Add RTL sources
   - `fir_core.v` (generic transposed-form FIR)
   - `fir_axis_wrapper.v` (AXI-Stream + AXI-Lite wrapper)

2. Package as custom AXI IP
   - Expose AXI-Stream (audio data path)
   - Expose AXI-Lite (control + coefficient memory)

3. Create block design:
   - Zynq MPSoC (KV260)
   - AXI DMA (MM2S + S2MM)
   - Stereo FIR AXI IP

4. Connect interfaces
   - AXI-Stream:
     - DMA MM2S → FIR input
     - FIR output → DMA S2MM
   - AXI-Lite:
     - PS master → FIR control & coefficient registers

5. Assign AXI-Lite base addresses
   - Control register
   - FIR coefficient memory

6. Generate bitstream

7. Export hardware
   - XSA (include bitstream)

---

## Vitis (Bare-Metal)

1. Create platform project from XSA

2. Create bare-metal application

3. Initialize FIR driver
   - Base address from `xparameters.h`
   - Hardware tap count

4. Load FIR coefficients via AXI-Lite
   - Q1.15 fixed-point format
   - Runtime reconfigurable

5. Enable FIR core

6. (Optional) Reconfigure coefficients on-the-fly
   - FIR core state can be cleared independently

7. Stream stereo audio buffers
   - Data transfer via AXI DMA (polling mode)
   - Left/Right channels processed identically

---

## Notes

- FIR coefficients are shared between Left and Right channels.
- AXI-Lite writes affect coefficient memory immediately.
- Internal FIR pipeline state can be cleared without modifying coefficients.
- The design is suitable for:
  - Static FIR filters
  - Dynamic filter switching
  - Real-time coefficient updates
