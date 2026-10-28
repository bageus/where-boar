#!/usr/bin/env python3
"""Bake the Green Valley relief (D039): writes the terrain height map and puts every map object on it.

The height function below is the single source of the map's shape. Run after changing it:
    python tools/bake_green_valley.py
It rewrites props/terrain_heights.tres and the y of props, river, zones, spawns, hunter and return
point in hunt_map.tscn; running it twice gives the same result.
"""

from __future__ import annotations

import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAP_DIR = ROOT / "game" / "presentation" / "hunt_map"
HEIGHTS = MAP_DIR / "props" / "terrain_heights.tres"
SCENE = MAP_DIR / "public" / "hunt_map.tscn"
HALF = 80  # the map is 160 x 160 m, one height sample per metre
RIVER_Z = -20.0
RIVER_LEVEL = -0.55  # river segment origin; the water surface (terrain.gd) is 5 cm higher
RIVER_SEGMENTS = 36  # wading areas along the river, west to east, overlapping
RIVER_CLEAR = 8.0  # props, zones and spawns keep this far from the river's centre line
BRIDGE_X = -64.0  # a fallen tree across the river (owner, 2026-10-28)
BRIDGE_TOP = 0.9
# Hills: x, z, height, radius (ASSUMPTION sizes, D013).
HILLS = [(40, 35, 5.0, 16), (-50, 32, 3.5, 11), (60, -45, 6.0, 17), (-62, -62, 3.0, 12), (30, -62, 2.5, 12), (65, 62, 3.0, 12)]
# Hollows: x, z, depth, radius.
HOLLOWS = [(-5, 45, 2.5, 11), (-40, -50, 2.0, 9), (20, 15, 1.5, 9)]
LOOKOUT = (-30.0, 25.0, 6.0, 7.0)  # mesa: x, z, height, top radius; cliffs all round, a gentle slope to the east
FLAT_SPOTS = [(0, 70, 8), (6, 73, 6), (0, -75, 5), (-75, 5, 5), (75, 10, 5), (-60, 62, 5), (70, -72, 5), (42, 74, 5), (-35, -74, 5)]


def smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def bump(x: float, z: float, cx: float, cz: float, radius: float) -> float:
    d = math.hypot(x - cx, z - cz)
    return 0.5 * (1.0 + math.cos(math.pi * d / radius)) if d < radius else 0.0


def lookout(x: float, z: float) -> float:
    cx, cz, height, top = LOOKOUT
    d = math.hypot(x - cx, z - cz)
    east = max(0.0, (x - cx) / d) if d > 0 else 0.0
    width = 2.5 + 13.0 * east ** 4  # 2.5 m is a cliff, 15.5 m a walkable slope
    return height * (1.0 - smooth(top, top + width, d))


def river_cliff(x: float, z: float) -> float:
    """A 5 m ridge south of the river: gentle slope up from the south, cliff down to the north."""
    along = smooth(-12.0, -6.0, x) * (1.0 - smooth(16.0, 22.0, x))
    across = smooth(2.0, -9.0, z) if z > -9.0 else 1.0 - smooth(-9.0, -11.5, z)
    return 5.0 * along * across


def river_z(x: float) -> float:
    """The winding river's centre line (owner, 2026-10-28); it stays 6-8 m off the ridge cliff at x -12..22."""
    return RIVER_Z + 6.0 * math.sin(0.05 * x + math.pi) + 2.5 * math.sin(0.13 * x + 1.0)


def river_slope(x: float) -> float:
    return (river_z(x + 0.5) - river_z(x - 0.5))


def river_distance(x: float, z: float) -> float:
    return abs(z - river_z(x)) / math.sqrt(1.0 + river_slope(x) ** 2)


