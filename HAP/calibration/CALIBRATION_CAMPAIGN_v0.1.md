# HAP-020 Physical Calibration Campaign v0.1

Status: READY_TO_PRINT / NO INTERFACE VALUE SEALED

The goal is to seal five fit-critical interfaces with the smallest practical number of prints.

## Important LEGO calibration change

The original coarse XY-scale approach is superseded for production parts.

The LEGO grid pitch stays fixed at 8.00 mm. Calibration now changes only contact geometry through `LEGO_CLUTCH_DELTA`:

- negative delta = looser;
- zero = nominal;
- positive delta = tighter.

This prevents large 4x4 / 6x6 / bridge parts from accumulating pitch error.

## Print order

Stage A — LEGO clutch:
- -0.08 mm
- -0.04 mm
- 0.00 mm
- +0.04 mm
- +0.08 mm

Stage B — GT male:
- 29.60 / 29.70 / 29.78 / 29.86 / 29.96 mm

Stage C — HAP core socket:
- 0.20 / 0.30 / 0.40 mm
- use the same nominal HAP core for all three coupons
- the new compact socket coupons replace the need to print three full 6x6 platforms

Stage D — Technic pin:
- 4.80 / 4.90 / 5.00 / 5.10 mm

Stage E — native donor connector:
- 0.996 / 0.998 / 1.000 / 1.002 / 1.004

## Recording results

Copy `PHYSICAL_RESULTS_TEMPLATE_v0.1.csv` and edit the copy.

For the winning candidate of each gate:
- set `result=PASS`;
- set `tested_real=YES`;
- record force / wobble ratings;
- add a short note about the physical test.

Other tested candidates can be marked `FAIL`.

Exactly one PASS per gate is required before the seal script will create a real physical profile.

## Reality rule

A sealed interface profile means the five interface values were physically selected.

It does NOT mean:
- structural Sky / Bridge tests passed;
- the Straight / Curve / S-Curve rolling pilot passed;
- all show modules are release-ready.
