# HAP LEGO Structural Pack v0.1

## Purpose

This pack completes the missing lower half of the HAP concept:

    printable LEGO-compatible structure
                 ↓
             HAP adapter
                 ↓
             GraviTrax

The pack is original parametric compatibility geometry. It is not an official
LEGO product.

## Interface contract

Nominal geometry:
- grid pitch: 8.00 mm
- plate body height: 3.20 mm
- brick body height: 9.60 mm
- top stud diameter: 4.80 mm
- top stud height: 1.80 mm
- outside gap: 0.20 mm
- underside wall: 1.50 mm
- underside tube OD: 6.50 mm
- underside tube ID: 4.80 mm

The same 8.00 mm grid contract used by HAP remains fixed. Fit tuning is isolated
to contact geometry through LEGO_CLUTCH_DELTA and LEGO_STUD_DELTA.

## Families

### 01 Bricks
Five standard stackable blocks:
- 2x2
- 2x4
- 2x6
- 2x8
- 4x4

### 02 Plates
Six low-profile stackable plates:
- 2x2
- 2x4
- 4x4
- 4x6
- 6x6
- 8x8

### 03 Risers
Five one-piece height modules. These replace stacks of many individual bricks
when the goal is simply to raise a GraviTrax support quickly.

### 04 Towers
Three tall one-piece columns for high track levels.

### 05 HAP supports
Six larger bases / piers sized for common HAP support roles.

## Recommended direct-print starter set

The generated starter ZIP contains 12 parts:
- Brick 2x2
- Brick 2x4
- Brick 2x8
- Plate 4x4
- Plate 6x6
- Plate 8x8
- Riser 2x2 H2
- Riser 2x2 H3
- Riser 2x4 H3
- Tower 2x2 H10
- Foundation 6x6 H1
- Bridge Support 4x8 H3

This set is intended to provide immediate structural variety without printing all
25 parts.

## How it connects to the existing HAP parts

Examples:

    HAP_LEGO_BRICK_2x4
          ↓ studs
    HAP_LG4x4_to_GT
          ↓
       GraviTrax

or:

    HAP_LEGO_TOWER_2x2_H10
          ↓
    HAP_LEGO_PLATE_6x6
          ↓
    HAP_FULL_HEX_6x6
          ↓
      HAP_GT_CORE
          ↓
       GraviTrax

or:

    two / more structural supports
          ↓
    HAP_BRIDGE_DUAL_CORE
          ↓
       HAP cores
          ↓
      GraviTrax bridge

## Printing

The geometry is designed for upright support-free printing with the open
anti-stud cavity on the build plate and studs pointing upward.

Recommended starting point for the current Anycubic workflow:
- 0.4 mm nozzle
- 0.16–0.20 mm layer height
- 3–4 walls
- 15–25% infill
- supports off
- model scale exactly 100%

Tall towers benefit from a brim if bed adhesion is marginal.

## Reality state

Every generated STL must pass:
- one positive printable solid shell
- watertight topology
- zero degenerate triangles
- unique SHA-256 payload

That proves digital mesh integrity, not real clutch force. The current direct
print path intentionally uses nominal fit values.
