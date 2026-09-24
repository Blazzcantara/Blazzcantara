# License and compatibility notes

## Original HAP code and parametric geometry

The original HAP source code and original parametric compatibility geometry in
this repository are released under the MIT License.

Copyright (c) 2026 Hybrid Adapter Pack contributors.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, subject to inclusion of this notice.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

## Third-party donor geometry

Third-party donor meshes are NOT relicensed under MIT.

The audited archive family:

**Gravitrax Tiles Variations Collection - 4538769**

contains bundled licensing text described by the archive audit as
**Creative Commons - Attribution** and identifies **ImShogun** in its bundled
README. The exact Creative Commons version was not established by the audit and
must not be invented.

HAP release tooling therefore applies a separate donor-license gate:

- only registry rows marked `CC_ATTRIBUTION` may be included in a donor-enabled
  local/final package;
- the original donor license/readme and HAP donor-attribution documentation must
  accompany redistributed donor meshes;
- `LICENSE_UNCONFIRMED` items remain blocked from redistribution;
- SHOW-SNAKE01 remains excluded until its original license is confirmed.

The final release builder verifies registered SHA-256 values before including
any approved donor tile.

## Trademarks / compatibility

LEGO is a trademark of the LEGO Group.
GraviTrax is a trademark/product line of Ravensburger.

This project is an independent compatibility / maker project and is not
affiliated with or endorsed by either rights holder.

## Reality and licensing are separate gates

A donor mesh being eligible for redistribution does not mean its HAP use has
been physically validated. Physical fit, structural and rolling gates remain
mandatory before a final physical release state may be produced.
