/*
HAP LEGO Structural Pack v0.1
Original parametric LEGO-compatible structural geometry for HAP / GraviTrax support.

Reality:
- digitally generated geometry
- nominal LEGO-compatible dimensions
- not physically fit-sealed unless explicitly tested

Units: mm.
*/

$fn = 64;

PART = is_undef(PART) ? "BRICK_2x4_H1" : PART;

LEGO_PITCH = is_undef(LEGO_PITCH) ? 8.00 : LEGO_PITCH;
LEGO_GAP = is_undef(LEGO_GAP) ? 0.20 : LEGO_GAP;
LEGO_PLATE_H = is_undef(LEGO_PLATE_H) ? 3.20 : LEGO_PLATE_H;
LEGO_BRICK_H = is_undef(LEGO_BRICK_H) ? 9.60 : LEGO_BRICK_H;
LEGO_STUD_D = is_undef(LEGO_STUD_D) ? 4.80 : LEGO_STUD_D;
LEGO_STUD_H = is_undef(LEGO_STUD_H) ? 1.80 : LEGO_STUD_H;
LEGO_WALL = is_undef(LEGO_WALL) ? 1.50 : LEGO_WALL;
LEGO_ROOF = is_undef(LEGO_ROOF) ? 1.00 : LEGO_ROOF;
LEGO_TUBE_OD = is_undef(LEGO_TUBE_OD) ? 6.50 : LEGO_TUBE_OD;
LEGO_TUBE_ID = is_undef(LEGO_TUBE_ID) ? 4.80 : LEGO_TUBE_ID;

// Fit tuning hooks. Nominal direct-print package keeps both at 0.00.
LEGO_CLUTCH_DELTA = is_undef(LEGO_CLUTCH_DELTA) ? 0.00 : LEGO_CLUTCH_DELTA;
LEGO_STUD_DELTA = is_undef(LEGO_STUD_DELTA) ? 0.00 : LEGO_STUD_DELTA;

EPS = 0.02;

assert(LEGO_PITCH == 8.00, "HAP Structural Pack requires fixed 8.00 mm grid pitch.");
assert(LEGO_CLUTCH_DELTA >= -0.20 && LEGO_CLUTCH_DELTA <= 0.20,
       "LEGO_CLUTCH_DELTA outside safe calibration range.");
assert(LEGO_STUD_DELTA >= -0.20 && LEGO_STUD_DELTA <= 0.20,
       "LEGO_STUD_DELTA outside safe calibration range.");

module centered_cube_xy(w,d,h,z=0) {
    translate([-w/2,-d/2,z]) cube([w,d,h], center=false);
}

module top_studs(nx,ny,z) {
    stud_d = LEGO_STUD_D + 2*LEGO_STUD_DELTA;

    for (ix=[0:nx-1])
    for (iy=[0:ny-1]) {
        x = (ix-(nx-1)/2)*LEGO_PITCH;
        y = (iy-(ny-1)/2)*LEGO_PITCH;

        translate([x,y,z])
            cylinder(d=stud_d,h=LEGO_STUD_H);
    }
}

module underside_tubes(nx,ny,h) {
    cavity_h = h - LEGO_ROOF;
    tube_od = LEGO_TUBE_OD + 2*LEGO_CLUTCH_DELTA;

    if (nx > 1 && ny > 1)
    for (ix=[0:nx-2])
    for (iy=[0:ny-2]) {
        x = (ix-(nx-2)/2)*LEGO_PITCH;
        y = (iy-(ny-2)/2)*LEGO_PITCH;

        translate([x,y,0])
        difference() {
            cylinder(d=tube_od,h=cavity_h+0.20);
            translate([0,0,-EPS])
                cylinder(d=LEGO_TUBE_ID,h=cavity_h+0.20+2*EPS);
        }
    }
}

module stackable_block(nx=2,ny=2,h=LEGO_BRICK_H,studs=true) {
    w = nx*LEGO_PITCH - LEGO_GAP;
    d = ny*LEGO_PITCH - LEGO_GAP;
    cavity_h = h - LEGO_ROOF;
    contact_wall = LEGO_WALL + LEGO_CLUTCH_DELTA;

