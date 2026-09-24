#!/usr/bin/env python3
"""Dependency-free STL integrity audit for HAP generated parts.

Supports binary and ASCII STL.
Distinguishes:
- watertight surface shells,
- positive-volume outer solid shells,
- negative-volume cavity shells,
- degenerate triangles.

A valid printable solid may contain one positive outer shell plus one or more
negative cavity shells. Multiple positive shells usually indicate disconnected
physical bodies in one STL.
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
        if (
            len(parts) == 5
            and parts[0].lower() == "facet"
            and parts[1].lower() == "normal"
        ):
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


def vkey(vertex, tolerance):
    return tuple(int(round(float(value) / tolerance)) for value in vertex)


def triangle_area(vertices):
    a, b, c = vertices
    ab = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    ac = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    cross = (
        ab[1] * ac[2] - ab[2] * ac[1],
        ab[2] * ac[0] - ab[0] * ac[2],
        ab[0] * ac[1] - ab[1] * ac[0],
    )
    return 0.5 * math.sqrt(sum(value * value for value in cross))


def signed_triangle_volume(vertices):
    a, b, c = vertices
    cross_bc = (
        b[1] * c[2] - b[2] * c[1],
        b[2] * c[0] - b[0] * c[2],
        b[0] * c[1] - b[1] * c[0],
    )
    return (
        a[0] * cross_bc[0]
        + a[1] * cross_bc[1]
        + a[2] * cross_bc[2]
    ) / 6.0


def audit(triangles, tolerance):
    edge_faces = defaultdict(list)
    edge_counts = defaultdict(int)

    mins = [math.inf, math.inf, math.inf]
    maxs = [-math.inf, -math.inf, -math.inf]

    face_keys = []
    degenerate_triangles = 0

    for face_index, (_, vertices, _) in enumerate(triangles):
        keys = [vkey(vertex, tolerance) for vertex in vertices]
        face_keys.append(keys)

        if triangle_area(vertices) <= tolerance * tolerance:
            degenerate_triangles += 1

        for vertex in vertices:
            for axis in range(3):
                mins[axis] = min(mins[axis], float(vertex[axis]))
                maxs[axis] = max(maxs[axis], float(vertex[axis]))

        for a, b in ((keys[0], keys[1]), (keys[1], keys[2]), (keys[2], keys[0])):
            edge = (a, b) if a <= b else (b, a)
            edge_counts[edge] += 1
            edge_faces[edge].append(face_index)

    # Surface-shell connectivity is edge-based. Merely touching at a vertex does
    # not make two printable shells one physical body.
    adjacency = [set() for _ in triangles]
    for faces in edge_faces.values():
        if len(faces) > 1:
            for face in faces:
                adjacency[face].update(other for other in faces if other != face)

    seen = set()
    shell_faces = []

    for start in range(len(triangles)):
        if start in seen:
            continue

        stack = [start]
        seen.add(start)
        faces = []

        while stack:
            current = stack.pop()
            faces.append(current)
            for other in adjacency[current]:
                if other not in seen:
                    seen.add(other)
                    stack.append(other)

        shell_faces.append(faces)

    shell_volumes = []
    shell_triangles = []

    for faces in shell_faces:
        volume = 0.0
        for face_index in faces:
            volume += signed_triangle_volume(triangles[face_index][1])
        shell_volumes.append(volume)
        shell_triangles.append(len(faces))

    volume_epsilon = max(tolerance ** 3, 1e-12)
    positive_shells = sum(volume > volume_epsilon for volume in shell_volumes)
    negative_shells = sum(volume < -volume_epsilon for volume in shell_volumes)
    near_zero_shells = len(shell_volumes) - positive_shells - negative_shells

    bad_edges = sum(1 for count in edge_counts.values() if count != 2)
    boundary_edges = sum(1 for count in edge_counts.values() if count == 1)
    nonmanifold_edges = sum(1 for count in edge_counts.values() if count > 2)
    extents = [maxs[index] - mins[index] for index in range(3)]

    return {
        "triangles": len(triangles),
        "components": len(shell_faces),
        "surface_shells": len(shell_faces),
        "component_triangles_desc": sorted(shell_triangles, reverse=True),
        "shell_signed_volume_mm3": [round(value, 6) for value in shell_volumes],
        "positive_shells": positive_shells,
        "negative_shells": negative_shells,
        "near_zero_shells": near_zero_shells,
        "net_signed_volume_mm3": round(sum(shell_volumes), 6),
        "watertight_edge_test": bad_edges == 0,
        "non_two_manifold_edge_count": bad_edges,
        "boundary_edge_count": boundary_edges,
        "nonmanifold_edge_count": nonmanifold_edges,
        "degenerate_triangle_count": degenerate_triangles,
        "bbox_min_mm": [round(value, 6) for value in mins],
        "bbox_max_mm": [round(value, 6) for value in maxs],
        "bbox_extent_mm": [round(value, 6) for value in extents],
        "weld_tolerance_mm": tolerance,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("stl", type=Path)
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--tolerance", type=float, default=1e-5)
    parser.add_argument("--expect-components", type=int)
    parser.add_argument("--expect-positive-shells", type=int)
    parser.add_argument("--require-watertight", action="store_true")
    parser.add_argument("--require-no-degenerate", action="store_true")
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

    if (
        args.expect_positive_shells is not None
        and result["positive_shells"] != args.expect_positive_shells
    ):
        failed = True

    if args.require_watertight and not result["watertight_edge_test"]:
        failed = True

    if args.require_no_degenerate and result["degenerate_triangle_count"] != 0:
        failed = True

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
