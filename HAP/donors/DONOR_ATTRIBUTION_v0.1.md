# Donor Attribution & Redistribution Notes v0.1

## Approved archive family for this pipeline

The local audit of the uploaded archive identified the folder:

**Gravitrax Tiles Variations Collection - 4538769**

The bundled files in that collection describe the license as **Creative Commons - Attribution** and the bundled README identifies the Thingiverse user **ImShogun** as the author.

The exact Creative Commons version was not established by the local audit. Do not invent a version number in redistributed derivatives.

## Current redistribution policy

- Registry entries with license_state = CC_ATTRIBUTION may be converted locally by BUILD_DONOR_CONVERSION.ps1.
- Every locally generated derivative receives an attribution sidecar.
- Registry entries with LICENSE_UNCONFIRMED are blocked by the conversion script.
- Unconfirmed donor meshes are reference-only and must not be redistributed by this HAP branch.

## Current HOLD example

SHOW-SNAKE01 points to extension+gravitrax_stls/obj_1_gt-snake-direct[1].stl.

Its original license was not confirmed during the archive audit, therefore the registry marks it HOLD_LICENSE and the conversion runner refuses to process it.

## Reality rule

Licensing approval and physical validation are separate gates.

A donor may be legally eligible for conversion while its resulting HAP derivative remains GENERATED / NOT PHYSICALLY VALIDATED.