    assert(nx >= 2 && ny >= 2, "Structural Pack blocks require nx>=2 and ny>=2.");
    assert(h >= LEGO_PLATE_H, "Block height below one LEGO-compatible plate.");

    union() {
        difference() {
            centered_cube_xy(w,d,h,0);

            centered_cube_xy(
                w-2*contact_wall,
                d-2*contact_wall,
                cavity_h+EPS,
                -EPS
            );
        }

        underside_tubes(nx,ny,h);

        if (studs)
            top_studs(nx,ny,h);
    }
}

module plate(nx,ny) {
    stackable_block(nx,ny,LEGO_PLATE_H,true);
}

module brick(nx,ny) {
    stackable_block(nx,ny,LEGO_BRICK_H,true);
}

module riser(nx,ny,brick_units) {
    stackable_block(nx,ny,brick_units*LEGO_BRICK_H,true);
}

module tower(nx,ny,brick_units) {
    // Same interface contract as a riser, but named separately for long load-bearing columns.
    stackable_block(nx,ny,brick_units*LEGO_BRICK_H,true);
}

// HAP-optimized support shapes.
// These remain normal LEGO-compatible stackable solids, but use dimensions
// chosen to match common HAP carrier footprints and stable GraviTrax support use.
module foundation(nx,ny,brick_units=1) {
    stackable_block(nx,ny,brick_units*LEGO_BRICK_H,true);
}

module bridge_support(nx,ny,brick_units=3) {
    stackable_block(nx,ny,brick_units*LEGO_BRICK_H,true);
}

module platform_block(nx,ny,brick_units=2) {
    stackable_block(nx,ny,brick_units*LEGO_BRICK_H,true);
}

// -------------------------
// Output selector
// -------------------------

// A — bricks
if (PART == "BRICK_2x2_H1")
    brick(2,2);
else if (PART == "BRICK_2x4_H1")
    brick(2,4);
else if (PART == "BRICK_2x6_H1")
    brick(2,6);
else if (PART == "BRICK_2x8_H1")
    brick(2,8);
else if (PART == "BRICK_4x4_H1")
    brick(4,4);

// B — plates
else if (PART == "PLATE_2x2")
    plate(2,2);
else if (PART == "PLATE_2x4")
    plate(2,4);
else if (PART == "PLATE_4x4")
    plate(4,4);
else if (PART == "PLATE_4x6")
    plate(4,6);
else if (PART == "PLATE_6x6")
    plate(6,6);
else if (PART == "PLATE_8x8")
    plate(8,8);
else if (PART == "PLATE_7x2")
    plate(7,2);
else if (PART == "PLATE_7x7")
    plate(7,7);

// C — risers
else if (PART == "RISER_2x2_H2")
    riser(2,2,2);
else if (PART == "RISER_2x2_H3")
    riser(2,2,3);
else if (PART == "RISER_2x2_H5")
    riser(2,2,5);
else if (PART == "RISER_2x4_H3")
    riser(2,4,3);
else if (PART == "RISER_4x4_H3")
    riser(4,4,3);

// D — towers
else if (PART == "TOWER_2x2_H10")
    tower(2,2,10);
else if (PART == "TOWER_2x4_H10")
    tower(2,4,10);
else if (PART == "TOWER_4x4_H5")
    tower(4,4,5);

// E — HAP-optimized supports
else if (PART == "FOUNDATION_6x6_H1")
    foundation(6,6,1);
else if (PART == "FOUNDATION_8x8_H1")
    foundation(8,8,1);
else if (PART == "FOUNDATION_7x7_H1")
    foundation(7,7,1);
else if (PART == "BRIDGE_SUPPORT_2x6_H5")
    bridge_support(2,6,5);
else if (PART == "BRIDGE_SUPPORT_4x8_H3")
    bridge_support(4,8,3);
else if (PART == "BRIDGE_SUPPORT_10x4_H3")
    bridge_support(10,4,3);
else if (PART == "CROSS_SUPPORT_6x6_H3")
    foundation(6,6,3);
else if (PART == "PLATFORM_BLOCK_6x6_H2")
    platform_block(6,6,2);

else
    assert(false, str("Unknown PART: ",PART));
