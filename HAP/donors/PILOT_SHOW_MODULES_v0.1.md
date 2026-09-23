# HAP-017..019 — Native Connector Pilot Plan

Status: IMPLEMENTED / PHYSICAL PILOT REQUIRED

## HAP-017 — Native Connector Intake

The existing donor collection already provides a removable connector that is
printed inside the tile and extracted after printing. HAP now treats this as a
first-class interface instead of permanently fusing a support plate into each
show tile.

This keeps the functional ball path untouched and avoids forcing a large
underbody adapter into the donor's normal print orientation.

## HAP-018 — Connector-to-HAP Core Bridge

`BUILD_NATIVE_CONNECTOR_PILOT.ps1` builds ten local STLs from the user's
verified archive:

- five CONNECTOR_ONLY calibration variants;
- five matching CORE_BRIDGE variants.

Every STL receives a dependency-free connectivity / watertight audit.

## HAP-019 — First Real Show-Module Pilot

Use the selected bridge with these existing donor tiles in this order:

1. SHOW-ST01 — Straight
2. SHOW-CV01 — Large curve
3. SHOW-SC01 — S-curve

The donor tile itself does not need CAD modification for this pilot. Replace the
collection's normal removable connector with the selected HAP native connector
bridge.

### Physical checks

For each of the three pilot tiles:

- connector inserts fully;
- connector removes without damage;
- no visible stress whitening or cracking;
- HAP core engages the selected carrier;
- no rocking under light lateral load;
- original track connectors remain unobstructed;
- ball path remains untouched;
- 10 consecutive marble runs complete without a new stall or rub.

Only after this pilot passes should Crossing, Spiral, Loop and Whoopy be promoted
to the same connector strategy.

## Fallback path

The HAP-011..016 fused-donor pipeline remains available for donor families that
do not expose a useful removable connector. It is no longer the preferred path
for the 4538769 tile family.
