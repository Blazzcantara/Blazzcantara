# HAP Physical Workbench v0.1

Status: IMPLEMENTED / REAL PHYSICAL EVIDENCE STILL REQUIRED

This workbench is the operator layer for HAP-037 through HAP-040.

## HAP-037 — Minimal Next-Print Queue

BUILD_NEXT_PRINT_QUEUE.ps1 reads the current physical results and copies only the
next useful candidate for each unfinished interface gate into one folder.

The initial queue contains:
- LEGO clutch nominal;
- GT male nominal;
- HAP core socket nominal plus one reusable HAP core;
- Technic hole nominal;
- Native removable connector nominal.

After a TIGHT or LOOSE result, the queue moves only in the useful direction.

## HAP-038 — Physical Operator Dashboard

BUILD_PHYSICAL_DASHBOARD.ps1 creates:
- HAP_PHYSICAL_DASHBOARD.md;
- HAP_PHYSICAL_DASHBOARD.html;
- HAP_PHYSICAL_DASHBOARD.json.

The dashboard shows:
- 5 interface-gate states;
- current winner per gate;
- pilot / structural / show progress when those result files exist;
- current blockers;
- the active overall stage.

## HAP-039 — Checkpoint / Restore

SAVE_PHYSICAL_CHECKPOINT.ps1 snapshots physical campaign state with:
- CSV / JSON evidence files;
- checkpoint manifest;
- SHA-256 verification;
- checkpoint ZIP and ZIP SHA-256.

RESTORE_PHYSICAL_CHECKPOINT.ps1 extracts into a target directory and verifies
every manifest hash before declaring PASS.

Use a checkpoint before:
- replacing a calibration winner;
- starting the first system pilot;
- beginning structural promotion;
- beginning advanced show-module promotion.

## HAP-040 — Self-Contained Windows Workbench

BUILD_PHYSICAL_WORKBENCH.ps1 creates HAP_PHYSICAL_WORKBENCH_v0.1.zip.

The workbench contains:
- staged calibration pack;
- working physical-results CSV;
- next-print queue;
- HTML / Markdown / JSON dashboard;
- operator scripts;
- required CAD / audit tools;
- Windows launcher START_HAP_PHYSICAL.cmd.

### Normal Windows workflow

1. Extract the workbench ZIP.
2. Double-click START_HAP_PHYSICAL.cmd.
3. Enter the path to lego-umbau.zip.
4. Print only the STL files in WORK\NEXT_PRINT_QUEUE.
5. Record each real fit test.
6. Start the launcher again.

The launcher refreshes the queue and dashboard after every run.

## Reality rule

The workbench automates file selection, evidence handling and promotion logic.
It never infers a physical PASS from CAD, CI, dimensions, slicer output or a
previous synthetic test.
