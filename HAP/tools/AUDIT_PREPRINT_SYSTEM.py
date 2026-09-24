#!/usr/bin/env python3
from __future__ import annotations
import argparse, csv, hashlib, json, re, shutil
from pathlib import Path

HAP_EXPECTED = [
    "HAP_LG2x2_to_GT_nominal_v0.1.stl",
    "HAP_LG4x4_to_GT_nominal_v0.1.stl",
    "HAP_FULL_HEX_6x6_socket_0.30_v0.1.stl",
    "HAP_GT_CORE_nominal_v0.1.stl",
    "HAP_GT_CORE_BLANK_v0.1.stl",
    "HAP_FULL_HEX_OFFSET_Xp4_v0.1.stl",
    "HAP_FULL_HEX_OFFSET_Xm4_v0.1.stl",
    "HAP_FULL_HEX_OFFSET_Xp8_v0.1.stl",
    "HAP_FULL_HEX_OFFSET_Yp4_v0.1.stl",
    "HAP_FULL_HEX_ROT30_v0.1.stl",
    "HAP_LG4x4_GT_DIRECT_OFFSET_Xp4_v0.1.stl",
    "HAP_SKY_CORE_2x4_v0.1.stl",
    "HAP_SKY_CORE_4x4_v0.1.stl",
    "HAP_SKY_CORE_4x6_v0.1.stl",
    "HAP_BRIDGE_DUAL_CORE_8x4_S32_v0.1.stl",
    "HAP_BRIDGE_DUAL_CORE_10x4_S40_v0.1.stl",
    "HAP_BRIDGE_DUAL_GT_8x4_S32_v0.1.stl",
    "HAP_DUAL_FOOT_CORE_S32_v0.1.stl",
    "HAP_DUAL_FOOT_CORE_S40_v0.1.stl",
    "HAP_CROSS_OUTRIGGER_CORE_S40_v0.1.stl",
    "HAP_DONOR_PAD_HEX_v0.1.stl",
    "HAP_DONOR_PAD_RECT_v0.1.stl",
    "HAP_DONOR_CORE_MOUNT_v0.1.stl",
    "HAP_DONOR_UNDERBODY_HEX_v0.1.stl",
    "HAP_DONOR_UNDERBODY_HEX_REINFORCED_v0.1.stl",
    "HAP_DONOR_UNDERBODY_RECT_v0.1.stl",
]

FORBIDDEN_PRINT_TOKENS = ("CAL_", "TECHNIC", "_0.20_", "_0.40_", "SYNTHETIC", "SMOKE")
INTERFACE_EXPECTED = {"pitch":8.00,"plate_h":3.20,"wall":1.50,"tube_od":6.50,"tube_id":4.80}
TOL = 0.035

def sha256(path: Path) -> str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def read_csv(path: Path):
    with path.open(newline="",encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))

def number_from_source(text: str, name: str) -> float:
    pats=[
        rf"(?m)^\s*{re.escape(name)}\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*;",
        rf"(?m)^\s*{re.escape(name)}\s*=.*?\?\s*([0-9]+(?:\.[0-9]+)?)\s*:",
    ]
    for pat in pats:
        m=re.search(pat,text)
        if m: return float(m.group(1))
    raise AssertionError(f"Could not resolve numeric source constant: {name}")

def assert_close(actual,expected,label,tol=TOL):
    if abs(actual-expected)>tol:
        raise AssertionError(f"{label}: expected {expected:.3f} mm, got {actual:.3f} mm (tol +/-{tol:.3f})")

