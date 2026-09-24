# HAP Deep Audit Report v0.1

Status: DIGITAL CLEANUP / FINAL CI REQUIRED

This report records the final pre-physical audit of the cumulative HAP-002..040
development state.

## Scope

The audit covers:
- 47 generated HAP STL candidates;
- parametric CAD selector coverage;
- local and GitHub Actions build parity;
- mesh topology;
- donor registry / recipe identity;
- license promotion gates;
- physical evidence gates;
- physical workbench state handling;
- final-release composition and SHA-256 linkage.

## Defects found and corrected

### 1. LEGO 2x2 direct support disconnected transition
The narrow 2x2 transition could be separated by the old internal through-relief.

Correction:
- narrow supports no longer receive the destructive internal relief;
- the generated direct 2x2 adapter is required to pass the one-positive-solid
  geometry gate.

### 2. Sky 2x4 support disconnected transition
The same class of relief problem affected the narrow Sky 2x4 carrier.

Correction:
- internal relief is limited to sufficiently wide Sky carriers;
- Sky 2x4 remains a connected load path.

### 3. Rectangular donor pad split into two bodies
The rectangular donor receiver still selected a 48x24 mm body while the HAP
socket cut required a wider continuous perimeter.

Correction:
- selector changed to 48x36 mm;
- the digital release gate requires exactly one positive solid body.

### 4. Cross-outrigger core socket could be partially filled
The original cross outrigger unioned two complete dual-foot carriers rotated
90 degrees. Each carrier contained its own socket. The union could fill parts
of the other rotated socket and produce a non-canonical center cavity.

Correction:
- the four LEGO feet and orthogonal load paths are now built first;
- exactly one canonical HAP core socket is added at the center;
- a controlled 0.20 mm vertical overlap joins the socket receiver to the deck.

### 5. Checkpoint relative-path corruption
The checkpoint saver did not resolve the active work root before calculating
relative paths.

Correction:
- active work root is resolved explicitly;
- restore verifies every file SHA-256.

### 6. Repeated checkpoint self-ingestion
When checkpoints live inside the work directory, a later recursive snapshot
could otherwise ingest files from earlier checkpoint folders.

Correction:
- the checkpoint tree is explicitly excluded from active-state discovery;
- ambiguous duplicate active-state files are rejected;
- CI performs two sequential checkpoint saves before restore validation.

### 7. Final release audit parser corruption
A prior edit left FINAL_RELEASE_AUDIT.ps1 syntactically damaged.

Correction:
- the audit was reconstructed;
- PowerShell parser validation is a mandatory CI gate;
- whole-tree SHA256SUMS and evidence linkage are checked.

### 8. Stale local STL outputs
A repeated local build could previously retain STL files from an older revision.

Correction:
- HAP/out and donor smoke STL outputs are cleaned before every local build;
- exact output count remains mandatory.

### 9. ASCII STL audit support
OpenSCAD CI output may be ASCII STL while older audit logic assumed binary STL.

Correction:
- STL_COMPONENT_AUDIT.py supports binary and ASCII STL.

## Current digital invariants

A successful final digital CI run requires:
- exactly 47 generated STL files;
- 47 unique STL SHA-256 values;
- exactly one positive printable solid body per STL;
- watertight topology for every STL;
- zero degenerate triangles for every STL;
- 47 local build definitions matching 47 CI build definitions;
- every build PART backed by a HAP_MASTER selector;
- fixed LEGO 8.00 mm system pitch;
- synchronized HAP core constants in master / donor / native CAD;
- donor registry = 8 conversion-ready CC-Attribution entries + 1 Snake
  license hold;
- physical show coverage = 3 pilot + 5 advanced modules;
- structural physical coverage = 11 modules;
- final release arithmetic = 28 generated HAP + 2 native connector + 8 donor
  show tiles = 38 STL.

## Digital STL deliverable

After all digital gates pass, BUILD_DIGITAL_STL_SET.ps1 creates:

    HAP_DIGITAL_STL_SET_v0.1.zip

Contents:
- 17 calibration STL;
- 13 core / adapter STL;
- 11 structural STL;
- 6 donor-mount STL;
- per-STL geometry audit JSON;
- STL_MANIFEST.csv;
- SHA256SUMS.txt;
- DIGITAL_AUDIT_SUMMARY.json.

Reality state:

    DIGITAL_GEOMETRY_PASS_PHYSICAL_PENDING

## Remaining non-digital gate

No digital audit can establish mechanical fit or marble-running behavior.

The true HAP FINAL v1.0.0 release therefore remains blocked until the existing
real physical gates pass:
1. five interface winners;
2. Straight / Large Curve / S-Curve 10/10 pilot;
3. eleven structural tests;
4. five advanced show-module 10/10 promotions.

No synthetic or CI fixture is permitted to satisfy these physical gates.
