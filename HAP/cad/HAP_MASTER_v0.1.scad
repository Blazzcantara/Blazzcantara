/*
Hybrid Adapter Pack v0.1 — HAP-002..040 Parametric Master
Original parametric compatibility geometry.
GENERATED != PHYSICALLY VALIDATED.

This file intentionally separates:
1) LEGO-family underside clutch geometry
2) GraviTrax-family support connector
3) full-hex shell
4) replaceable core
5) offset/orientation carriers

Units: mm.
*/

$fn = 72;

// -------------------------
// User/build parameters
// -------------------------
PART = is_undef(PART) ? "LG4x4_GT" : PART;
LEGO_SCALE = is_undef(LEGO_SCALE) ? 1.000 : LEGO_SCALE; // legacy compatibility only
LEGO_CLUTCH_DELTA = is_undef(LEGO_CLUTCH_DELTA) ? 0.00 : LEGO_CLUTCH_DELTA;
GT_MALE_FLAT = is_undef(GT_MALE_FLAT) ? 29.78 : GT_MALE_FLAT;
CORE_CLEARANCE = is_undef(CORE_CLEARANCE) ? 0.30 : CORE_CLEARANCE;
OFFSET_X = is_undef(OFFSET_X) ? 0.0 : OFFSET_X;
OFFSET_Y = is_undef(OFFSET_Y) ? 0.0 : OFFSET_Y;
TILE_ROTATION = is_undef(TILE_ROTATION) ? 0.0 : TILE_ROTATION;

// -------------------------
// Interface SSOT — nominal
// -------------------------
lego_pitch = 8.00;
lego_gap = 0.20;
lego_plate_h = 3.20;
lego_wall = 1.50;
lego_roof = 1.00;
lego_tube_od = 6.50;
lego_tube_id = 4.80;

gt_support_outer_flat = 46.00;
gt_tile_flat = 59.60;          // nominal full tile: ~68.82 mm point-to-point
gt_platform_h = 2.40;
gt_ring_h = 2.00;
gt_ring_wall = 2.00;

core_nominal_flat = 30.80;
core_h = 3.20;
full_hex_shell_h = 5.20;
full_hex_transition_h = 4.00;

eps = 0.02;

// -------------------------
// Generic primitives
// -------------------------
module centered_cube_xy(w,d,h,z=0) {
    translate([-w/2,-d/2,z]) cube([w,d,h], center=false);
}

module hex2d(flat) {
    r = flat / sqrt(3);
    polygon(points=[for (a=[0:60:300]) [r*cos(a), r*sin(a)]]);
}

module hex_prism(flat,h,z=0,rot=0) {
    translate([0,0,z])
        rotate([0,0,rot])
            linear_extrude(height=h)
                hex2d(flat);
}

module hex_ring(flat_outer, wall, h, z=0, rot=0) {
    difference() {
        hex_prism(flat_outer,h,z,rot);
        hex_prism(flat_outer-2*wall,h+2*eps,z-eps,rot);
    }
}

// -------------------------
// LEGO-family underside
// -------------------------
module lego_tile_bottom(nx=2, ny=2, xy_scale=1.0) {
    // LEGO grid pitch and outer footprint remain fixed.
    // Fit is tuned only at the contact features so a 6x6 part does not
    // accumulate grid error when calibration changes.
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;
    cavity_h = lego_plate_h - lego_roof;
    contact_wall = lego_wall + LEGO_CLUTCH_DELTA;
    contact_tube_od = lego_tube_od + 2*LEGO_CLUTCH_DELTA;

    union() {
        difference() {
            centered_cube_xy(w,d,lego_plate_h,0);
            centered_cube_xy(
                w-2*contact_wall,
                d-2*contact_wall,
                cavity_h+eps,
                -eps
            );
        }

        if (nx > 1 && ny > 1)
        for (ix=[0:nx-2])
        for (iy=[0:ny-2]) {
            x = (ix-(nx-2)/2)*lego_pitch;
            y = (iy-(ny-2)/2)*lego_pitch;
            translate([x,y,0])
            difference() {
                cylinder(d=contact_tube_od,h=cavity_h+0.20);
                translate([0,0,-eps])
                    cylinder(d=lego_tube_id,h=cavity_h+0.20+2*eps);
            }
        }
    }
}

