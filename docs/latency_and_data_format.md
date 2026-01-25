# Latency and Data Format

This document describes the processing latency and data representation
used by the Stereo FIR AXI Filter.

---

## Processing Latency

- Latency: **1 clock cycle**
- Measured from valid AXI-Stream input (`s_axis_tvalid`)
  to valid AXI-Stream output (`m_axis_tvalid`)
- Identical latency for both Left and Right channels
- Deterministic and independent of tap count

> Note: The FIR core uses a transposed-form architecture, allowing
> constant latency regardless of the number of taps.

---

## Data Format

- Fixed-point representation: **signed Q1.15**
- AXI-Stream data width: **32-bit**
  - `[31:16]` → Left channel
  - `[15:0]`  → Right channel

- Internal accumulation is performed at higher precision
  and normalized before output.

---

## Stereo Behavior

- Left and Right channels are processed synchronously
- Each channel has its own FIR core instance
- Coefficients are **shared** between channels
- No cross-channel interaction or mixing

---

## Notes

- FIR coefficients are interpreted as signed Q1.15 values
- Saturation logic prevents arithmetic wrap-around
- Output samples are aligned and phase-consistent
  between Left and Right channels
