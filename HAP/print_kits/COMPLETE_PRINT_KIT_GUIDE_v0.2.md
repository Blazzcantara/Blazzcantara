# HAP Complete Direct-Print Kit v0.2

## Goal

This is the first distribution layer where both halves of the original concept
are treated as one build system:

    printable LEGO-compatible underbuild
                  ↓
          HAP adapter / carrier
                  ↓
          HAP core / direct interface
                  ↓
               GraviTrax

LEGO Technic remains intentionally separate.

## Part families

### Printable LEGO-compatible structure
Use these for height, foundations and load distribution:
- BRICK
- PLATE
- RISER
- TOWER
- FOUNDATION / BRIDGE SUPPORT / PLATFORM BLOCK

### HAP direct adapters
Use when the printed LEGO structure should connect directly to GraviTrax:
- HAP_LG2x2_to_GT
- HAP_LG4x4_to_GT
- HAP_BRIDGE_DUAL_GT

### HAP modular carriers
Use when you want replaceable HAP cores:
- HAP_FULL_HEX_6x6
- HAP_SKY_CORE
- HAP_BRIDGE_DUAL_CORE
- HAP_DUAL_FOOT_CORE
- HAP_CROSS_OUTRIGGER_CORE

### HAP cores
- HAP_GT_CORE_nominal: normal GraviTrax-facing core
- HAP_GT_CORE_BLANK: blank insert for later custom functions

## Recommended print sequence

Do not print the entire 51/53-part ecosystem first.

### Round A — basic construction
- 2x Brick 2x4
- 2x Brick 2x8
- 2x Plate 6x6
- 1x Plate 8x8
- 2x Riser 2x2 H3
- 1x Foundation 6x6

### Round B — HAP interface
- 1x LG4x4 to GT direct adapter
- 1x Full Hex 6x6 socket 0.30
- 2x GT Core nominal
- 1x Sky Core 4x4

### Round C — bridge / height
- 2x Bridge Support 4x8 H3
- 1x Bridge Dual Core S32
- 1x Tower 2x2 H10
- 1x Cross Outrigger S40

This gives a useful construction inventory before printing every optional variant.

## Nominal direct-print dimensions

Because the physical fit campaign was intentionally skipped, this package uses:
- LEGO grid pitch: 8.00 mm
- LEGO clutch delta: 0.00 mm
- LEGO structural stud delta: 0.00 mm
- GT male flat: 29.78 mm
- HAP core clearance: 0.30 mm
- Native connector: scale 1.000 when privately supplied

## Native connector

The public/repository CI cannot reconstruct or redistribute the original donor
mesh. BUILD_COMPLETE_PRINT_KIT.ps1 therefore supports two modes:

1. without NativeConnectorZip
   -> 51 STL, explicit NO_NATIVE package name
2. with the user's private native connector ZIP
   -> 53 STL complete no-Technic package

No donor mesh is reconstructed or invented.

## Reality state

Digital geometry validation does not prove physical clutch force. These are
nominal direct-print candidates because the fit-test phase was intentionally
skipped.
