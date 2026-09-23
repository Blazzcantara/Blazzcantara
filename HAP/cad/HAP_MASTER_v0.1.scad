/*
Hybrid Adapter Pack v0.1 — HAP-002 Calibration + Prototype Master
Original parametric compatibility geometry.
GENERATED != PHYSICALLY VALIDATED.

Units: mm
Default references:
- LEGO-family pitch: 8.0
- Plate height: 3.2
- GT height-support outer hex: 46.0 mm across flats
- GT male connector starting reference: 29.78 mm across flats
*/

$fn = 64;

PART = is_undef(PART) ? "LG4x4_GT" : PART;
LEGO_SCALE = is_undef(LEGO_SCALE) ? 1.000 : LEGO_SCALE;
GT_MALE_FLAT = is_undef(GT_MALE_FLAT) ? 29.78 : GT_MALE_FLAT;

lego_pitch = 8.0;
lego_gap = 0.20;
lego_plate_h = 3.20;
lego_wall = 1.50;
lego_roof = 1.00;
lego_tube_od = 6.50;
lego_tube_id = 4.80;

gt_outer_flat = 46.00;
gt_platform_h = 2.40;
gt_ring_h = 2.00;
gt_ring_wall = 2.00;

eps = 0.02;

module centered_cube_xy(w,d,h,z=0) {
    translate([-w/2,-d/2,z]) cube([w,d,h], center=false);
}

module hex2d(flat) {
    r = flat / sqrt(3);
    polygon(points=[for (a=[0:60:300]) [r*cos(a), r*sin(a)]]);
}

module hex_prism(flat,h,z=0) {
    translate([0,0,z]) linear_extrude(height=h) hex2d(flat);
}

module hex_ring(flat_outer, wall, h, z=0) {
    difference() {
        hex_prism(flat_outer,h,z);
        hex_prism(flat_outer-2*wall,h+2*eps,z-eps);
    }
}

module lego_tile_bottom(nx=2, ny=2, xy_scale=1.0) {
    w = nx*lego_pitch - lego_gap;
    d = ny*lego_pitch - lego_gap;
    cavity_h = lego_plate_h - lego_roof;

    scale([xy_scale,xy_scale,1])
    union() {
        difference() {
            centered_cube_xy(w,d,lego_plate_h,0);
            centered_cube_xy(w-2*lego_wall,d-2*lego_wall,cavity_h+eps,-eps);
        }

        if (nx > 1 && ny > 1)
        for (ix=[0:nx-2])
        for (iy=[0:ny-2]) {
            x = (ix-(nx-2)/2)*lego_pitch;
            y = (iy-(ny-2)/2)*lego_pitch;
            translate([x,y,0])
            difference() {
                cylinder(d=lego_tube_od,h=cavity_h+0.20);
                translate([0,0,-eps]) cylinder(d=lego_tube_id,h=cavity_h+0.20+2*eps);
            }
        }
    }
}

module gt_male_test(flat=29.78) {
    base_flat = 38.0;
    base_h = 2.4;
    union() {
        difference() {
            hex_prism(base_flat,base_h,0);
            hex_prism(flat-2*gt_ring_wall,base_h+2*eps,-eps);
        }
        hex_ring(flat,gt_ring_wall,gt_ring_h,base_h);
    }
}

module gt_support_top(male_flat=29.78, z=0) {
    inner_flat = male_flat - 2*gt_ring_wall;
    union() {
        difference() {
            hex_prism(gt_outer_flat,gt_platform_h,z);
            hex_prism(inner_flat,gt_platform_h+2*eps,z-eps);
        }
        hex_ring(male_flat,gt_ring_wall,gt_ring_h,z+gt_platform_h);
    }
}

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
                translate([0,0,z0]) centered_cube_xy(w*0.94,d*0.94,0.22,0);
                translate([0,0,z1]) linear_extrude(height=0.22) hex2d(gt_outer_flat);
            }
            translate([0,0,z0+0.5])
                hex_prism(inner_flat,transition_h+gt_platform_h+gt_ring_h+2.0,0);
        }

        gt_support_top(male_flat,z1);
    }
}

module clutch_label_2x2(scale_value=1.0) {
    lego_tile_bottom(2,2,scale_value);
    txt = str(round(scale_value*1000)/10, "%");
    translate([0,0,lego_plate_h])
        linear_extrude(height=0.35)
            text(txt,size=3.0,halign="center",valign="center");
}

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
else
    assert(false,str("Unknown PART: ",PART));