module clutch_label_2x2(scale_value=1.0) {
    lego_tile_bottom(2,2,1.0);
    txt = str("d",LEGO_CLUTCH_DELTA);
    translate([0,0,lego_plate_h])
        linear_extrude(height=0.35)
            text(txt,size=2.6,halign="center",valign="center");
}

// -------------------------
// GT-family support interface
// -------------------------
module gt_male_ring(flat=29.78, z=0) {
    hex_ring(flat,gt_ring_wall,gt_ring_h,z);
}

module gt_male_test(flat=29.78) {
    base_flat = 38.0;
    base_h = 2.40;

    union() {
        difference() {
            hex_prism(base_flat,base_h,0);
            hex_prism(flat-2*gt_ring_wall,base_h+2*eps,-eps);
        }
        gt_male_ring(flat,base_h);
    }
}

module gt_support_top(male_flat=29.78, z=0) {
    inner_flat = male_flat - 2*gt_ring_wall;

    union() {
        difference() {
            hex_prism(gt_support_outer_flat,gt_platform_h,z);
            hex_prism(inner_flat,gt_platform_h+2*eps,z-eps);
        }
        gt_male_ring(male_flat,z+gt_platform_h);
    }
}

// -------------------------
// HAP-002 simple supports
// -------------------------
module lego_to_gt_adapter(nx=4, ny=4, xy_scale=1.0, male_flat=29.78, transition_h=8.0) {
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;
    z0 = lego_plate_h;
    z1 = lego_plate_h + transition_h;
    inner_flat = male_flat - 2*gt_ring_wall;

    union() {
        lego_tile_bottom(nx,ny,xy_scale);

        difference() {
            hull() {
                translate([0,0,z0])
                    centered_cube_xy(w*0.94,d*0.94,0.22,0);
                translate([0,0,z1])
                    linear_extrude(height=0.22)
                        hex2d(gt_support_outer_flat);
            }

            // Keep enough material around narrow bases. On a 2x2 footprint the
            // old through-relief removed the complete transition for several mm
            // and produced two disconnected solids.
            if (min(w,d) > inner_flat + 4.0)
                translate([0,0,z0+0.50])
                    hex_prism(inner_flat,transition_h+gt_platform_h+gt_ring_h+2.0,0);
        }

        gt_support_top(male_flat,z1);
    }
}

// -------------------------
// HAP-003 full hex platform
// -------------------------
module full_hex_transition(nx=6, ny=6, xy_scale=1.0, tile_rot=0, h=full_hex_transition_h) {
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;

    hull() {
        translate([0,0,lego_plate_h])
            centered_cube_xy(w*0.96,d*0.96,0.22,0);
        translate([0,0,lego_plate_h+h])
            rotate([0,0,tile_rot])
                linear_extrude(height=0.22)
                    hex2d(gt_tile_flat);
    }
}

module full_hex_shell(
    socket_dx=0,
    socket_dy=0,
    tile_rot=0,
    core_clearance=0.30,
    z=0
) {
    socket_flat = core_nominal_flat + core_clearance;

    difference() {
        hex_prism(gt_tile_flat,full_hex_shell_h,z,tile_rot);

        // Replaceable-core socket opens from the top, not through the whole shell.
        translate([socket_dx,socket_dy,z + full_hex_shell_h - core_h])
            hex_prism(socket_flat,core_h+eps,0,tile_rot);

        // Small underside relief prevents elephant-foot interference around the core.
        translate([socket_dx,socket_dy,z-eps])
            hex_prism(core_nominal_flat-3.0,1.00+eps,0,tile_rot);
    }
}

module lego_full_hex_platform(
    nx=6,
    ny=6,
    xy_scale=1.0,
    socket_dx=0,
    socket_dy=0,
    tile_rot=0,
    core_clearance=0.30
) {
    shell_z = lego_plate_h + full_hex_transition_h;

    union() {
        lego_tile_bottom(nx,ny,xy_scale);

        difference() {
            full_hex_transition(nx,ny,xy_scale,tile_rot,full_hex_transition_h);

            // Hollow transition to save filament while retaining broad ribs/walls.
            translate([0,0,lego_plate_h+0.80])
                hex_prism(gt_tile_flat-6.0,full_hex_transition_h+1.0,0,tile_rot);
        }

        full_hex_shell(socket_dx,socket_dy,tile_rot,core_clearance,shell_z);
    }
}

