# HAP Donor Conversion Test Matrix v0.1

Status: GENERATED PIPELINE / PHYSICAL TEST REQUIRED

## Static CAD gate

| Donor ID | SHA verified | OpenSCAD output | Mesh opens | Attribution receipt | Result |
|---|---|---|---|---|---|
| SHOW-ST01 | | | | | |
| SHOW-CV01 | | | | | |
| SHOW-SC01 | | | | | |
| SHOW-X01 | | | | | |
| SHOW-SP01 | | | | | |
| SHOW-LP01 | | | | | |
| SHOW-WP01 | | | | | |
| SHOW-SOL01 | | | | | |

## Physical fit gate

For each printed derivative record:
- HAP core insertion and removal
- carrier retention
- donor/base contact quality
- lateral rigidity
- visible cracking or stress
- interference with original GraviTrax connectors

## Rolling regression gate

Start with low-dynamic modules:
1. SHOW-ST01 Straight
2. SHOW-CV01 Curve
3. SHOW-SC01 S-Curve
4. SHOW-X01 Crossing
5. SHOW-SP01 Spiral
6. SHOW-LP01 Loop
7. SHOW-WP01 Whoopy

A module reaches ROLL_TEST_PASS only when repeated marble runs do not introduce new stalls, launches, rubbing or alignment errors attributable to the HAP conversion.

## HOLD gate

SHOW-SNAKE01 stays HOLD_LICENSE and must not be converted by the automated runner until the original source license is confirmed.
