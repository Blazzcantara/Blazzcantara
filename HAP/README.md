# Hybrid Adapter Pack v0.1 — HAP-002

## Status

**ENGINEERING PROTOTYPE — GENERATED ≠ VALIDATED**

This branch contains the first real parametric calibration pack and the first two LEGO→GraviTrax support prototypes.

Nothing here is claimed as physically validated until the test pieces are printed and checked on real bricks / GraviTrax parts.

## Included

### Calibration
- 5 × 2×2 LEGO-under-clutch variants:
  - 99.6 %
  - 99.8 %
  - 100.0 %
  - 100.2 %
  - 100.4 %
- 5 × GraviTrax male-connector width variants:
  - 29.60 mm
  - 29.70 mm
  - 29.78 mm
  - 29.86 mm
  - 29.96 mm

### First prototypes
- HAP LG 2×2 → GT support
- HAP LG 4×4 → GT support

## First physical gate

Print the clutch tests and GT male tests first.

Do **not** rescale them in the slicer.

Recommended first-pass settings for the Anycubic Kobra S1:
- PLA
- 0.16–0.20 mm layer height
- 3 walls
- normal dimensional compensation / no intentional slicer scaling
- print with LEGO-compatible underside on the bed

Record:
1. which LEGO scale holds firmly without excessive force;
2. which GT male width seats securely without wobble or stress.

Then rebuild the two prototypes using those selected values.

## Nominal starting values

- LEGO pitch: 8.00 mm
- LEGO plate height: 3.20 mm
- GT support outer hex: 46.00 mm across flats
- GT male starting reference: 29.78 mm across flats
- GT male connector height: 2.00 mm

The GT 29.78 mm starting value is a calibration reference, not a sealed production value.

## Build

Windows:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_ALL.ps1

Or use OpenSCAD directly:

    openscad.com -o out.stl -D 'PART="LG4x4_GT"' .\HAP\cad\HAP_MASTER_v0.1.scad

## Next gate after physical fit

After both interface values are known:
- freeze LEGO_SCALE;
- freeze GT_MALE_FLAT;
- generate calibrated 2×2 and 4×4 prototypes;
- derive Full-Hex, Offset and rotatable variants from the same SSOT.
