/*
HAP-017..019 Native Donor Connector Builder v0.1

The external connector STL is extracted from the user's local archive.
No third-party donor binary is stored in this repository.

Source reference:
Gravitrax Tiles Variations Collection - 4538769 - part 3 of 3/files/hex-connectorNOT-NEEDED-spare.stl
SHA256: 31818bf1c329a458ef9a1a74e477bc0e0d5e2403e64700c77ec5f798962fd4c1

GENERATED != PHYSICALLY VALIDATED.
*/

$fn = 72;

DONOR_FILE = is_undef(DONOR_FILE) ? "" : DONOR_FILE;
MODE = is_undef(MODE) ? "CORE_BRIDGE" : MODE;
CONNECTOR_SCALE = is_undef(CONNECTOR_SCALE) ? 1.000 : CONNECTOR_SCALE;

hap_core_flat = 30.80;
hap_core_h = 3.20;
bridge_overlap = 0.20;

module hex2d(flat) {
    r = flat / sqrt(3);
    polygon(points=[for (a=[0:60:300]) [r*cos(a),r*sin(a)]]);
}

module hex_prism(flat,h,z=0,rot=30) {
    translate([0,0,z])
        rotate([0,0,rot])
            linear_extrude(height=h)
                hex2d(flat);
}

module native_connector() {
    assert(DONOR_FILE != "", "DONOR_FILE must point to the verified local connector STL.");

    scale([CONNECTOR_SCALE,CONNECTOR_SCALE,1])
        import(file=DONOR_FILE,convexity=20);
}

module hap_core_bridge() {
    union() {
        // Lower body inserts into the provisional HAP core socket.
        translate([0,0,-hap_core_h+bridge_overlap])
            hex_prism(hap_core_flat,hap_core_h,0,30);

        // Native donor connector remains the upper tile-facing interface.
        native_connector();
    }
}

if (MODE == "CONNECTOR_ONLY")
    native_connector();
else if (MODE == "CORE_BRIDGE")
    hap_core_bridge();
else
    assert(false,str("Unknown MODE: ",MODE));