def audit_geometry_json(path:Path,label:str):
    if not path.exists():
        raise AssertionError(f"Missing geometry evidence for {label}: {path}")
    data=json.loads(path.read_text(encoding="utf-8"))
    if data.get("positive_shells")!=1: raise AssertionError(f"{label}: positive_shells != 1")
    if data.get("watertight_edge_test") is not True: raise AssertionError(f"{label}: not watertight")
    if int(data.get("degenerate_triangle_count",-1))!=0: raise AssertionError(f"{label}: degenerate triangles present")
    return data

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",default=".")
    ap.add_argument("--output-dir",required=True)
    args=ap.parse_args()

    root=Path(args.repo_root).resolve()
    hap=root/"HAP"
    out=hap/"out"
    hap_audit=hap/"geometry_audit"
    structural_root=hap/"lego_structural_out"
    structural_stage=structural_root/"HAP_LEGO_STRUCTURAL_PACK_v0.1"
    structural_manifest_path=structural_stage/"STL_MANIFEST.csv"
    structural_audit=structural_root/"_audit"
    catalog_path=hap/"lego_structural"/"LEGO_STRUCTURAL_PARTS_v0.1.csv"
    master_hap=(hap/"cad"/"HAP_MASTER_v0.1.scad").read_text(encoding="utf-8")
    master_lego=(hap/"cad"/"LEGO_STRUCTURAL_MASTER_v0.1.scad").read_text(encoding="utf-8")

    report_dir=Path(args.output_dir).resolve()
    if report_dir.exists(): shutil.rmtree(report_dir)
    report_dir.mkdir(parents=True)

    warnings=[]
    rows=[]
    warnings.append(
        "Printed LEGO top-stud fit is NOMINAL ONLY: LEGO_STUD_D=4.80 mm and LEGO_STUD_DELTA=0.00. "
        "No separate real top-stud physical gate exists because the direct-print path intentionally skipped fit calibration."
    )
    warnings.append(
        "The new 25-part LEGO Structural Pack is a v0.2 pre-print add-on. The older HAP_FINAL_v1.0.0 builder still seals the "
        "original 38-part scope and does not yet claim these 25 parts as physically released."
    )

    pairs={
        "pitch":("lego_pitch","LEGO_PITCH"),
        "plate_h":("lego_plate_h","LEGO_PLATE_H"),
        "wall":("lego_wall","LEGO_WALL"),
        "tube_od":("lego_tube_od","LEGO_TUBE_OD"),
        "tube_id":("lego_tube_id","LEGO_TUBE_ID"),
    }
    interface_actual={}
    for key,(a_name,b_name) in pairs.items():
        a=number_from_source(master_hap,a_name); b=number_from_source(master_lego,b_name)
        interface_actual[key]={"hap":a,"lego_structural":b}
        assert_close(a,INTERFACE_EXPECTED[key],f"HAP {key}",1e-9)
        assert_close(b,INTERFACE_EXPECTED[key],f"LEGO structural {key}",1e-9)
        assert_close(a,b,f"SSOT parity {key}",1e-9)

    stud_d=number_from_source(master_lego,"LEGO_STUD_D")
    stud_h=number_from_source(master_lego,"LEGO_STUD_H")
    lego_roof=number_from_source(master_lego,"LEGO_ROOF")
    assert_close(stud_d,4.80,"LEGO stud diameter",1e-9)
    assert_close(stud_h,1.80,"LEGO stud height",1e-9)

    tube_wall=(INTERFACE_EXPECTED["tube_od"]-INTERFACE_EXPECTED["tube_id"])/2.0
    max_roof_bridge=max(
        INTERFACE_EXPECTED["pitch"]-INTERFACE_EXPECTED["tube_od"],
        ((2*INTERFACE_EXPECTED["pitch"]-0.20)-2*INTERFACE_EXPECTED["wall"])/2.0
        - INTERFACE_EXPECTED["tube_od"]/2.0
    )
    if INTERFACE_EXPECTED["wall"] < 1.20:
        raise AssertionError("Structural outer wall below 1.20 mm pre-print guard.")
    if lego_roof < 0.80:
        raise AssertionError("Structural roof below 0.80 mm pre-print guard.")
    if tube_wall < 0.80:
        raise AssertionError("Structural anti-stud tube wall below 0.80 mm pre-print guard.")
    if max_roof_bridge > 4.00:
        raise AssertionError(f"Structural roof bridge span too large: {max_roof_bridge:.2f} mm")

    actual_hap=sorted(p.name for p in out.glob("*.stl") if p.name in HAP_EXPECTED)
    if actual_hap!=sorted(HAP_EXPECTED):
        missing=sorted(set(HAP_EXPECTED)-set(actual_hap))
        extra=sorted(set(actual_hap)-set(HAP_EXPECTED))
        raise AssertionError(f"HAP direct-print selection mismatch. missing={missing}, extra={extra}")

    for name in HAP_EXPECTED:
        upper=name.upper()
        for token in FORBIDDEN_PRINT_TOKENS:
            if token in upper: raise AssertionError(f"Forbidden token {token} in print candidate {name}")
        stl=out/name
        geo=audit_geometry_json(hap_audit/(stl.stem+".json"),name)
        orientation="DEFAULT_FLAT_BASE_DOWN"
        risk="NORMAL"
        if name in {
            "HAP_DONOR_CORE_MOUNT_v0.1.stl",
            "HAP_DONOR_UNDERBODY_HEX_v0.1.stl",
            "HAP_DONOR_UNDERBODY_HEX_REINFORCED_v0.1.stl",
            "HAP_DONOR_UNDERBODY_RECT_v0.1.stl",
        }:
            orientation="ROTATE_180_PAD_ON_BED_CORE_UP"
            risk="ORIENTATION_REQUIRED"
            warnings.append(f"{name}: standalone STL should be rotated 180 degrees so the broad donor pad is on the bed and the HAP core points upward.")
        elif "DONOR_PAD_" in name:
            orientation="DONOR_PAD_FLAT_BASE_DOWN"
        elif name.startswith("HAP_GT_CORE"):
            orientation="CORE_FLAT_BASE_DOWN"
        elif any(token in name for token in ("LG","FULL_HEX","SKY","BRIDGE","DUAL_FOOT","CROSS_OUTRIGGER")):
            orientation="LEGO_OPEN_CAVITY_DOWN_GRAVITRAX_SIDE_UP"

        rows.append({
            "family":"HAP","file":name,"path":stl.relative_to(root).as_posix(),
            "sha256":sha256(stl),"size_bytes":stl.stat().st_size,"triangles":geo.get("triangles"),
            "bbox_x_mm":geo["bbox_extent_mm"][0],"bbox_y_mm":geo["bbox_extent_mm"][1],"bbox_z_mm":geo["bbox_extent_mm"][2],
            "positive_shells":geo.get("positive_shells"),"watertight":geo.get("watertight_edge_test"),
            "degenerate_triangles":geo.get("degenerate_triangle_count"),"risk":risk,
            "orientation":orientation,
        })

    structural_manifest=read_csv(structural_manifest_path)
    catalog=read_csv(catalog_path)
    if len(structural_manifest)!=25: raise AssertionError(f"Structural manifest expected 25 rows, got {len(structural_manifest)}")
    if len(catalog)!=25: raise AssertionError(f"Structural catalog expected 25 rows, got {len(catalog)}")
    by_selector={r["selector"]:r for r in catalog}
    if len(by_selector)!=25: raise AssertionError("Structural catalog contains duplicate selector values")

    structural_names=[]
    for mr in structural_manifest:
        filename=mr["file"]; selector=mr["part_selector"]; structural_names.append(filename)
        if selector not in by_selector: raise AssertionError(f"Structural selector missing from catalog: {selector}")
        cat=by_selector[selector]
        nx=int(cat["nx"]); ny=int(cat["ny"]); body_h=float(cat["height_mm"])
        expected_x=nx*8.00-0.20; expected_y=ny*8.00-0.20; expected_z=body_h+1.80
        bx=float(mr["bbox_x_mm"]); by=float(mr["bbox_y_mm"]); bz=float(mr["bbox_z_mm"])
        assert_close(bx,expected_x,f"{filename} bbox X")
        assert_close(by,expected_y,f"{filename} bbox Y")
        assert_close(bz,expected_z,f"{filename} bbox Z")
        if mr["positive_shells"]!="1": raise AssertionError(f"{filename}: structural manifest positive_shells != 1")
        if mr["watertight"].strip().lower() not in {"true","1"}: raise AssertionError(f"{filename}: structural manifest not watertight")
        if int(mr["degenerate_triangles"])!=0: raise AssertionError(f"{filename}: structural manifest degenerate triangles")
        matches=list(structural_stage.rglob(filename))
        if len(matches)!=1: raise AssertionError(f"{filename}: expected one packaged structural STL, found {len(matches)}")
        stl=matches[0]
        geo=audit_geometry_json(structural_audit/(Path(filename).stem+".json"),filename)
        aspect=expected_z/min(expected_x,expected_y)
        risk="NORMAL"
        if aspect>=6.0:
            risk="HIGH_SLENDER"
            warnings.append(f"{filename}: tall/slender aspect ratio {aspect:.2f}; use strong bed adhesion/brim and do not use as the first proof print.")
        elif aspect>=3.5:
            risk="CAUTION_SLENDER"
            warnings.append(f"{filename}: slender aspect ratio {aspect:.2f}; verify bed adhesion before long print.")
        rows.append({
            "family":"LEGO_STRUCTURAL","file":filename,"path":stl.relative_to(root).as_posix(),
            "sha256":sha256(stl),"size_bytes":stl.stat().st_size,"triangles":geo.get("triangles"),
            "bbox_x_mm":bx,"bbox_y_mm":by,"bbox_z_mm":bz,
            "positive_shells":geo.get("positive_shells"),"watertight":geo.get("watertight_edge_test"),
            "degenerate_triangles":geo.get("degenerate_triangle_count"),"risk":risk,
            "orientation":"STUDS_UP_OPEN_ANTISTUD_CAVITY_DOWN",
        })

    if len(set(structural_names))!=25: raise AssertionError("Duplicate structural STL filename")
    if len(rows)!=51: raise AssertionError(f"Pre-print set expected 51 STL, got {len(rows)}")
    hashes=[r["sha256"] for r in rows]
    if len(set(hashes))!=51: raise AssertionError("Duplicate STL payload SHA-256 values found")
    basenames=[r["file"] for r in rows]
    if len(set(basenames))!=51: raise AssertionError("Duplicate STL basenames across combined print set")
    if "HAP_FULL_HEX_6x6_socket_0.30_v0.1.stl" not in basenames: raise AssertionError("Nominal 0.30 core socket missing")
    if any("_socket_0.20_" in n or "_socket_0.40_" in n for n in basenames): raise AssertionError("Non-nominal full-hex socket leaked into direct-print set")
    if any("TECHNIC" in n.upper() for n in basenames): raise AssertionError("Technic leaked into no-Technic pre-print set")
    if any(n.startswith("CAL_") for n in basenames): raise AssertionError("Calibration coupon leaked into direct-print set")

    pkg_root=report_dir/"HAP_PREPRINT_AUDITED_PUBLIC_NO_TECHNIC_v0.2"
    (pkg_root/"01_HAP").mkdir(parents=True)
    (pkg_root/"02_LEGO_STRUCTURAL").mkdir(parents=True)
    (pkg_root/"03_AUDIT").mkdir(parents=True)

    for r in rows:
        src=root/r["path"]
        dst_dir=pkg_root/("01_HAP" if r["family"]=="HAP" else "02_LEGO_STRUCTURAL")
        shutil.copy2(src,dst_dir/r["file"])

    fieldnames=list(rows[0].keys())
    with (pkg_root/"03_AUDIT"/"PREPRINT_MANIFEST.csv").open("w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=fieldnames); w.writeheader(); w.writerows(rows)

    summary={
        "audit_version":"0.2",
        "reality_state":"DIGITAL_PREPRINT_AUDIT_PASS_PHYSICAL_FIT_PENDING",
        "public_regenerable_stl_count":51,
        "hap_nominal_stl_count":26,
        "lego_structural_stl_count":25,
        "native_real_stl_count_not_in_public_package":2,
        "mesh_gate":{"positive_shells_exactly_one":True,"watertight":True,"zero_degenerate_triangles":True,"unique_sha256_payloads":True},
        "interface_parity":interface_actual,
        "lego_stud_d_mm":stud_d,"lego_stud_h_mm":stud_h,
        "structural_printability_guard":{
            "outer_wall_mm":INTERFACE_EXPECTED["wall"],
            "roof_mm":lego_roof,
            "tube_wall_mm":round(tube_wall,3),
            "max_nominal_roof_bridge_mm":round(max_roof_bridge,3),
            "support_free_geometry_guard":"PASS",
        },
        "printed_top_stud_fit_state":"NOMINAL_4.80_STUD_DELTA_0.00_PHYSICAL_GATE_SKIPPED",
        "final_release_scope_note":"HAP_FINAL_v1.0.0 remains the original 38-part physically-gated scope; LEGO Structural Pack is v0.2 pre-print add-on.",
        "warnings":warnings,"physical_fit_sealed":False,
    }
    (pkg_root/"03_AUDIT"/"PREPRINT_AUDIT.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")

    md=[
        "# HAP v0.2 Pre-Print Full Audit","",
        "**DIGITAL PRE-PRINT AUDIT: PASS**","",
        "Reality state: DIGITAL_PREPRINT_AUDIT_PASS_PHYSICAL_FIT_PENDING","",
        "## Audited print inventory","",
        "- 26 nominal HAP non-Technic production candidates",
        "- 25 LEGO-compatible structural parts",
        "- 51 public/regenerable STL files total",
        "- 2 real native donor-derived STL files remain a separate addendum","",
        "## Passed checks","",
        "- exact inventory and no-Technic/no-calibration selection",
        "- 8.00 mm grid SSOT parity",
        "- 3.20 mm plate / 9.60 mm brick dimensional contract",
        "- 4.80 x 1.80 mm nominal structural top studs",
        "- every selected mesh: exactly one positive shell",
        "- every selected mesh: watertight",
        "- every selected mesh: zero degenerate triangles",
        "- 51/51 unique SHA-256 STL payloads",
        "- structural X/Y/Z bounding boxes match catalog dimensions",
        "- structural wall/roof/tube and roof-bridge printability guards",
        "- explicit per-part print orientation metadata",
        "- nominal 0.30 core socket only","",
        "## Physical limitation","",
        "Fit calibration was intentionally skipped. Digital PASS does not prove real LEGO clutch force, real GraviTrax fit, material shrinkage, or structural load.","",
    ]
    if warnings:
        md+=["## Print-risk warnings",""]+[f"- {w}" for w in warnings]+[""]
    md += [
        "## Recommended first proof build","",
        "Print a normal-height Brick 2x4 + Plate 6x6 + LG4x4-to-GT adapter before committing to the H10 towers.",
        "This is a real usable assembly, not a calibration coupon, and serves as the first physical sanity check.",""
    ]
    (pkg_root/"00_PREPRINT_AUDIT_README.md").write_text("\n".join(md),encoding="utf-8")

    sum_lines=[]
    for p in sorted(pkg_root.rglob("*")):
        if p.is_file() and p.name!="SHA256SUMS.txt":
            sum_lines.append(f"{sha256(p)}  {p.relative_to(pkg_root).as_posix()}")
    (pkg_root/"SHA256SUMS.txt").write_text("\n".join(sum_lines)+"\n",encoding="ascii")

    print("PREPRINT FULL AUDIT PASS")
    print("Selected STLs:",len(rows))
    print("HAP:",sum(1 for r in rows if r["family"]=="HAP"))
    print("LEGO structural:",sum(1 for r in rows if r["family"]=="LEGO_STRUCTURAL"))
    print("Warnings:",len(warnings))
    for warning in warnings: print("WARN:",warning)

if __name__=="__main__":
    main()
