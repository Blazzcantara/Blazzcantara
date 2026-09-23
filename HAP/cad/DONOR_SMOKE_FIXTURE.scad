/*
HAP synthetic donor smoke fixture v0.1
Original test geometry. Not a GraviTrax donor mesh.

Used only by CI to prove that DONOR_CONVERTER_v0.1.scad can
import an external STL and fuse each supported underbody mount.
*/

$fn = 48;

difference() {
    cylinder(d=56.0,h=6.0);
    translate([0,0,2.0])
        cylinder(d=30.0,h=5.0);
}