// -------------------------
// HAP-004 replaceable cores
// -------------------------
module gt_core_insert(
    male_flat=29.78,
    core_flat=core_nominal_flat,
    tile_rot=0,
    with_male=true
) {
    union() {
        // Fit body.
        hex_prism(core_flat,core_h,0,tile_rot);

        // Small top flange gives a finger-visible seam and prevents over-insertion.
        hex_ring(core_flat+1.20,0.60,0.60,core_h-0.60,tile_rot);

        if (with_male)
            gt_male_ring(male_flat,core_h);
    }
}

module gt_core_blank(core_flat=core_nominal_flat, tile_rot=0) {
    hex_prism(core_flat,core_h,0,tile_rot);
}

// -------------------------
// HAP-005 offset/orientation family
// -------------------------
module lego_full_hex_offset(
    dx=0,
    dy=0,
    tile_rot=0,
    nx=6,
    ny=6,
    xy_scale=1.0,
    core_clearance=0.30
) {
    // Keep full-hex outline centered while relocating the replaceable interface.
    lego_full_hex_platform(
        nx,
        ny,
        xy_scale,
        dx,
        dy,
        tile_rot,
        core_clearance
    );
}

// Direct integrated offset support (lighter than the full-hex shell).
module lego_to_gt_offset_direct(
    nx=4,
    ny=4,
    dx=0,
    dy=0,
    xy_scale=1.0,
    male_flat=29.78,
    transition_h=10.0
) {
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;
    z0 = lego_plate_h;
    z1 = lego_plate_h + transition_h;

    union() {
        lego_tile_bottom(nx,ny,xy_scale);

        hull() {
            translate([0,0,z0])
                centered_cube_xy(w*0.94,d*0.94,0.24,0);
            translate([dx,dy,z1])
                linear_extrude(height=0.24)
                    hex2d(gt_support_outer_flat);
        }

        translate([dx,dy,0])
            gt_support_top(male_flat,z1);
    }
}


// -------------------------
// HAP-006 modular Sky supports
// -------------------------
module core_socket_top(
    outer_flat=gt_support_outer_flat,
    core_clearance=0.30,
    z=0,
    h=full_hex_shell_h
) {
    socket_flat = core_nominal_flat + core_clearance;

    difference() {
        hex_prism(outer_flat,h,z,0);

        translate([0,0,z+h-core_h])
            hex_prism(socket_flat,core_h+eps,0,0);

        translate([0,0,z-eps])
            hex_prism(core_nominal_flat-3.0,1.00+eps,0,0);
    }
}

module core_socket_coupon(core_clearance=0.30) {
    // Small calibration coupon: same HAP socket geometry as production
    // carriers without the material cost of three full-size platforms.
    core_socket_top(38.0,core_clearance,0,full_hex_shell_h);
}

module lego_to_core_cap(
    nx=4,
    ny=4,
    xy_scale=1.0,
    core_clearance=0.30,
    transition_h=10.0
) {
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;
    z0 = lego_plate_h;
    z1 = lego_plate_h + transition_h;

    union() {
        lego_tile_bottom(nx,ny,xy_scale);

        difference() {
            hull() {
                translate([0,0,z0])
                    centered_cube_xy(w*0.94,d*0.94,0.22,0);

                translate([0,0,z1])
                    linear_extrude(height=0.22)
                        hex2d(gt_support_outer_flat);
            }

            // Internal relief keeps wider transitions light. The 2x4 variant
            // stays solid because the previous relief completely separated the
            // lower LEGO foot from the upper core receiver.
            if (nx >= 4)
                translate([0,0,z0+0.8])
                    hex_prism(gt_support_outer_flat-7.0,transition_h+0.5,0,0);
        }

        core_socket_top(
            gt_support_outer_flat,
            core_clearance,
            z1,
            full_hex_shell_h
        );
    }
}

