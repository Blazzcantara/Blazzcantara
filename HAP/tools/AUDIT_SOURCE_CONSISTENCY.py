#!/usr/bin/env python3
"""Deep static consistency audit for the cumulative HAP source tree.

The audit is dependency-free and intentionally fail-closed. It checks the
relationships that are easy to break while editing different build/release
layers independently.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAD = ROOT / "cad" / "HAP_MASTER_v0.1.scad"
DONOR_CONVERTER = ROOT / "cad" / "DONOR_CONVERTER_v0.1.scad"
NATIVE_CONVERTER = ROOT / "cad" / "DONOR_NATIVE_CONNECTOR_v0.1.scad"
BUILD_ALL = ROOT / "BUILD_ALL.ps1"
WORKFLOW = ROOT.parent / ".github" / "workflows" / "hap-build.yml"
FINAL_BUILDER = ROOT / "BUILD_FINAL_RELEASE.ps1"
REGISTRY = ROOT / "donors" / "DONOR_REGISTRY_v0.1.csv"
RECIPES = ROOT / "donors" / "DONOR_RECIPES_v0.1.csv"
PILOT = ROOT / "pilot" / "PILOT_RESULTS_TEMPLATE_v0.1.csv"
STRUCTURAL = ROOT / "structural" / "STRUCTURAL_RESULTS_TEMPLATE_v0.1.csv"
SHOW = ROOT / "show" / "SHOW_RESULTS_TEMPLATE_v0.1.csv"


def fail(message: str) -> None:
    raise AssertionError(message)


def text(path: Path) -> str:
    if not path.is_file():
        fail(f"required file missing: {path}")
    return path.read_text(encoding="utf-8-sig")


def number(source: str, name: str) -> float:
    match = re.search(
        rf"(?m)^\s*{re.escape(name)}\s*=\s*(-?\d+(?:\.\d+)?)\s*;",
        source,
    )
    if not match:
        fail(f"constant not found: {name}")
    return float(match.group(1))


def csv_ids(path: Path, column: str) -> list[str]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows or column not in rows[0]:
        fail(f"{path}: missing column {column}")
    return [row[column] for row in rows]


cad = text(CAD)
donor = text(DONOR_CONVERTER)
native = text(NATIVE_CONVERTER)
build_all = text(BUILD_ALL)
workflow = text(WORKFLOW)
final_builder = text(FINAL_BUILDER)

# 1 — SSOT drift.
core_flat = number(cad, "core_nominal_flat")
core_h = number(cad, "core_h")
eps = number(cad, "eps")

checks = {
    "DONOR_CONVERTER core_nominal_flat": (number(donor, "core_nominal_flat"), core_flat),
    "DONOR_CONVERTER core_h": (number(donor, "core_h"), core_h),
    "DONOR_CONVERTER eps": (number(donor, "eps"), eps),
    "NATIVE_CONNECTOR hap_core_flat": (number(native, "hap_core_flat"), core_flat),
    "NATIVE_CONNECTOR hap_core_h": (number(native, "hap_core_h"), core_h),
}
for label, (actual, expected) in checks.items():
    if abs(actual - expected) > 1e-9:
        fail(f"SSOT drift: {label}: {actual} != {expected}")

if not re.search(
    r"hex_prism\(hap_core_flat\s*,\s*hap_core_h\s*,\s*0\s*,\s*0\s*\)",
    native,
):
    fail("native bridge core orientation drift: expected HAP socket orientation rot=0")

if abs(number(cad, "lego_pitch") - 8.0) > 1e-9:
    fail("LEGO grid pitch drift: expected 8.00 mm")
if "scale([xy_scale,xy_scale,1])" in cad.replace(" ", ""):
    fail("legacy whole-part LEGO XY scaling has re-entered production geometry")

# 2 — Master selectors / local builder / CI builder parity.
selectors = re.findall(r'PART\s*==\s*"([^"]+)"', cad)
if len(selectors) != len(set(selectors)):
    fail("duplicate PART selectors in HAP_MASTER")

local_calls = re.findall(
    r'(?m)^\s*Build-Part\s+"([^"]+)"\s+"([^"]+)"',
    build_all,
)
ci_calls = re.findall(
    r'(?m)^\s*build\s+([^\s]+)\s+-D\s+\'PART="([^"]+)"\'',
    workflow,
)

if len(local_calls) != 47:
    fail(f"BUILD_ALL expected 47 calls, found {len(local_calls)}")
if len(ci_calls) != 47:
    fail(f"workflow expected 47 calls, found {len(ci_calls)}")
if local_calls != ci_calls:
    local_set = set(local_calls)
    ci_set = set(ci_calls)
    fail(
        "BUILD_ALL/workflow build parity mismatch: "
        f"local_only={sorted(local_set-ci_set)} ci_only={sorted(ci_set-local_set)}"
    )

names = [name for name, _ in local_calls]
if len(names) != len(set(names)):
    fail("duplicate local STL output name")
unsupported = sorted({part for _, part in local_calls if part not in selectors})
if unsupported:
    fail(f"builder references unsupported PART selectors: {unsupported}")

# 3 — Registry / recipe identity and license gate.
with REGISTRY.open(encoding="utf-8-sig", newline="") as handle:
    registry = list(csv.DictReader(handle))
with RECIPES.open(encoding="utf-8-sig", newline="") as handle:
    recipes = list(csv.DictReader(handle))

reg_ids = [row["donor_id"] for row in registry]
recipe_ids = [row["donor_id"] for row in recipes]
if len(registry) != 9 or len(recipes) != 9:
    fail(f"expected 9 registry + 9 recipe rows, got {len(registry)} + {len(recipes)}")
if len(reg_ids) != len(set(reg_ids)) or len(recipe_ids) != len(set(recipe_ids)):
    fail("duplicate donor IDs")
if set(reg_ids) != set(recipe_ids):
    fail("registry/recipe donor ID mismatch")

ready = [row for row in registry if row["conversion_state"] == "READY_FOR_PRIVATE_CONVERSION"]
holds = [row for row in registry if row["conversion_state"] == "HOLD_LICENSE"]
if len(ready) != 8 or len(holds) != 1:
    fail(f"expected 8 ready + 1 license hold, got {len(ready)} + {len(holds)}")
if any(row["license_state"] != "CC_ATTRIBUTION" for row in ready):
    fail("conversion-ready donor lacks CC_ATTRIBUTION state")
if holds[0]["donor_id"] != "SHOW-SNAKE01":
    fail("unexpected license-hold donor")

# 4 — Physical promotion IDs exactly cover all release show modules.
pilot_ids = csv_ids(PILOT, "module_id")
show_ids = csv_ids(SHOW, "module_id")
structural_ids = csv_ids(STRUCTURAL, "module_id")

if len(pilot_ids) != 3 or len(set(pilot_ids)) != 3:
    fail("pilot matrix must contain exactly 3 unique modules")
if len(show_ids) != 5 or len(set(show_ids)) != 5:
    fail("advanced show matrix must contain exactly 5 unique modules")
if len(structural_ids) != 11 or len(set(structural_ids)) != 11:
    fail("structural matrix must contain exactly 11 unique modules")

release_show_block = re.search(
    r"\$showIds\s*=\s*@\((.*?)\)\s*\n\nAdd-Type",
    final_builder,
    flags=re.S,
)
if not release_show_block:
    fail("final builder showIds block not found")
release_show_ids = re.findall(r'"(SHOW-[^"]+)"', release_show_block.group(1))
expected_show = pilot_ids + show_ids
if set(release_show_ids) != set(expected_show) or len(release_show_ids) != 8:
    fail(
        f"final donor show list mismatch: release={release_show_ids} "
        f"physical={expected_show}"
    )
if "SHOW-SNAKE01" in release_show_ids:
    fail("unlicensed Snake donor reached final release list")

# 5 — Final release composition arithmetic and selector validity.
final_calls = re.findall(
    r'(?m)^\s*Build-FinalPart\s+"([^"]+)"\s+"([^"]+)"\s+"([^"]+)"',
    final_builder,
)
if len(final_calls) != 28:
    fail(f"final HAP generated part count must be 28, found {len(final_calls)}")
if len({name for _, name, _ in final_calls}) != 28:
    fail("duplicate final generated STL name")
bad_final_parts = sorted({part for _, _, part in final_calls if part not in selectors})
if bad_final_parts:
    fail(f"final builder references unsupported selectors: {bad_final_parts}")

by_dir: dict[str, int] = {}
for directory, _, _ in final_calls:
    by_dir[directory] = by_dir.get(directory, 0) + 1
expected_dirs = {
    "01_CORE_ADAPTERS": 11,
    "02_STRUCTURAL": 11,
    "05_FALLBACK_DONOR_MOUNTS": 6,
}
if by_dir != expected_dirs:
    fail(f"final generated distribution mismatch: {by_dir}")

final_total = len(final_calls) + 2 + len(release_show_ids)
if final_total != 38:
    fail(f"final release arithmetic expected 38 STL, got {final_total}")

# 6 — Reality gates must remain fail-closed.
required_states = {
    "INTERFACE_VALUES_PHYSICALLY_SELECTED_PENDING_SYSTEM_PILOT",
    "PHYSICAL_PILOT_PASS",
    "STRUCTURAL_PHYSICAL_PASS",
    "SHOW_MODULES_PHYSICAL_PASS",
}
missing_states = sorted(state for state in required_states if state not in final_builder)
if missing_states:
    fail(f"final release missing reality-state gates: {missing_states}")
if "SYNTHETIC_CI_ONLY_DO_NOT_USE_FOR_PRINTING" not in workflow:
    fail("workflow no longer proves synthetic profile rejection")
if "Synthetic final-release refusal PASS" not in workflow:
    fail("workflow no longer proves synthetic final-release rejection")

print("HAP SOURCE CONSISTENCY AUDIT PASS")
print(f"PART selectors: {len(selectors)}")
print("Local/CI build outputs: 47 / 47")
print("Donor registry: 8 ready / 1 hold")
print("Physical show coverage: 3 pilot + 5 advanced")
print("Structural physical coverage: 11")
print("Final release composition: 28 generated + 2 native + 8 donor = 38")
print("SSOT duplicated constants: synchronized")
