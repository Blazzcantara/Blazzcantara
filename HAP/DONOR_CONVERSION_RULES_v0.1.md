# HAP Donor Conversion Rules v0.1

The purpose of the donor layer is to reuse working GraviTrax-compatible geometry without unnecessarily changing the ball path.

## Conversion order

1. Preserve the existing functional track surface.
2. Identify a structurally safe support region below the functional surface.
3. Add the smallest useful HAP donor pad or core mount.
4. Keep the HAP replaceable core separable where geometry permits.
5. Avoid boolean edits to the ball channel unless required.
6. Re-check clearances around the marble path after every CAD operation.
7. Mark the result GENERATED until a real print and rolling test pass.

## Preferred donor blanks

- DONOR_PAD_HEX: broad hex support under tile-like parts.
- DONOR_PAD_RECT: narrow support under bridge, straight or transition parts.
- DONOR_CORE_MOUNT: compact interface intended for CAD fusion into an existing donor body.

## Reality states

REFERENCE_ONLY -> CAD_CONVERTED -> BUILD_PASS -> FIT_PASS -> ROLL_TEST_PASS -> PHYSICAL_PASS

No donor file from the uploaded source archives is redistributed by this branch.
