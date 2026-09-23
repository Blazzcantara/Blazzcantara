# HAP Donor Batch & QA Guide v0.1

Status: IMPLEMENTED / PHYSICAL VALIDATION STILL REQUIRED

This guide covers HAP-014 through HAP-016.

## HAP-014 — Recipe Profiles

Each donor has a matching row in DONOR_RECIPES_v0.1.csv.

The recipe controls:
- mount style;
- X/Y/Z mount offset;
- mount rotation;
- priority;
- risk class;
- rolling-test order;
- recipe state.

The first recipe set is intentionally conservative: all offsets and rotations start at zero because the audited donor tiles share a consistent nominal tile envelope. These values are not sealed until rendered and physically checked.

## HAP-015 — Batch Conversion

Use BUILD_DONOR_BATCH.ps1 to process all conversion-ready donors from the local lego-umbau.zip archive.

Dry-run preflight:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_DONOR_BATCH.ps1 ^
      -ArchivePath "C:\Path\To\lego-umbau.zip" ^
      -DryRun

Full local batch:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_DONOR_BATCH.ps1 ^
      -ArchivePath "C:\Path\To\lego-umbau.zip"

Optional selected donors:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_DONOR_BATCH.ps1 ^
      -ArchivePath "C:\Path\To\lego-umbau.zip" ^
      -DonorIds SHOW-ST01,SHOW-CV01,SHOW-SC01

A full batch creates:
- one converted STL per eligible donor;
- one attribution receipt per donor;
- one JSON evidence receipt per donor;
- DONOR_BATCH_PREFLIGHT.csv;
- DONOR_BATCH_MANIFEST.csv;
- DONOR_BATCH_MANIFEST.json;
- SHA256SUMS.txt;
- DONOR_BATCH_SUMMARY.md;
- HAP_DONOR_BATCH_v0.1.zip.

## HAP-016 — QA & Smoke Test

CI and BUILD_ALL.ps1 use an original synthetic donor fixture to verify the external-conversion path without redistributing any third-party donor mesh.

The smoke gate verifies:
- external STL import;
- HEX mount fusion;
- HEX_REINFORCED mount fusion;
- RECT mount fusion;
- non-empty STL outputs.

This proves converter geometry generation only. It does not prove donor contact quality, LEGO/GT fit or ball-path performance.

## Reality-state ladder

REFERENCE_ONLY
-> RECIPE_ASSIGNED
-> HASH_VERIFIED
-> CAD_CONVERTED
-> BUILD_PASS
-> FIT_PASS
-> ROLL_TEST_PASS
-> PHYSICAL_PASS

No donor derivative may skip the physical fit and rolling regression gates.

## Recommended first real batch

Start with the lowest-risk sequence:
1. SHOW-ST01 Straight
2. SHOW-CV01 Large curve
3. SHOW-SC01 S-curve

Do not start the first physical campaign with Loop, Spiral or Whoopy because those have higher dynamic loading and make interface problems harder to diagnose.
