# Hybrid Adapter Pack v0.1 — HAP-002..033

## Status

**ENGINEERING PROTOTYPE — GENERATED != PHYSICALLY VALIDATED**

The pack now covers LEGO clutch supports, modular GraviTrax cores, offsets, Sky/Bridge structures, Technic side mounting, anti-twist supports and donor-conversion blanks.

## Implemented

### HAP-002 — Calibration + direct supports
- 5 LEGO clutch calibration variants
- LEGO pitch now remains fixed; contact fit is tuned through LEGO_CLUTCH_DELTA
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



### HAP-014 — Donor Recipe Profiles
- per-donor mount recipe registry
- mount style plus X/Y/Z offsets and rotation
- priority, risk class and rolling-test order
- Snake remains blocked by the license gate

### HAP-015 — Batch Donor Conversion
- one command can preflight or convert all eligible registered donors from the local archive
- batch manifest in CSV + JSON
- per-output SHA-256
- per-donor attribution + evidence receipts
- final local batch ZIP

### HAP-016 — Converter QA / Synthetic Smoke Gate
- original synthetic donor fixture generated in CI
- external import path tested without embedding third-party donor geometry
- HEX / HEX_REINFORCED / RECT fusion paths tested
- local BUILD_ALL.ps1 performs the same geometry smoke gate
- CI report distinguishes geometry PASS from physical PASS



### HAP-017 — Native Removable Connector Intake
- adopts the donor collection's own removable connector as the preferred interface
- exact archive path and SHA-256 are recorded in a dedicated SSOT
- five connector-only XY calibration variants: 0.996 / 0.998 / 1.000 / 1.002 / 1.004
- third-party source mesh remains external to the repository

### HAP-018 — Native Connector → HAP Core Bridge
- five matching core-bridge variants
- donor-facing geometry remains the verified native removable connector
- lower geometry uses the provisional 30.80 mm HAP core
- dependency-free STL connectivity / watertight audit added

### HAP-019 — Straight / Curve / S-Curve Physical Pilot
- first pilot targets SHOW-ST01, SHOW-CV01 and SHOW-SC01
- donor track meshes do not need CAD modification
- selected HAP bridge replaces the collection's normal removable connector
- 10-run rolling regression gate defined before higher-dynamic show modules are promoted
- fused-underbody conversion remains available as a fallback for donor families without a removable interface



### HAP-020 — Physical Calibration Campaign
- LEGO clutch calibration changed from whole-part XY scaling to fixed-pitch contact deltas
- five clutch deltas: -0.08 / -0.04 / 0.00 / +0.04 / +0.08 mm
- three compact HAP core socket coupons replace three full-size calibration platforms
- one-command calibration pack builder creates 23 targeted print parts
- physical results template and staged campaign guide added

### HAP-021 — Physical Interface Profile Seal
- fail-closed profile sealer requires exactly one PASS for each of five gates
- every real winner must be marked tested_real=YES
- physical-test note required for every real winner
- selected values are emitted as a SHA-256-sealed JSON profile
- CI fixture profiles are explicitly synthetic and cannot be used for printing

### HAP-022 — Sealed-Value Physical Pilot Builder
- accepts only a real physically selected interface profile
- rebuilds production candidates with the selected LEGO / GT / core / Technic values
- builds exactly one selected native connector -> HAP core bridge
- outputs a six-STL pilot package for the Straight / Curve / S-Curve system test
- synthetic CI profiles are rejected



### HAP-023 — Physical Test Operator
- progress checker for all five interface gates
- reports incomplete, invalid-multiple-pass and ready-to-seal states

### HAP-024 — First Physical Pilot Promotion
- fail-closed Straight / Large Curve / S-Curve validator
- minimum 10/10 successful runs per module
- real-test notes and fit / rigidity / clearance PASS required

### HAP-025 / HAP-030 — Structural Physical Seal
- all 11 structural production parts represented in the final physical matrix
- vertical load / lateral rigidity / twist / crack-free gates
- structural receipt required for final release

### HAP-026..029 — Advanced Show Promotion
- Crossing / Spiral-to-Fall / Loop / Whoopy / Solenoid S-Curve
- minimum 10/10 successful runs each
- requires passed first physical pilot
- produces a show-promotion receipt

### HAP-031 — Final Release Consolidation
- clean production-only release layout
- calibration / smoke / CI fixture files excluded
- 38 final STL target: 11 core adapters + 11 structural + 2 native connector + 8 show modules + 6 fallback mounts

### HAP-032 — Final Release Audit
- verifies four real evidence states
- verifies exactly 38 STL files and 38 manifest rows
- verifies every final STL SHA-256
- rejects calibration, smoke and synthetic filenames

### HAP-033 — HAP FINAL v1.0.0 Builder
- only accepts real physical profile + pilot + structural + show receipts
- verifies receipt linkage by SHA-256
- rebuilds selected HAP geometry from sealed values
- extracts only eight physically promoted CC-Attribution donor tiles from the local archive
- runs final audit and creates RELEASE_SEAL.txt
- only then creates HAP_FINAL_v1.0.0.zip and its SHA-256 sidecar

