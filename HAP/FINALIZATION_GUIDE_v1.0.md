# HAP Finalization Guide v1.0

Status: DIGITAL FINALIZATION PIPELINE IMPLEMENTED / PHYSICAL EVIDENCE PENDING

This guide covers HAP-023 through HAP-033.

## HAP-023 — Physical Test Operator

Use CHECK_PHYSICAL_PROGRESS.ps1 with a working copy of
calibration/PHYSICAL_RESULTS_TEMPLATE_v0.1.csv.

Example:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\CHECK_PHYSICAL_PROGRESS.ps1 ^
      -ResultsCsv .\HAP\calibration\my_physical_results.csv

Exit code 0 means all five interface gates have exactly one real winner.
Exit code 2 means the calibration is still incomplete.

## HAP-024 — Straight / Curve / S-Curve pilot

After creating the real PHYSICAL_PROFILE_v0.1.json, fill
pilot/PILOT_RESULTS_TEMPLATE_v0.1.csv.

Each module needs:
- at least 10 runs;
- every run successful;
- connector fit PASS;
- HAP core fit PASS;
- lateral rigidity PASS;
- track clearance PASS;
- tested_real=YES;
- result=PASS;
- a physical-test note.

Then run VALIDATE_PHYSICAL_PILOT.ps1.

## HAP-025 / HAP-030 — Structural seal

All 11 structural production parts have explicit physical rows:
- three Sky supports;
- three Bridge variants;
- two dual-foot supports;
- one cross-outrigger;
- two Technic side-core supports.

Every row must pass vertical load, lateral rigidity, twist and crack-free checks.

## HAP-026..029 — Show-module promotion

After the first three-module pilot passes, test:
- Crossing;
- Spiral-to-Fall;
- Loop;
- Whoopy Jump;
- Solenoid S-Curve.

Each needs at least 10/10 successful runs and all fit / rigidity / clearance gates.

VALIDATE_SHOW_PROMOTION.ps1 creates SHOW_PROMOTION_RECEIPT_v0.1.json.

## HAP-031 — Release consolidation

The final builder creates a clean release tree and excludes:
- calibration coupons;
- smoke-test STL files;
- synthetic CI fixtures;
- unvalidated Snake content.

The final production set contains 38 STL files:
- 11 core adapters / offsets;
- 11 structural parts;
- 2 native connector parts;
- 8 physically promoted show tiles;
- 6 fallback donor mounts.

## HAP-032 — Final audit

FINAL_RELEASE_AUDIT.ps1 requires:
- a real physical profile;
- PHYSICAL_PILOT_PASS;
- STRUCTURAL_PHYSICAL_PASS;
- SHOW_MODULES_PHYSICAL_PASS;
- exactly 38 final STL files;
- 38 matching manifest rows;
- no calibration / smoke / synthetic files in the final release;
- matching SHA-256 values.

## HAP-033 — Final release

BUILD_FINAL_RELEASE.ps1 is the only path that may create:

    HAP_FINAL_v1.0.0.zip

Example:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_FINAL_RELEASE.ps1 ^
      -ArchivePath "C:\Path\To\lego-umbau.zip" ^
      -PhysicalProfileJson ".\HAP\calibration\PHYSICAL_PROFILE_v0.1.json" ^
      -PilotReceiptJson ".\HAP\pilot\PILOT_PROMOTION_RECEIPT_v0.1.json" ^
      -StructuralReceiptJson ".\HAP\structural\STRUCTURAL_SEAL_RECEIPT_v0.1.json" ^
      -ShowReceiptJson ".\HAP\show\SHOW_PROMOTION_RECEIPT_v0.1.json"

The builder verifies evidence linkage, rebuilds the selected HAP geometry, extracts
only the eight physically promoted donor tiles from the user's local archive,
verifies their registered SHA-256 values, performs the final audit, creates a
release seal and writes the final ZIP SHA-256.

## Hard stop

The final ZIP cannot be truthfully produced before the real physical evidence
exists. CI may prove that the gates work, but synthetic CI fixtures are
explicitly prohibited from reaching BUILD_FINAL_RELEASE.ps1.
