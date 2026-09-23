#!/usr/bin/env python3
"""Minimal STL integrity audit for HAP generated parts.

No third-party Python packages required.
Supports both binary and ASCII STL output.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
from collections import defaultdict
from pathlib import Path


def read_binary_stl_bytes(data: bytes):
    if len(data) < 84:
        return None

    tri_count = struct.unpack_from("<I", data, 80)[0]
    expected = 84 + 50 * tri_count
    if expected != len(data):
        return None

    triangles = []
    offset = 84
    for _ in range(tri_count):
        normal = struct.unpack_from("<3f", data, offset)
        offset += 12

        vertices = []
        for _ in range(3):
            vertices.append(struct.unpack_from("<3f", data, offset))
            offset += 12

        attribute = struct.unpack_from("<H", data, offset)[0]
        offset += 2
        triangles.append((normal, vertices, attribute))

    return triangles


def read_ascii_stl_bytes(data: bytes):
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ValueError("STL is neither valid binary nor UTF-8 ASCII STL") from exc

    triangles = []
    current_normal = (0.0, 0.0, 0.0)
    vertices = []

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        parts = line.split()
        if len(parts) == 5 and parts[0].lower() == "facet" and parts[1].lower() == "normal":
            current_normal = tuple(float(v) for v in parts[2:5])
        elif len(parts) == 4 and parts[0].lower() == "vertex":
            vertices.append(tuple(float(v) for v in parts[1:4]))
        elif parts[0].lower() == "endfacet":
            if len(vertices) != 3:
                raise ValueError(
                    f"Malformed ASCII STL facet: expected 3 vertices, got {len(vertices)}"
                )
            triangles.append((current_normal, vertices, 0))
            vertices = []
            current_normal = (0.0, 0.0, 0.0)

    if vertices:
        raise ValueError("Malformed ASCII STL: unterminated facet")
    if not triangles:
        raise ValueError("No triangles found in ASCII STL")

    return triangles


def read_stl(path: Path):
    data = path.read_bytes()
    if len(data) < 16:
        raise ValueError("STL is too short")

    triangles = read_binary_stl_bytes(data)
    if triangles is not None:
        return triangles, "binary"

    return read_ascii_stl_bytes(data), "ascii"


def vkey(v, tolerance):
    return tuple(int(round(float(x) / tolerance)) for x in v)


def audit(triangles, tolerance):
    vertex_faces = defaultdict(list)
    edge_counts = defaultdict(int)

    mins = [math.inf, math.inf, math.inf]
    maxs = [-math.inf, -math.inf, -math.inf]

    face_keys = []
    for face_index, (_, vertices, _) in enumerate(triangles):
        keys = [vkey(v, tolerance) for v in vertices]
        face_keys.append(keys)

        for v, key in zip(vertices, keys):
            vertex_faces[key].append(face_index)
            for axis in range(3):
                mins[axis] = min(mins[axis], float(v[axis]))
                maxs[axis] = max(maxs[axis], float(v[axis]))

        for a, b in ((keys[0], keys[1]), (keys[1], keys[2]), (keys[2], keys[0])):
            edge = (a, b) if a <= b else (b, a)
            edge_counts[edge] += 1

    adjacency = [set() for _ in triangles]
    for faces in vertex_faces.values():
        if len(faces) > 1:
            for face in faces:
                adjacency[face].update(other for other in faces if other != face)

    seen = set()
    component_sizes = []

    for start in range(len(triangles)):
        if start in seen:
            continue

        stack = [start]
        seen.add(start)
        size = 0

        while stack:
            current = stack.pop()
            size += 1
            for other in adjacency[current]:
                if other not in seen:
                    seen.add(other)
                    stack.append(other)

        component_sizes.append(size)

    bad_edges = sum(1 for count in edge_counts.values() if count != 2)
    extents = [maxs[i] - mins[i] for i in range(3)]

    return {
        "triangles": len(triangles),
        "components": len(component_sizes),
        "component_triangles_desc": sorted(component_sizes, reverse=True),
        "watertight_edge_test": bad_edges == 0,
        "non_two_manifold_edge_count": bad_edges,
        "bbox_min_mm": [round(v, 6) for v in mins],
        "bbox_max_mm": [round(v, 6) for v in maxs],
        "bbox_extent_mm": [round(v, 6) for v in extents],
        "weld_tolerance_mm": tolerance,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("stl", type=Path)
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--tolerance", type=float, default=1e-5)
    parser.add_argument("--expect-components", type=int)
    parser.add_argument("--require-watertight", action="store_true")
    args = parser.parse_args()

    triangles, stl_format = read_stl(args.stl)
    result = audit(triangles, args.tolerance)
    result["file"] = args.stl.name
    result["stl_format"] = stl_format

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(json.dumps(result, indent=2))

    failed = False
    if args.expect_components is not None and result["components"] != args.expect_components:
        failed = True
    if args.require_watertight and not result["watertight_edge_test"]:
        failed = True

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
