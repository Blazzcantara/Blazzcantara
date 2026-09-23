# HAP Donor Intake & Conversion Pipeline v0.1

## Scope

This pipeline turns an existing donor STL from the user's local lego-umbau.zip archive into a HAP-compatible local derivative without storing the donor mesh in this repository.

## Stages

1. Look up DONOR_REGISTRY_v0.1.csv.
2. Enforce license_state and conversion_state.
3. Extract only the registered source path from the local ZIP.
4. Verify the exact donor SHA-256.
5. Select the registered HAP underbody mount.
6. Fuse donor + underbody mount with OpenSCAD.
7. Generate an attribution receipt.
8. Keep the result in GENERATED state until print and rolling tests pass.

## Example

From the repository root:

    PowerShell -ExecutionPolicy Bypass -File .\HAP\BUILD_DONOR_CONVERSION.ps1 \
      -ArchivePath "C:\Path\To\lego-umbau.zip" \
      -DonorId "SHOW-ST01"

Other approved IDs in v0.1:
- SHOW-CV01
- SHOW-SC01
- SHOW-X01
- SHOW-SP01
- SHOW-LP01
- SHOW-WP01
- SHOW-SOL01

SHOW-SNAKE01 is deliberately blocked because its source license is unconfirmed.

## Mount styles

HEX:
- compact underbody mount
- intended for Straight / Curve / S-Curve style tiles

HEX_REINFORCED:
- broader underbody reinforcement ring
- intended for Crossing / Spiral / Loop / Whoopy style modules with higher dynamic or torsional load

## Important

The converter assumes the registered collection's nominal tile coordinate system where the donor underside is close to Z=0. The underbody mount overlaps the donor underside by 0.20 mm to produce a real boolean connection.

That is a CAD-generation assumption, not a physical-fit proof.