// -------------------------
// HAP-007 Bridge / multi-anchor carriers
// -------------------------
module bridge_dual_core_carrier(
    nx=8,
    ny=4,
    socket_spacing=32.0,
    xy_scale=1.0,
    core_clearance=0.30,
    deck_h=5.20
) {
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;
    socket_flat = core_nominal_flat + core_clearance;
    z0 = lego_plate_h;

    union() {
        lego_tile_bottom(nx,ny,xy_scale);

        difference() {
            centered_cube_xy(w,d,deck_h,z0);

            for (sx=[-socket_spacing/2,socket_spacing/2]) {
                translate([sx,0,z0+deck_h-core_h])
                    hex_prism(socket_flat,core_h+eps,0,0);

                translate([sx,0,z0-eps])
                    hex_prism(core_nominal_flat-3.0,1.00+eps,0,0);
            }

            // Long underside relief reduces mass while preserving perimeter and socket zones.
            centered_cube_xy(
                max(8,w-2*lego_pitch),
                max(8,d-2*lego_pitch),
                1.20,
                z0+0.60
            );
        }
    }
}

module bridge_dual_gt_carrier(
    nx=8,
    ny=4,
    support_spacing=32.0,
    xy_scale=1.0,
    male_flat=29.78,
    deck_h=3.20
) {
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;
    z0 = lego_plate_h;
    z1 = z0 + deck_h;

    union() {
        lego_tile_bottom(nx,ny,xy_scale);
        centered_cube_xy(w,d,deck_h,z0);

        for (sx=[-support_spacing/2,support_spacing/2])
            translate([sx,0,0])
                gt_support_top(male_flat,z1);
    }
}


// -------------------------
// HAP-008 LEGO Technic interface family
// -------------------------
TECHNIC_HOLE_D = is_undef(TECHNIC_HOLE_D) ? 4.90 : TECHNIC_HOLE_D;
technic_plate_t = 6.40;
technic_edge = 8.00;

module technic_hole_x(d=4.90, len=8.0) {
    rotate([0,90,0])
        cylinder(d=d,h=len,center=true);
}

module technic_hole_coupon(
    hole_d=4.90,
    count=3
) {
    w = technic_plate_t;
    d = 14.0;
    h = (count-1)*lego_pitch + 14.0;

    difference() {
        centered_cube_xy(w,d,h,0);

        for (iz=[0:count-1]) {
            z = 7.0 + iz*lego_pitch;
            translate([0,0,z])
                technic_hole_x(hole_d,w+2*eps);
        }
    }
}

module technic_side_core(
    holes=3,
    hole_d=4.90,
    core_clearance=0.30,
    top_overhang=7.0
) {
    plate_h = (holes-1)*lego_pitch + 16.0;
    plate_w = technic_plate_t;
    plate_d = 16.0;
    cap_z = plate_h;
    cap_flat = gt_support_outer_flat;

    union() {
        difference() {
            centered_cube_xy(plate_w,plate_d,plate_h,0);

            for (iz=[0:holes-1]) {
                z = 8.0 + iz*lego_pitch;
                translate([0,0,z])
                    technic_hole_x(hole_d,plate_w+2*eps);
            }
        }

        // Triangular-ish printable transition to the core receiver.
        hull() {
            translate([0,0,plate_h-2.0])
                centered_cube_xy(plate_w,plate_d,2.0,0);

            translate([0,0,cap_z+top_overhang])
                linear_extrude(height=0.22)
                    hex2d(cap_flat);
        }

        core_socket_top(
            cap_flat,
            core_clearance,
            cap_z+top_overhang,
            full_hex_shell_h
        );
    }
}

// -------------------------
// HAP-009 anti-twist / outrigger family
// -------------------------
module dual_lego_foot_core(
    foot_nx=2,
    foot_ny=2,
    foot_spacing=32.0,
    xy_scale=1.0,
    core_clearance=0.30,
    deck_h=4.0
) {
    foot_w = foot_nx*lego_pitch - lego_gap;
    foot_d = foot_ny*lego_pitch - lego_gap;
    deck_w = foot_spacing + foot_w;
    deck_d = max(foot_d,gt_support_outer_flat);
    z0 = lego_plate_h;

    union() {
        translate([-foot_spacing/2,0,0])
            lego_tile_bottom(foot_nx,foot_ny,xy_scale);

        translate([foot_spacing/2,0,0])
            lego_tile_bottom(foot_nx,foot_ny,xy_scale);

        difference() {
            centered_cube_xy(deck_w,deck_d,deck_h,z0);

            // Large reliefs leave two load paths plus the center core zone.
            for (sx=[-foot_spacing/2,foot_spacing/2])
                translate([sx,0,z0+0.8])
                    centered_cube_xy(
                        max(4,foot_w-6),
                        max(4,foot_d-6),
                        deck_h+eps,
                        0
                    );
        }

        core_socket_top(
            gt_support_outer_flat,
            core_clearance,
            z0+deck_h,
            full_hex_shell_h
        );
    }
}

