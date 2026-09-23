# Hybrid Adapter Pack v0.1 — HAP-002..013

## Status

**ENGINEERING PROTOTYPE — GENERATED != PHYSICALLY VALIDATED**

The pack now covers LEGO clutch supports, modular GraviTrax cores, offsets, Sky/Bridge structures, Technic side mounting, anti-twist supports and donor-conversion blanks.

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

### HAP-005 — Offset / Orientation Family
- X +4 / -4 / +8 mm and Y +4 mm variants
- 30° full-tile orientation
- lightweight direct offset support

### HAP-006 — Sky Core Support Family
- 2×4, 4×4 and 4×6 LEGO footprints
- replaceable HAP core receiver
- high-rise support use case

### HAP-007 — Bridge / Multi-Anchor Family
- 8×4 dual-core carrier at 32 mm spacing
- 10×4 dual-core carrier at 40 mm spacing
- 8×4 dual direct-GT carrier

### HAP-008 — Technic Structural Interface
- 4 Technic-hole calibration coupons: 4.80 / 4.90 / 5.00 / 5.10 mm
- 3-hole side-mount core bracket
- 5-hole side-mount core bracket
- separate physical gate for Technic pin fit

### HAP-009 — Anti-Twist / Outrigger Family
- dual 2×2 foot support at 32 mm spacing
- dual 2×2 foot support at 40 mm spacing
- cross-outrigger support at 40 mm spacing
- designed for taller LEGO columns and lateral stability

### HAP-010 — Donor Conversion Layer
- hex donor pad
- rectangular donor pad
- compact donor core mount
- donor conversion rules that preserve the functional ball path



### HAP-011 — Donor Registry & License Gate
- 9 donor candidates registered with exact source paths and SHA-256 values
- 8 candidates from the audited CC-Attribution collection are conversion-ready
- Snake remains HOLD_LICENSE because its original license is unconfirmed
- donor identity is verified before conversion

### HAP-012 — Local Donor Conversion Runner
- `BUILD_DONOR_CONVERSION.ps1` extracts only the selected donor from the user's local `lego-umbau.zip`
- exact SHA-256 must match the registry
- OpenSCAD fuses the donor with the appropriate HAP underbody mount
- no donor STL is stored in this GitHub repository
- every generated derivative receives an attribution receipt

### HAP-013 — Show-Module Conversion Gate
- initial candidates: Straight, large curve, S-curve, crossing, spiral-to-fall, loop, Whoopy jump and Solenoid S-curve
- light and reinforced underbody mounts are available
- rolling regression test matrix added
- donor conversions remain GENERATED until real print + marble-run validation passes

## Current automated build

Expected output: **44 STL files**.

Windows:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_ALL.ps1

CI packages the complete result as:

    HAP_v0.1_DONOR_PIPELINE.zip

## Interface SSOT

See INTERFACE_SSOT_v0.1.md.

Fit-critical interfaces remain provisional:
- LEGO clutch scale
- GT male support width
- HAP replaceable-core clearance
- Technic pin-hole diameter

## Physical validation order

1. LEGO clutch calibration.
2. GT male calibration.
3. HAP core clearance calibration.
4. Technic hole calibration.
5. Rebuild selected structural parts with sealed values.
6. Static rigidity tests for Sky / Bridge / Outrigger supports.
7. Only then convert actual Snake / Spiral / Crossing / Curves donor parts.
8. Every converted functional part receives a rolling regression test.

## Documentation

- PHYSICAL_TEST_MATRIX_v0.1.md
- STRUCTURAL_TEST_MATRIX_v0.1.md
- TECHNIC_AND_DONOR_TEST_MATRIX_v0.1.md
- DONOR_CONVERSION_RULES_v0.1.md
- donors/DONOR_REGISTRY_v0.1.csv
- donors/DONOR_ATTRIBUTION_v0.1.md
- donors/DONOR_PIPELINE_v0.1.md
- donors/DONOR_TEST_MATRIX_v0.1.md

## Architecture

    Functional GraviTrax / donor module
                 |
          GT / donor interface
                 |
            HAP core layer
                 |
       carrier / offset / brace
          /       |        \
       LEGO    Technic    GT

## Reality state

- Parametric CAD: IMPLEMENTED
- 41-output build definition: IMPLEMENTED
- LEGO family: GENERATED / NOT VALIDATED
- GT interface: GENERATED / NOT VALIDATED
- HAP core: GENERATED / NOT VALIDATED
- Sky / Bridge family: BUILD-DEFINED / NOT PHYSICALLY VALIDATED
- Technic family: BUILD-DEFINED / NOT PHYSICALLY VALIDATED
- Outrigger family: BUILD-DEFINED / NOT PHYSICALLY VALIDATED
- Donor conversion blanks: IMPLEMENTED
- License-aware donor registry: IMPLEMENTED
- Local hash-checked donor converter: IMPLEMENTED
- Eight CC-Attribution donor candidates: CONVERSION-READY / NOT PHYSICALLY VALIDATED
- Snake donor: HOLD_LICENSE
- Actual printed donor derivatives: NOT YET PHYSICALLY VALIDATED