def raw_height(x: float, z: float) -> float:
    h = 1.0 + 0.8 * math.sin(x * 0.06 + 1.3) * math.sin(z * 0.05 + 0.4) + 0.5 * math.sin(x * 0.13 + z * 0.09)
    for cx, cz, height, radius in HILLS:
        h += height * bump(x, z, cx, cz, radius)
    for cx, cz, depth, radius in HOLLOWS:
        h -= depth * bump(x, z, cx, cz, radius)
    h += lookout(x, z) + river_cliff(x, z)
    h = 1.0 + (h - 1.0) * (1.0 - smooth(72.0, 79.0, max(abs(x), abs(z))))  # level ground along the walls
    # River bed: banks ease down into it; one water body, no fords or islands.
    d = river_distance(x, z)
    return h * smooth(3.0, 10.0, d) - 1.2 * (1.0 - smooth(2.0, 6.0, d))


def height(x: float, z: float) -> float:
    h = raw_height(x, z)
    for cx, cz, radius in FLAT_SPOTS:
        w = 1.0 - smooth(radius, radius + 4.0, math.hypot(x - cx, z - cz))
        h += (raw_height(cx, cz) - h) * w
    return round(h, 3)


def write_heights() -> None:
    size = 2 * HALF + 1
    data = ", ".join(f"{height(i - HALF, j - HALF):g}" for j in range(size) for i in range(size))
    HEIGHTS.write_text(
        '[gd_resource type="HeightMapShape3D" format=3]\n\n[resource]\n'
        f"map_width = {size}\nmap_depth = {size}\nmap_data = PackedFloat32Array({data})\n",
        encoding="utf-8",
    )


SNAP_PARENTS = {"Props": 0.0, "EscapeZones": 0.0, "BoarSpawns": 0.5}
SNAP_NODES = {"Hunter": 0.1, "ReturnPoint": 0.0}
TRANSFORM = re.compile(r"transform = Transform3D\(([^)]*)\)")


def snap_scene() -> None:
    blocks = SCENE.read_text(encoding="utf-8").split("\n[node ")
    for k, block in enumerate(blocks[1:], 1):
        name = re.search(r'name="([^"]+)"', block).group(1)
        parent = re.search(r'parent="([^"]+)"', block)
        parent = parent.group(1) if parent else ""
        match = TRANSFORM.search(block)
        if not match:
            continue
        v = [float(n) for n in match.group(1).split(",")]
        if parent == "River":
            x = -79.0 + 158.0 * (int(name.removeprefix("River")) - 1) / (RIVER_SEGMENTS - 1)
            v = _yawed(-math.atan(river_slope(x)), x, RIVER_LEVEL, river_z(x))
        elif parent == "." and name == "Bridge":
            # Across the river: the log's length (local z) runs square to the flow.
            v = _yawed(-math.atan(river_slope(BRIDGE_X)), BRIDGE_X, BRIDGE_TOP, river_z(BRIDGE_X))
        elif parent in SNAP_PARENTS:
            centre = river_z(v[9])
            if abs(v[11] - centre) < RIVER_CLEAR:
                v[11] = centre + math.copysign(RIVER_CLEAR, v[11] - centre)
            v[10] = height(v[9], v[11]) + SNAP_PARENTS[parent]
        elif parent == "." and name in SNAP_NODES:
            v[10] = height(v[9], v[11]) + SNAP_NODES[name]
        else:
            continue
        text = "Transform3D(%s)" % ", ".join(f"{round(n, 3):g}" for n in v)
        blocks[k] = block[: match.start(1) - 12] + text + block[match.end():]
    SCENE.write_text("\n[node ".join(blocks), encoding="utf-8")


def _yawed(yaw: float, x: float, y: float, z: float) -> list[float]:
    """Transform3D numbers for a turn about y (river runs along local x)."""
    c, s = math.cos(yaw), math.sin(yaw)
    return [c, 0.0, s, 0.0, 1.0, 0.0, -s, 0.0, c, x, y, z]


if __name__ == "__main__":
    write_heights()
    snap_scene()
    print(f"Baked {HEIGHTS.relative_to(ROOT)} and snapped {SCENE.relative_to(ROOT)}.")
