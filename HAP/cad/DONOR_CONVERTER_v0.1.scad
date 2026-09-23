/*
HAP Donor Converter v0.1
Local-use conversion harness.

The donor STL is intentionally external and is NOT stored in this repository.
This file fuses a selected donor mesh with a HAP underbody mount.

GENERATED != PHYSICALLY VALIDATED.
*/

use <HAP_MASTER_v0.1.scad>

$fn = 72;

DONOR_FILE = is_undef(DONOR_FILE) ? "" : DONOR_FILE;
MOUNT_STYLE = is_undef(MOUNT_STYLE) ? "HEX" : MOUNT_STYLE;
MODE = is_undef(MODE) ? "FUSED" : MODE;

DONOR_X = is_undef(DONOR_X) ? 0.0 : DONOR_X;
DONOR_Y = is_undef(DONOR_Y) ? 0.0 : DONOR_Y;
DONOR_Z = is_undef(DONOR_Z) ? 0.0 : DONOR_Z;
DONOR_ROT = is_undef(DONOR_ROT) ? 0.0 : DONOR_ROT;

module donor_mesh() {
    assert(DONOR_FILE != "", "DONOR_FILE must point to a local donor STL.");

    translate([DONOR_X,DONOR_Y,DONOR_Z])
        rotate([0,0,DONOR_ROT])
            import(file=DONOR_FILE,convexity=20);
}

module donor_mount() {
    if (MOUNT_STYLE == "HEX")
        donor_underbody_hex(58.40,2.40,0.20,false);
    else if (MOUNT_STYLE == "HEX_REINFORCED")
        donor_underbody_hex(58.40,2.40,0.20,true);
    else if (MOUNT_STYLE == "RECT")
        donor_underbody_rect(48.0,24.0,2.40,0.20);
    else
        assert(false,str("Unknown MOUNT_STYLE: ",MOUNT_STYLE));
}

if (MODE == "MOUNT_ONLY")
    donor_mount();
else if (MODE == "DONOR_ONLY")
    donor_mesh();
else if (MODE == "FUSED")
    union() {
        donor_mesh();
        donor_mount();
    }
else
    assert(false,str("Unknown MODE: ",MODE));