module cross_outrigger_core(
    foot_spacing=40.0,
    xy_scale=1.0,
    core_clearance=0.30,
    deck_h=4.0
) {
    union() {
        dual_lego_foot_core(2,2,foot_spacing,xy_scale,core_clearance,deck_h);

        rotate([0,0,90])
            dual_lego_foot_core(2,2,foot_spacing,xy_scale,core_clearance,deck_h);
    }
}

// -------------------------
// HAP-010 donor conversion blanks
// -------------------------
module donor_pad_hex(
    pad_flat=gt_tile_flat,
    pad_h=full_hex_shell_h,
    core_clearance=0.30
) {
    socket_flat = core_nominal_flat + core_clearance;

    difference() {
        hex_prism(pad_flat,pad_h,0,0);

        // Production-style top-opening HAP core socket.
        translate([0,0,pad_h-core_h])
            hex_prism(socket_flat,core_h+eps,0,0);

        // Small underside relief limits elephant-foot interference without
        // turning the receiver into a through-hole.
        translate([0,0,-eps])
            hex_prism(core_nominal_flat-3.0,1.00+eps,0,0);
    }
}

module donor_pad_rect(
    w=48.0,
    d=36.0,
    pad_h=full_hex_shell_h,
    core_clearance=0.30
) {
    socket_flat = core_nominal_flat + core_clearance;

    difference() {
        centered_cube_xy(w,d,pad_h,0);

        // The old 48x24 through-cut was narrower than the HAP core socket and
        // split the pad into two separate pieces. A 48x36 receiver preserves a
        // continuous perimeter and uses the same top-opening socket depth as
        // the production carriers.
        translate([0,0,pad_h-core_h])
            hex_prism(socket_flat,core_h+eps,0,0);

        translate([0,0,-eps])
            hex_prism(core_nominal_flat-3.0,1.00+eps,0,0);
    }
}

module donor_core_mount(
    pad_flat=42.0,
    pad_h=2.40,
    overlap=0.20
) {
    // Core body points downward into an existing HAP carrier socket.
    // Attachment pad sits above it and may overlap the donor underside slightly.
    union() {
        translate([0,0,-core_h-pad_h+overlap])
            hex_prism(core_nominal_flat,core_h,0,0);

        translate([0,0,-pad_h+overlap])
            hex_prism(pad_flat,pad_h,0,0);
    }
}

module donor_underbody_hex(
    pad_flat=58.40,
    pad_h=2.40,
    overlap=0.20,
    reinforced=false
) {
    union() {
        donor_core_mount(
            reinforced ? pad_flat : min(pad_flat,46.0),
            pad_h,
            overlap
        );

        if (reinforced)
            translate([0,0,-pad_h+overlap])
                hex_ring(pad_flat,4.0,pad_h,0,0);
    }
}

module donor_underbody_rect(
    w=48.0,
    d=24.0,
    pad_h=2.40,
    overlap=0.20
) {
    union() {
        translate([0,0,-core_h-pad_h+overlap])
            hex_prism(core_nominal_flat,core_h,0,0);

        translate([0,0,-pad_h+overlap])
            centered_cube_xy(w,d,pad_h,0);
    }
}

// -------------------------
// Output selector
// -------------------------
if (PART == "LEGO_CLUTCH_2x2")
    clutch_label_2x2(LEGO_SCALE);

else if (PART == "LEGO_TILE_2x2")
    lego_tile_bottom(2,2,LEGO_SCALE);

else if (PART == "LEGO_TILE_4x4")
    lego_tile_bottom(4,4,LEGO_SCALE);

else if (PART == "GT_MALE_TEST")
    gt_male_test(GT_MALE_FLAT);

else if (PART == "LG2x2_GT")
    lego_to_gt_adapter(2,2,LEGO_SCALE,GT_MALE_FLAT,16.0);

