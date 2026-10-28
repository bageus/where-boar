#!/usr/bin/env python3
"""Build the cartoon low-poly models (GAME_SPEC section 17) as .glb files in assets/models/.

Each model is a list of flat-shaded parts, each with a colour from COLOURS. Every colour is one
surface and one material named after it, so few colours keep draw calls low. "hide" is white:
the game tints it per boar type. Run after a change:
    python tools/build_models.py
The output is deterministic, so running it twice gives the same files.
"""

from __future__ import annotations

import json
import math
import random
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
# sRGB, as a colour picker shows them; written to glTF as linear.
COLOURS = {
    "hide": (1.0, 1.0, 1.0),
    "bark": (0.45, 0.28, 0.14),
    "leaf": (0.22, 0.62, 0.2),
    "stone": (0.55, 0.55, 0.58),
    "snout": (0.86, 0.6, 0.58),
    "tusk": (0.97, 0.94, 0.82),
    "dark": (0.1, 0.07, 0.06),
    "wood": (0.62, 0.43, 0.24),
    "rope": (0.86, 0.78, 0.55),
    "flint": (0.42, 0.44, 0.5),
    "skin": (0.93, 0.7, 0.52),
    "leather": (0.5, 0.3, 0.15),
    "canvas": (0.82, 0.7, 0.5),
    "straw": (0.88, 0.76, 0.4),
    "flame": (1.0, 0.45, 0.1),
    "glow": (1.0, 0.85, 0.3),
}
(HIDE, BARK, LEAF, STONE, SNOUT, TUSK, DARK, WOOD, ROPE, FLINT, SKIN, LEATHER, CANVAS, STRAW, FLAME,
 GLOW) = COLOURS


# ---- shapes: each returns a list of triangles (three xyz tuples) ----

def _icosphere() -> tuple[list, list]:
    t = (1.0 + 5 ** 0.5) / 2.0
    verts = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
             (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    verts = [_norm(v) for v in verts]
    faces = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2), (10, 7, 6),
             (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10),
             (8, 6, 7), (9, 8, 1)]
    return verts, faces


def ball(center, radii, jitter=0.0, seed=0, detail=0) -> list:
    """Low-poly ellipsoid; jitter moves shared vertices so the surface stays closed."""
    verts, faces = _icosphere()
    for _ in range(detail):
        cache: dict = {}
        def mid(a, b):
            key = (min(a, b), max(a, b))
            if key not in cache:
                cache[key] = len(verts)
                verts.append(_norm(tuple((verts[a][i] + verts[b][i]) / 2 for i in range(3))))
            return cache[key]
        new = []
        for a, b, c in faces:
            ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
            new += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
        faces = new
    rng = random.Random(seed)
    pts = [tuple(center[i] + v[i] * radii[i] * (1.0 + rng.uniform(-jitter, jitter)) for i in range(3)) for v in verts]
    return [(pts[a], pts[b], pts[c]) for a, b, c in faces]


def rod(p0, p1, r0, r1, sides=6) -> list:
    """Frustum from p0 (radius r0) to p1 (radius r1); r1 = 0 makes a cone."""
    axis = _norm(_sub(p1, p0))
    u = _norm(_cross(axis, (0, 0, 1) if abs(axis[1]) > 0.9 else (0, 1, 0)))
    v = _cross(axis, u)
    def ring(p, r):
        return [tuple(p[i] + r * (math.cos(a) * u[i] + math.sin(a) * v[i]) for i in range(3))
                for a in (2 * math.pi * k / sides for k in range(sides))]
    a, b = ring(p0, r0), ring(p1, r1)
    tris = []
    for k in range(sides):
        n = (k + 1) % sides
        tris += [(a[k], a[n], b[n]), (a[k], b[n], b[k])]
        tris.append((p0, a[n], a[k]))
        if r1 > 0:
            tris.append((p1, b[k], b[n]))
    return [t for t in tris if _area(t) > 1e-9]


def box(center, size) -> list:
    h = [s / 2 for s in size]
    c = [tuple(center[i] + (h[i] if (k >> i) & 1 else -h[i]) for i in range(3)) for k in range(8)]
    quads = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return [t for a, b, cc, d in quads for t in ((c[a], c[b], c[cc]), (c[a], c[cc], c[d]))]


