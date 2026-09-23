# HAP Structural Validation Matrix v0.1

Status: NOMINAL / PHYSICAL TEST REQUIRED

This matrix covers HAP-006 Sky supports and HAP-007 Bridge carriers. These parts intentionally reuse the same provisional LEGO clutch, GT male and HAP core interfaces. A successful CI build proves only that printable meshes were generated, not that the structures are physically load-safe.

## HAP-006 Sky Core Caps

| File | LEGO fit | Core fit | Vertical rigidity | Lateral rigidity | Result |
|---|---|---|---|---|---|
| HAP_SKY_CORE_2x4_v0.1.stl | | | | | |
| HAP_SKY_CORE_4x4_v0.1.stl | | | | | |
| HAP_SKY_CORE_4x6_v0.1.stl | | | | | |

Recommended test:
- build a LEGO column 8–12 bricks high;
- fit the adapter without glue;
- mount the calibrated GT core;
- apply gentle hand load from four horizontal directions;
- reject any geometry that rocks, cracks or self-releases.

## HAP-007 Bridge Carriers

| File | LEGO fit | Socket/GT fit | Twist | Deck sag | Result |
|---|---|---|---|---|---|
| HAP_BRIDGE_DUAL_CORE_8x4_S32_v0.1.stl | | | | | |
| HAP_BRIDGE_DUAL_CORE_10x4_S40_v0.1.stl | | | | | |
| HAP_BRIDGE_DUAL_GT_8x4_S32_v0.1.stl | | | | | |

Recommended test:
- support the carrier on a rigid LEGO deck or wide pillar;
- fit two interfaces;
- add the intended track/bridge element;
- inspect twist before adding a ball;
- run a marble only after static fit is stable.

## Gate rule

HAP-006/HAP-007 may be marked BUILD_PASS after CI produces all expected STLs.

They may be marked PHYSICAL_PASS only after:
1. LEGO clutch calibration is sealed;
2. GT male calibration is sealed;
3. replaceable-core clearance is sealed where applicable;
4. the structural checks above pass.

Show-module donor conversions remain locked until these interface gates are complete.
