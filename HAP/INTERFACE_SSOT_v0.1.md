# HAP Interface SSOT v0.1

Status: NOMINAL / NOT PHYSICALLY SEALED

This file is the engineering single source of truth for the current Hybrid Adapter Pack geometry. Values remain provisional until physical calibration on the target printer and real parts.

| Interface | Parameter | Nominal value | State |
|---|---|---:|---|
| LEGO-family | pitch | 8.00 mm | reference |
| LEGO-family | plate height | 3.20 mm | reference |
| LEGO-family | body gap | 0.20 mm | nominal |
| LEGO-family | wall | 1.50 mm | nominal |
| LEGO-family | tube OD | 6.50 mm | nominal |
| LEGO-family | tube ID | 4.80 mm | nominal |
| LEGO-family | grid pitch | 8.00 mm | FIXED REFERENCE |
| LEGO-family | clutch contact delta | 0.00 mm | CALIBRATION REQUIRED |
| Technic-family | hole pitch | 8.00 mm | reference |
| Technic-family | hole diameter | 4.90 mm | CALIBRATION REQUIRED |
| GT support | outer support hex, across flats | 46.00 mm | donor-derived nominal |
| GT support | male hex, across flats | 29.78 mm | CALIBRATION REQUIRED |
| GT support | male height | 2.00 mm | nominal |
| GT full tile | full hex, across flats | 59.60 mm | donor-derived nominal |
| GT full tile | point-to-point derived | about 68.82 mm | derived |
| HAP core | core body, across flats | 30.80 mm | prototype |
| HAP core | socket clearance | 0.30 mm | CALIBRATION REQUIRED |
| HAP core | core height | 3.20 mm | prototype |
| HAP full hex | shell height | 5.20 mm | prototype |

## Required physical gates

Gate A — LEGO clutch: keep the 8.00 mm pitch fixed and select the best contact delta from -0.08 / -0.04 / 0.00 / +0.04 / +0.08 mm. Positive is tighter; negative is looser.

Gate B — GT male support: select the best width from 29.60 / 29.70 / 29.78 / 29.86 / 29.96 mm.

Gate C — replaceable core: select the best socket clearance from 0.20 / 0.30 / 0.40 mm using the same core insert.

Gate D — Technic hole: select the best hole diameter from 4.80 / 4.90 / 5.00 / 5.10 mm using real Technic pins.

Gate E — native donor connector: select the best XY scale from 0.996 / 0.998 / 1.000 / 1.002 / 1.004 using the removable connector slot in a real donor tile.

No interface value may be marked SEALED before all five gates have exactly one real tested winner.

## Architectural rule

Functional track geometry, platform geometry and support geometry must remain separated where possible.

GT functional part -> GT/HAP core -> HAP carrier -> LEGO / Technic / GT support

This allows future Snake, Spiral, Crossing, Bridge and Sky modules to reuse the same lower interface without reauthoring their ball path.


## HAP-020 calibration refinement

The earlier coarse LEGO XY-scale method is superseded for production geometry.
Large LEGO footprints must keep the 8.00 mm grid pitch fixed. Fit calibration is
applied only to the inner wall / tube contact geometry through
`LEGO_CLUTCH_DELTA`.

This avoids introducing cumulative grid-position error on 4x4, 6x6 and bridge
carriers.

## Profile seal state

`SEAL_PHYSICAL_PROFILE.ps1` creates a real interface profile only when every
gate has exactly one `PASS` row marked `tested_real=YES`.

Synthetic CI fixture profiles are explicitly marked
`SYNTHETIC_CI_ONLY_DO_NOT_USE_FOR_PRINTING` and are rejected by the physical
pilot builder.