## Current automated build

Expected core output: **47 STL files** plus synthetic donor/native-connector smoke outputs.

Windows:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_ALL.ps1

CI packages the complete result as:

    HAP_v0.1_FINALIZATION_GATES.zip

## Interface SSOT

See INTERFACE_SSOT_v0.1.md.

Fit-critical interfaces remain provisional:
- LEGO clutch contact delta (fixed 8.00 mm grid pitch)
- GT male support width
- HAP replaceable-core clearance
- Technic pin-hole diameter

## Physical validation order

1. Build the 23-part physical calibration pack.
2. Select the best LEGO clutch contact delta.
3. Select the best GT male width.
4. Select the best compact HAP core socket clearance.
5. Select the best Technic hole diameter.
6. Select the best native removable-connector scale.
7. Record exactly one real PASS per gate in the physical-results CSV.
8. Seal the physical interface profile.
9. Build the six-part sealed-value physical pilot package.
10. Pilot the native bridge on Straight, Large Curve and S-Curve.
11. Perform static rigidity checks on Sky / Bridge / Outrigger supports.
12. Only after the pilot passes promote Crossing, Spiral, Loop and Whoopy.

## Documentation

- PHYSICAL_TEST_MATRIX_v0.1.md
- STRUCTURAL_TEST_MATRIX_v0.1.md
- TECHNIC_AND_DONOR_TEST_MATRIX_v0.1.md
- DONOR_CONVERSION_RULES_v0.1.md
- donors/DONOR_REGISTRY_v0.1.csv
- donors/DONOR_ATTRIBUTION_v0.1.md
- donors/DONOR_PIPELINE_v0.1.md
- donors/DONOR_TEST_MATRIX_v0.1.md
- donors/DONOR_RECIPES_v0.1.csv
- donors/DONOR_BATCH_QA_GUIDE_v0.1.md
- donors/NATIVE_CONNECTOR_SSOT_v0.1.md
- donors/PILOT_SHOW_MODULES_v0.1.md
- calibration/CALIBRATION_CAMPAIGN_v0.1.md
- calibration/PHYSICAL_RESULTS_TEMPLATE_v0.1.csv
- pilot/PILOT_RESULTS_TEMPLATE_v0.1.csv
- structural/STRUCTURAL_RESULTS_TEMPLATE_v0.1.csv
- show/SHOW_RESULTS_TEMPLATE_v0.1.csv
- FINALIZATION_GUIDE_v1.0.md
- FINAL_RELEASE_GATE_MATRIX_v1.0.md

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
- 47-output core build definition: IMPLEMENTED
- LEGO family: GENERATED / NOT VALIDATED
- GT interface: GENERATED / NOT VALIDATED
- HAP core: GENERATED / NOT VALIDATED
- Sky / Bridge family: BUILD-DEFINED / NOT PHYSICALLY VALIDATED
- Technic family: BUILD-DEFINED / NOT PHYSICALLY VALIDATED
- Outrigger family: BUILD-DEFINED / NOT PHYSICALLY VALIDATED
- Donor conversion blanks: IMPLEMENTED
- License-aware donor registry: IMPLEMENTED
- Local hash-checked donor converter: IMPLEMENTED
- Recipe-driven per-donor mount transforms: IMPLEMENTED
- Batch conversion + manifest + SHA256 evidence: IMPLEMENTED
- Synthetic converter smoke gate: IMPLEMENTED
- Native removable-connector strategy: IMPLEMENTED
- Native connector 5-scale calibration family: IMPLEMENTED
- Native connector → HAP core bridge family: IMPLEMENTED
- Dependency-free STL geometry audit: IMPLEMENTED
- Straight / Curve / S-Curve physical pilot: READY_TO_PRINT / NOT YET PHYSICALLY VALIDATED
- Fixed-pitch LEGO clutch calibration: IMPLEMENTED
- 23-part physical calibration pack builder: IMPLEMENTED
- Five-gate physical profile sealer: IMPLEMENTED
- Six-part sealed-value pilot builder: IMPLEMENTED
- Physical test progress operator: IMPLEMENTED
- First pilot promotion gate: IMPLEMENTED
- 11-part structural seal gate: IMPLEMENTED
- Advanced show-module promotion gate: IMPLEMENTED
- Production-only final release consolidation: IMPLEMENTED
- Fail-closed final audit: IMPLEMENTED
- HAP FINAL v1.0.0 builder: IMPLEMENTED / BLOCKED UNTIL REAL PHYSICAL EVIDENCE
- Eight CC-Attribution donor candidates: CONVERSION-READY / NOT PHYSICALLY VALIDATED
- Snake donor: HOLD_LICENSE
- Actual printed donor derivatives: NOT YET PHYSICALLY VALIDATED
