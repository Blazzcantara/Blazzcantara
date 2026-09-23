# HAP Native Donor Connector SSOT v0.1

Status: DONOR-DERIVED / GENERATED / NOT PHYSICALLY SEALED

This interface is derived from the removable connector included in the audited
`Gravitrax Tiles Variations Collection - 4538769`.

## Source identity

- Archive path: `Gravitrax Tiles Variations Collection - 4538769 - part 3 of 3/files/hex-connectorNOT-NEEDED-spare.stl`
- SHA-256: `31818bf1c329a458ef9a1a74e477bc0e0d5e2403e64700c77ec5f798962fd4c1`
- Audited mesh size: approximately 29.70 × 33.985 × 3.00 mm
- Mesh state in audit: one component / watertight
- Bundled author identification: ImShogun
- Bundled license text: Creative Commons - Attribution
- License version: not stated in the bundled LICENSE.txt

The source mesh is not stored in this repository. The local builder extracts it
from the user's archive and verifies the SHA-256 before generating derivatives.

## Calibration gate

Five XY scale variants are generated:

- 0.996
- 0.998
- 1.000
- 1.002
- 1.004

First test `CONNECTOR_ONLY` variants. Only after one scale is selected should
the matching `CORE_BRIDGE` be treated as the candidate adapter.

## Bridge geometry

Upper interface:
- exact verified native connector mesh
- XY-scaled only by the selected calibration factor

Lower interface:
- HAP core body
- 30.80 mm nominal across flats
- 3.20 mm nominal height
- 0.20 mm overlap into the native connector to guarantee a single generated body

## Preferred architecture

For compatible 4538769 tiles:

```text
existing donor tile
      |
native removable socket
      |
HAP native connector bridge
      |
HAP carrier / LEGO / Technic structure
```

This is preferred over fusing a large underbody pad into the donor tile because
it preserves the original track mesh and print orientation.

## Reality gate

The connector source dimensions are donor-derived and hash-verified, but no scale
variant is SEALED until it is printed and physically clipped into a real donor
tile without excessive force, play or damage.
