# HAP Physical Calibration — Anycubic Kobra S1 Starting Profile v0.1

Status: STARTING PROFILE / NOT PHYSICALLY SEALED

Use the same material, nozzle and slicer family that you intend to use for the final adapters. Changing material after calibration can change fit.

## Recommended dimensional-calibration settings

- nozzle: 0.4 mm
- layer height: 0.16 mm
- first layer: 0.20 mm
- walls/perimeters: 4
- top layers: 5
- bottom layers: 5
- infill: 20–25% gyroid or equivalent isotropic pattern
- model scale: exactly 100%
- XY compensation / hole compensation: disabled
- elephant-foot compensation: disabled for the calibration campaign
- adaptive scaling / shrink compensation: disabled unless it is also part of the intended production profile
- supports: off for the calibration coupons
- brim: normally off; use only if adhesion requires it
- seam: place away from mating faces where the slicer allows it

Use filament-manufacturer temperatures rather than hard-coded HAP temperatures.

## Why supports stay off

The fit gate must measure the geometry produced by the normal production process. In particular, the Technic coupon contains horizontal pin holes. Adding support inside those holes can change their effective diameter and contaminate the calibration result.

## Print strategy

Do not print all 23 calibration STLs immediately.

Start with only five active candidates:
1. LEGO delta 0.00
2. GT male 29.78
3. HAP core socket 0.30 plus the single nominal core reference
4. Technic hole 4.90
5. Native connector scale 1.000

If a candidate is too tight or too loose, use NEXT_CALIBRATION_TEST.ps1 to select the next directional candidate.

This often reduces the real campaign from 23 possible STLs to roughly 6–12 prints.

## Measurement discipline

- let parts cool to room temperature before judging fit;
- use the same physical LEGO / GraviTrax / Technic reference parts throughout a gate;
- insert straight, without twisting aggressively;
- do not force a candidate that produces visible stress whitening or cracking;
- record both insertion force and wobble consistently on the 1–5 scale;
- repeat a promising fit several times before marking PASS.

A PASS is a physical engineering observation, not an automatic slicer result.
