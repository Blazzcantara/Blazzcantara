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
| LEGO-family | XY scale | 1.000 | CALIBRATION REQUIRED |
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

Gate A — LEGO clutch: select the best printed XY scale from 0.996 / 0.998 / 1.000 / 1.002 / 1.004.

Gate B — GT male support: select the best width from 29.60 / 29.70 / 29.78 / 29.86 / 29.96 mm.

Gate C — replaceable core: select the best socket clearance from 0.20 / 0.30 / 0.40 mm using the same core insert.

Gate D — Technic hole: select the best hole diameter from 4.80 / 4.90 / 5.00 / 5.10 mm using real Technic pins.

No interface value may be marked SEALED before the applicable tests.

## Architectural rule

Functional track geometry, platform geometry and support geometry must remain separated where possible.

GT functional part -> GT/HAP core -> HAP carrier -> LEGO / Technic / GT support

This allows future Snake, Spiral, Crossing, Bridge and Sky modules to reuse the same lower interface without reauthoring their ball path.