# ---- models: lists of (colour, triangles); facing -Z, standing on y = 0 ----

def boar() -> list:
    parts = [
        (HIDE, ball((0, 0.62, 0.1), (0.46, 0.42, 0.72), 0.06, 1)),
        (HIDE, ball((0, 0.68, -0.62), (0.36, 0.35, 0.36), 0.05, 2)),
        (SNOUT, rod((0, 0.58, -0.86), (0, 0.55, -1.12), 0.18, 0.16, 8)),
        (HIDE, rod((0, 0.75, 0.78), (0, 0.5, 0.95), 0.04, 0.02, 4)),
    ]
    for s in (-1, 1):
        parts += [
            (TUSK, rod((s * 0.14, 0.5, -1.0), (s * 0.22, 0.76, -1.13), 0.045, 0.0, 5)),
            (DARK, ball((s * 0.17, 0.8, -0.9), (0.06, 0.07, 0.04))),
            (HIDE, rod((s * 0.2, 0.92, -0.55), (s * 0.34, 1.18, -0.5), 0.11, 0.0, 4)),
        ]
        for z in (-0.35, 0.5):
            parts += [(HIDE, rod((s * 0.24, 0.5, z), (s * 0.24, 0.08, z), 0.11, 0.08, 6)),
                      (DARK, rod((s * 0.24, 0.1, z), (s * 0.24, 0.0, z), 0.085, 0.09, 6))]
    for k in range(6):
        z = -0.45 + k * 0.17
        parts.append((DARK, rod((0, 0.98 - 0.08 * abs(k - 1.5) ** 1.2 * 0.5, z), (0, 1.2 - 0.03 * k, z + 0.1), 0.07, 0.0, 4)))
    return parts


def tree() -> list:
    parts = [(BARK, rod((0, -0.2, 0), (0, 3.6, 0), 0.4, 0.26, 7))]
    for k, (x, y, z, r) in enumerate([(0, 4.7, 0, 1.8), (0.9, 4.2, 0.5, 1.2), (-0.8, 4.4, -0.6, 1.3), (0.1, 5.8, -0.2, 1.2)]):
        parts.append((LEAF, ball((x, y, z), (r, r * 0.85, r), 0.12, 10 + k, 1)))
    return parts


def bush() -> list:
    return [(LEAF, ball((x, 0.5, z), (r, r * 0.75, r), 0.12, 20 + k, 1))
            for k, (x, z, r) in enumerate([(0, 0, 0.8), (0.45, 0.25, 0.55), (-0.4, -0.3, 0.6), (0.1, -0.45, 0.5)])]


def rock() -> list:
    return [(STONE, ball((0, 0.5, 0), (1.05, 0.7, 1.05), 0.15, 30, 1))]


def stone() -> list:
    return [(STONE, ball((0, 0.08, 0), (0.13, 0.1, 0.12), 0.15, 40))]


# Weapons keep the frames of the grey-box meshes they replace in hands.tscn: the long ones run along +y.

def spear() -> list:
    return [(WOOD, rod((0, -0.8, 0), (0, 0.8, 0), 0.025, 0.022, 6)),
            (ROPE, rod((0, 0.74, 0), (0, 0.82, 0), 0.032, 0.032, 6)),
            (FLINT, ball((0, 0.92, 0), (0.05, 0.16, 0.02), 0.05, 50))]


def arrow() -> list:
    return [(WOOD, rod((0, -0.4, 0), (0, 0.32, 0), 0.01, 0.01, 5)),
            (FLINT, ball((0, 0.36, 0), (0.025, 0.06, 0.008))),
            (DARK, box((0, -0.34, 0), (0.07, 0.1, 0.004))), (DARK, box((0, -0.34, 0), (0.004, 0.1, 0.07)))]


def club() -> list:
    parts = [(WOOD, rod((0, -0.35, 0), (0, 0.3, 0), 0.03, 0.05, 6)),
             (LEATHER, rod((0, -0.33, 0), (0, -0.15, 0), 0.036, 0.04, 6)),
             (WOOD, ball((0, 0.38, 0), (0.12, 0.15, 0.12), 0.08, 51, 1))]
    for k in range(5):
        a = 2 * math.pi * k / 5
        base = (0.1 * math.cos(a), 0.38 + 0.05 * (k % 2), 0.1 * math.sin(a))
        parts.append((FLINT, rod(base, (0.18 * math.cos(a), base[1] + 0.03, 0.18 * math.sin(a)), 0.03, 0.0, 4)))
    return parts


