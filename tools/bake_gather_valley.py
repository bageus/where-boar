#!/usr/bin/env python3
"""Bake the gathering woods relief: writes the height map of the gathering map (same 160 x 160 m as the hunt).

More varied than Green Valley (owner, 2026-11-23): many hills, several of them rising into rocky crags,
a long escarpment in the north and rolling ground in between; no river. Run after changing the numbers:
    python tools/bake_gather_valley.py
It rewrites props/gather_heights.tres; running it twice gives the same result. terrain.gd turns slopes
steeper than about 40 degrees into rock and sets cliff walls on them.
"""

from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HEIGHTS = ROOT / "game" / "presentation" / "hunt_map" / "props" / "gather_heights.tres"
HALF = 80  # one height sample per metre
# Rounded hills: x, z, height, radius (ASSUMPTION sizes, D013).
HILLS = [
    (45, 40, 5.0, 16), (-50, 40, 4.0, 13), (62, -10, 6.0, 15), (-62, -8, 5.0, 14), (20, 5, 3.0, 12),
    (-22, 12, 3.5, 11), (5, -30, 4.0, 13), (-35, -60, 4.5, 14), (40, -60, 5.5, 15), (-8, 40, 2.5, 10),
    (68, 55, 3.0, 11), (-68, 62, 3.0, 11), (25, 60, 2.0, 10), (-30, 62, 2.0, 9),
]
# Hills that rise into crags (owner: hills turn into cliffs): x, z, hill height, hill radius, crag height,
# crag top radius. The hill is walkable; the crag on it is a steep rocky block.
CRAGS = [(45, 40, 4.0, 18, 5.0, 5.0), (-62, -8, 4.0, 16, 6.0, 4.0), (40, -60, 4.0, 17, 7.0, 6.0),
         (5, -30, 3.0, 14, 4.0, 4.0), (-50, 40, 3.0, 14, 5.0, 3.5)]
# Escarpment in the north: from x0 to x1 at z, height, cliff to the south, gentle rise from the north.
SCARP = (-70.0, 20.0, -45.0, 6.0)
HOLLOWS = [(-5, 15, 1.0, 9), (30, -25, 1.0, 8), (-40, 20, 0.8, 7)]
FLAT_SPOTS = [(0, 70, 8), (6, 73, 6)]  # the hunter's start and the way back to camp


def smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(1.0, max(0.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def bump(x: float, z: float, cx: float, cz: float, radius: float) -> float:
    d = math.hypot(x - cx, z - cz)
    return 0.5 * (1.0 + math.cos(math.pi * d / radius)) if d < radius else 0.0


def crag(x: float, z: float, cx: float, cz: float, height: float, top: float) -> float:
    """A rocky block on a hill top, its edge a bit ragged so the cliff walls do not read as a ring."""
    d = math.hypot(x - cx, z - cz)
    angle = math.atan2(z - cz, x - cx)
    edge = top * (1.0 + 0.25 * math.sin(3.0 * angle + cx) + 0.15 * math.sin(5.0 * angle + cz))
    return height * (1.0 - smooth(edge, edge + 2.5, d))


def scarp(x: float, z: float) -> float:
    x0, x1, cz, height = SCARP
    along = smooth(x0, x0 + 8.0, x) * (1.0 - smooth(x1 - 8.0, x1, x))
    face = cz + 3.0 * math.sin(x * 0.15)
    across = smooth(face + 3.0, face, z) * (1.0 - smooth(face - 6.0, face - 26.0, z))  # cliff south, slope north
    return height * along * across


def raw_height(x: float, z: float) -> float:
    h = 1.0 + 1.2 * math.sin(x * 0.07 + 0.3) * math.sin(z * 0.06 + 1.1) + 0.6 * math.sin(x * 0.15 - z * 0.11) \
        + 0.3 * math.sin(x * 0.31 + 2.0) * math.sin(z * 0.27)
    for cx, cz, height, radius in HILLS:
        h += height * bump(x, z, cx, cz, radius)
    for cx, cz, height, radius, crag_h, top in CRAGS:
        h += height * bump(x, z, cx, cz, radius) + crag(x, z, cx, cz, crag_h, top)
    for cx, cz, depth, radius in HOLLOWS:
        h -= depth * bump(x, z, cx, cz, radius)
    h += scarp(x, z)
    h = max(h, 0.0)  # no water here: low ground stays grass, not mud
    return 1.0 + (h - 1.0) * (1.0 - smooth(72.0, 79.0, max(abs(x), abs(z))))  # level ground along the walls


def height(x: float, z: float) -> float:
    h = raw_height(x, z)
    for cx, cz, radius in FLAT_SPOTS:
        w = 1.0 - smooth(radius, radius + 4.0, math.hypot(x - cx, z - cz))
        h += (raw_height(cx, cz) - h) * w
    return round(h, 3)


def main() -> None:
    size = 2 * HALF + 1
    data = ", ".join(f"{height(i - HALF, j - HALF):g}" for j in range(size) for i in range(size))
    HEIGHTS.write_text(
        '[gd_resource type="HeightMapShape3D" format=3]\n\n[resource]\n'
        f"map_width = {size}\nmap_depth = {size}\nmap_data = PackedFloat32Array({data})\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
