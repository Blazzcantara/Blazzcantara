# Hybrid Adapter Pack v0.1 — HAP-002..005

## Status

**ENGINEERING PROTOTYPE — GENERATED != PHYSICALLY VALIDATED**

This branch extends the first calibration baseline into a modular LEGO→GraviTrax architecture.

## Implemented

### HAP-002 — Calibration + direct supports
- 5 LEGO clutch calibration variants
- 5 GT male-interface calibration variants
- 2×2 LEGO→GT direct support
- 4×4 LEGO→GT direct support

### HAP-003 — Full Hex Platform
- 6×6 LEGO underside
- full GraviTrax-size hex shell
- lightweight transition body
- center socket for replaceable cores
- 3 socket-clearance variants: 0.20 / 0.30 / 0.40 mm

### HAP-004 — Replaceable Core
- GT male core insert
- blank core insert
- removable interface concept
- dedicated physical-fit matrix

### HAP-005 — Offset / Orientation Family
- centered full-hex carrier
- X +4 mm offset
- X -4 mm offset
- X +8 mm offset
- Y +4 mm offset
- 30° full-tile orientation variant
- lightweight 4×4 direct-offset prototype

## Interface SSOT

See INTERFACE_SSOT_v0.1.md.

Important nominal values:
- LEGO pitch: 8.00 mm
- LEGO plate height: 3.20 mm
- GT support outer hex: 46.00 mm across flats
- GT full tile: 59.60 mm across flats
- GT male starting reference: 29.78 mm across flats
- HAP core: 30.80 mm across flats

All fit-critical values remain provisional until printed.

## Physical validation order

1. Print LEGO clutch calibration.
2. Print GT male calibration.
3. Select one winner for each interface.
4. Print one GT core and the 0.20 / 0.30 / 0.40 Full-Hex socket variants.
5. Select the best removable-core clearance.
6. Rebuild the 4×4 support and Full-Hex platform with sealed values.
7. Only after that unlock Snake / Spiral / Crossing / Bridge donor conversions.

Use PHYSICAL_TEST_MATRIX_v0.1.md to record results.

## Windows build

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_ALL.ps1

The script installs OpenSCAD through winget when it cannot find it, builds all calibration and nominal prototype STLs, verifies output presence and creates a ZIP package.

## Architecture

    GT functional module
            |
       GT/HAP core
            |
       HAP carrier
        /   |   \
     LEGO Technic GT

The full-hex carrier can therefore be reused while only the center core or lower support changes.

## Reality state

- Parametric CAD: IMPLEMENTED
- Automated STL generation definition: IMPLEMENTED
- Interface SSOT: IMPLEMENTED
- Physical LEGO clutch: NOT VALIDATED
- Physical GT fit: NOT VALIDATED
- Replaceable core fit: NOT VALIDATED
- Show-module conversion: LOCKED pending fit gate