def sling() -> list:
    return [(ROPE, rod((0, 0.2, 0), (0, -0.18, 0), 0.01, 0.01, 4)),
            (LEATHER, ball((0, -0.22, 0), (0.06, 0.04, 0.06))),
            (STONE, ball((0, -0.19, 0), (0.04, 0.035, 0.04), 0.1, 52))]


def bow() -> list:
    arc = [(0.0, 0.48), (0.06, 0.3), (0.085, 0.1), (0.085, -0.1), (0.06, -0.3), (0.0, -0.48)]
    parts = [(WOOD, rod((x0, y0, 0), (x1, y1, 0), 0.02, 0.02, 5)) for (x0, y0), (x1, y1) in zip(arc, arc[1:])]
    return parts + [(ROPE, rod((0, 0.48, 0), (0, -0.48, 0), 0.004, 0.004, 3)),
                    (LEATHER, rod((0.085, -0.08, 0), (0.085, 0.08, 0), 0.026, 0.026, 6))]


def knife() -> list:
    return [(WOOD, rod((0, 0, 0.07), (0, 0, -0.06), 0.02, 0.018, 6)),
            (FLINT, ball((0, 0, -0.17), (0.032, 0.01, 0.12), 0.08, 53))]


def net_bundle() -> list:
    return [(ROPE, ball((0, 0, 0), (0.16, 0.07, 0.15), 0.2, 54, 1))]


def hand() -> list:
    """A fist at the origin and a forearm reaching back to the bottom right of the view."""
    return [(SKIN, ball((0, 0, 0), (0.05, 0.045, 0.06), 0.08, 55)),
            (SKIN, rod((0.01, -0.01, 0.03), (0.06, -0.12, 0.32), 0.035, 0.045, 6)),
            (LEATHER, rod((0.04, -0.07, 0.2), (0.07, -0.14, 0.36), 0.05, 0.055, 6))]


# Camp: sizes match the collision boxes in game/presentation/camp/props.

def tent() -> list:
    a, b, c, d, l, r = (-2, 0, -2), (2, 0, -2), (2, 0, 2), (-2, 0, 2), (0, 3, -2), (0, 3, 2)
    parts = [(CANVAS, [(a, l, b), (d, c, r), (a, d, r), (a, r, l), (b, l, r), (b, r, c)]),
             (DARK, [((-0.6, 0.01, -2.02), (0, 1.8, -2.02), (0.6, 0.01, -2.02))])]
    for z in (-2.05, 2.05):
        parts += [(WOOD, rod((-0.5, 3.6, z), (0.3, 2.4, z), 0.06, 0.06, 5)), (WOOD, rod((0.5, 3.6, z), (-0.3, 2.4, z), 0.06, 0.06, 5))]
    return parts


def fence() -> list:
    """Palisade 40 m long along x."""
    parts = []
    for k in range(81):
        x = -20 + k * 0.5
        h = 1.4 + 0.12 * ((k * 7) % 3)
        parts += [(BARK, rod((x, -0.1, 0), (x, h, 0), 0.13, 0.12, 5)), (BARK, rod((x, h, 0), (x, h + 0.3, 0), 0.12, 0.0, 5))]
    return parts + [(WOOD, box((0, y, 0.15), (40, 0.12, 0.08))) for y in (0.45, 1.1)]


def stall() -> list:
    parts = [(WOOD, box((0, 0.45, 0), (2, 0.9, 0.8))), (STRAW, box((0, 2.3, 0), (2.5, 0.14, 1.5)))]
    for x in (-0.95, 0.95):
        for z in (-0.45, 0.45):
            parts.append((BARK, rod((x, 0, z), (x, 2.25, z), 0.06, 0.06, 5)))
    return parts


def campfire() -> list:
    parts = [(STONE, ball((0.75 * math.cos(a), 0.1, 0.75 * math.sin(a)), (0.2, 0.15, 0.2), 0.15, 60 + k))
             for k, a in enumerate(2 * math.pi * k / 9 for k in range(9))]
    for k in range(3):
        a = math.pi * k / 3
        dx, dz = 0.55 * math.cos(a), 0.55 * math.sin(a)
        parts.append((BARK, rod((-dx, 0.08, -dz), (dx, 0.2, dz), 0.08, 0.08, 6)))
    return parts + [(FLAME, rod((0, 0.1, 0), (0, 1.0, 0), 0.35, 0.0, 6)), (GLOW, rod((0.05, 0.1, -0.05), (0.05, 0.7, -0.05), 0.2, 0.0, 5))]