else if (PART == "LG4x4_GT")
    lego_to_gt_adapter(4,4,LEGO_SCALE,GT_MALE_FLAT,8.0);

else if (PART == "FULL_HEX_6x6")
    lego_full_hex_platform(6,6,LEGO_SCALE,0,0,TILE_ROTATION,CORE_CLEARANCE);

else if (PART == "GT_CORE")
    gt_core_insert(GT_MALE_FLAT,core_nominal_flat,TILE_ROTATION,true);

else if (PART == "GT_CORE_BLANK")
    gt_core_blank(core_nominal_flat,TILE_ROTATION);

else if (PART == "CORE_SOCKET_COUPON")
    core_socket_coupon(CORE_CLEARANCE);

else if (PART == "FULL_HEX_OFFSET")
    lego_full_hex_offset(
        OFFSET_X,
        OFFSET_Y,
        TILE_ROTATION,
        6,
        6,
        LEGO_SCALE,
        CORE_CLEARANCE
    );

else if (PART == "LG4x4_GT_OFFSET_DIRECT")
    lego_to_gt_offset_direct(
        4,
        4,
        OFFSET_X,
        OFFSET_Y,
        LEGO_SCALE,
        GT_MALE_FLAT,
        10.0
    );

else if (PART == "SKY_CORE_2x4")
    lego_to_core_cap(2,4,LEGO_SCALE,CORE_CLEARANCE,16.0);

else if (PART == "SKY_CORE_4x4")
    lego_to_core_cap(4,4,LEGO_SCALE,CORE_CLEARANCE,10.0);

else if (PART == "SKY_CORE_4x6")
    lego_to_core_cap(4,6,LEGO_SCALE,CORE_CLEARANCE,8.0);

else if (PART == "BRIDGE_DUAL_CORE_8x4")
    bridge_dual_core_carrier(8,4,32.0,LEGO_SCALE,CORE_CLEARANCE,5.20);

else if (PART == "BRIDGE_DUAL_CORE_10x4")
    bridge_dual_core_carrier(10,4,40.0,LEGO_SCALE,CORE_CLEARANCE,5.20);

else if (PART == "BRIDGE_DUAL_GT_8x4")
    bridge_dual_gt_carrier(8,4,32.0,LEGO_SCALE,GT_MALE_FLAT,3.20);

else if (PART == "TECHNIC_HOLE_COUPON_3")
    technic_hole_coupon(TECHNIC_HOLE_D,3);

else if (PART == "TECHNIC_SIDE_CORE_3H")
    technic_side_core(3,TECHNIC_HOLE_D,CORE_CLEARANCE,7.0);

else if (PART == "TECHNIC_SIDE_CORE_5H")
    technic_side_core(5,TECHNIC_HOLE_D,CORE_CLEARANCE,7.0);

else if (PART == "DUAL_FOOT_CORE_S32")
    dual_lego_foot_core(2,2,32.0,LEGO_SCALE,CORE_CLEARANCE,4.0);

else if (PART == "DUAL_FOOT_CORE_S40")
    dual_lego_foot_core(2,2,40.0,LEGO_SCALE,CORE_CLEARANCE,4.0);

else if (PART == "CROSS_OUTRIGGER_CORE_S40")
    cross_outrigger_core(40.0,LEGO_SCALE,CORE_CLEARANCE,4.0);

else if (PART == "DONOR_PAD_HEX")
    donor_pad_hex(gt_tile_flat,2.40,CORE_CLEARANCE);

else if (PART == "DONOR_PAD_RECT")
    donor_pad_rect(48.0,36.0,2.40,CORE_CLEARANCE);

else if (PART == "DONOR_CORE_MOUNT")
    donor_core_mount(42.0,2.40,0.20);

else if (PART == "DONOR_UNDERBODY_HEX")
    donor_underbody_hex(58.40,2.40,0.20,false);

else if (PART == "DONOR_UNDERBODY_HEX_REINFORCED")
    donor_underbody_hex(58.40,2.40,0.20,true);

else if (PART == "DONOR_UNDERBODY_RECT")
    donor_underbody_rect(48.0,24.0,2.40,0.20);

else
    assert(false,str("Unknown PART: ",PART));
