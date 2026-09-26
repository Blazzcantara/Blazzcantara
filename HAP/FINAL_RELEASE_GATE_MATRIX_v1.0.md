# HAP Final Release Gate Matrix v1.0

| Gate | Required state | Current source |
|---|---|---|
| Digital CAD / CI | PASS | GitHub Actions |
| LEGO clutch | real winner | physical calibration |
| GT male | real winner | physical calibration |
| HAP core clearance | real winner | physical calibration |
| Technic pin | real winner | physical calibration |
| Native connector | real winner | physical calibration |
| Straight / Curve / S-Curve | PHYSICAL_PILOT_PASS | 10-run pilot |
| 11 structural parts | STRUCTURAL_PHYSICAL_PASS | structural matrix |
| 5 advanced show modules | SHOW_MODULES_PHYSICAL_PASS | 10-run promotion |
| Final tree audit | FINAL_AUDIT_PASS | FINAL_RELEASE_AUDIT.ps1 |
| Final ZIP | HAP_FINAL_v1.0.0 | BUILD_FINAL_RELEASE.ps1 |

Snake remains excluded because its source license is still unconfirmed.