def signpost() -> list:
    return [(BARK, rod((0, 0, 0), (0, 2.0, 0), 0.08, 0.07, 6)), (WOOD, box((0.25, 1.65, -0.1), (1.2, 0.35, 0.08))),
            (WOOD, [((0.85, 1.85, -0.1), (1.15, 1.65, -0.1), (0.85, 1.45, -0.1)), ((0.85, 1.85, -0.1), (0.85, 1.45, -0.1), (1.15, 1.65, -0.1))])]


MODELS = {"tent": tent, "fence": fence, "stall": stall, "campfire": campfire, "signpost": signpost, "boar": boar, "tree": tree, "bush": bush, "rock": rock, "stone": stone, "spear": spear, "arrow": arrow,
          "club": club, "sling": sling, "bow": bow, "knife": knife, "net_bundle": net_bundle, "hand": hand}


# ---- glTF writer ----

def write_glb(path: Path, parts: list) -> None:
    groups: dict[str, list] = {}
    for colour, tris in parts:
        groups.setdefault(colour, []).extend(_outward(tris))
    blob = bytearray()
    views, accessors, prims, materials = [], [], [], []

    def add(data: bytes, count: int, kind: str, **extra) -> int:
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        blob.extend(data)
        blob.extend(b"\0" * (-len(blob) % 4))
        accessors.append({"bufferView": len(views) - 1, "componentType": 5126, "count": count, "type": kind, **extra})
        return len(accessors) - 1

    for name, items in groups.items():
        pos, nrm = [], []
        for tri in items:
            n = _norm(_cross(_sub(tri[1], tri[0]), _sub(tri[2], tri[0])))
            for p in tri:
                pos.append(tuple(round(x, 5) for x in p))
                nrm.append(n)
        attrs = {
            "POSITION": add(_pack(pos), len(pos), "VEC3", min=[min(p[i] for p in pos) for i in range(3)],
                            max=[max(p[i] for p in pos) for i in range(3)]),
            "NORMAL": add(_pack(nrm), len(nrm), "VEC3"),
        }
        materials.append({"name": name, "pbrMetallicRoughness": {
            "baseColorFactor": [c ** 2.2 for c in COLOURS[name]] + [1.0], "metallicFactor": 0.0, "roughnessFactor": 0.9}})
        prims.append({"attributes": attrs, "material": len(materials) - 1})
    doc = {"asset": {"version": "2.0", "generator": "tools/build_models.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
           "nodes": [{"name": path.stem, "mesh": 0}], "meshes": [{"name": path.stem, "primitives": prims}],
           "materials": materials, "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(blob)}]}
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    body = struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(blob), 0x004E4942) + bytes(blob)
    path.write_bytes(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)


def _outward(tris: list) -> list:
    """Wind every triangle counter-clockwise seen from outside; all parts are convex."""
    pts = [p for t in tris for p in t]
    c = tuple(sum(p[i] for p in pts) / len(pts) for i in range(3))
    def facing_out(t):
        n = _cross(_sub(t[1], t[0]), _sub(t[2], t[0]))
        return sum(n[i] * (t[0][i] - c[i]) for i in range(3)) >= 0
    return [t if facing_out(t) else (t[0], t[2], t[1]) for t in tris]


def _pack(rows) -> bytes:
    return struct.pack("<%df" % (3 * len(rows)), *(x for r in rows for x in r))


def _sub(a, b):
    return tuple(a[i] - b[i] for i in range(3))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _norm(a):
    length = math.sqrt(sum(x * x for x in a)) or 1.0
    return tuple(x / length for x in a)


def _area(t) -> float:
    return math.sqrt(sum(x * x for x in _cross(_sub(t[1], t[0]), _sub(t[2], t[0]))))


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, build in MODELS.items():
        parts = build()
        write_glb(OUT / f"{name}.glb", parts)
        print(f"{name}.glb: {sum(len(t) for _, t in parts)} triangles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
