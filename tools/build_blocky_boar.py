#!/usr/bin/env python3
"""Build the owner's reference boar (blocky brown body, square snout, cream tusks, dark hooves)
as an unrigged source .glb for tools/rig_boars.py, which rigs and animates it:
    python tools/build_blocky_boar.py /tmp/blocky_boar.glb
    python tools/rig_boars.py common_brown /tmp/blocky_boar.glb

Needs Blender as a Python module (`pip install bpy`). Authored like the Meshy sources: Z up, snout
towards -Y, metres; rig_boars.py scales it to the type's length. One mesh, flat colours per face.
"""

from __future__ import annotations

import math
import sys

import bpy  # first: it provides bmesh
import bmesh
from mathutils import Matrix, Vector


def srgb(r: float, g: float, b: float) -> tuple:
    """glTF base colours are linear; the colours below are picked from the reference (sRGB)."""
    lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), 1.0)


COLOURS = {
    "fur": srgb(0.50, 0.28, 0.18),
    "snout": srgb(0.72, 0.44, 0.28),
    "ear": srgb(0.43, 0.23, 0.15),
    "hoof": srgb(0.20, 0.18, 0.21),
    "tusk": srgb(0.95, 0.89, 0.70),
    "dark": srgb(0.12, 0.07, 0.06),
}
HOOF = 0.13  # hoof height, m
SLOT = {name: i for i, name in enumerate(COLOURS)}


def box(bm: bmesh.types.BMesh, lo: tuple, hi: tuple, colour: str, bevel: float = 0.0, top_scale: float = 1.0) -> list:
    """Axis box from lo to hi; bevel chamfers every edge once (the reference's cut corners); top_scale narrows the top face in X."""
    centre = (Vector(lo) + Vector(hi)) / 2
    size = Vector(hi) - Vector(lo)
    geom = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(centre) @ Matrix.Diagonal((*size, 1.0)))
    verts = geom["verts"]
    if top_scale != 1.0:
        for v in verts:
            if v.co.z > centre.z:
                v.co.x = centre.x + (v.co.x - centre.x) * top_scale
    faces = list({f for v in verts for f in v.link_faces})
    if bevel > 0.0:
        edges = list({e for v in verts for e in v.link_edges})
        result = bmesh.ops.bevel(bm, geom=verts + edges, offset=bevel, segments=1, affect="EDGES", profile=0.5)
        faces = list({f for v in result["verts"] for f in v.link_faces})  # the inset sides and the chamfers
    for f in faces:
        f.material_index = SLOT[colour]
    return faces


def wedge(bm: bmesh.types.BMesh, base: Vector, tip: Vector, radius: float, colour: str) -> None:
    """Four-sided pyramid from a square base around `base` to `tip` (ears, tusk tips)."""
    axis = (tip - base).normalized()
    side = axis.cross(Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))).normalized()
    up = axis.cross(side)
    ring = [bm.verts.new(base + (side * math.cos(a) + up * math.sin(a)) * radius) for a in
            (math.pi / 4 + i * math.pi / 2 for i in range(4))]
    top = bm.verts.new(tip)
    faces = [bm.faces.new((ring[i], ring[(i + 1) % 4], top)) for i in range(4)]
    faces.append(bm.faces.new(list(reversed(ring))))
    for f in faces:
        f.material_index = SLOT[colour]


def tusk(bm: bmesh.types.BMesh, side: float) -> None:
    """Short cream tusk: a stub out of the snout side, then a pointed tip bent up and back."""
    root = Vector((0.18 * side, -0.82, 0.50))
    bend = Vector((0.31 * side, -0.85, 0.56))
    tip = Vector((0.35 * side, -0.80, 0.80))
    wedge(bm, root, bend + (bend - root) * 0.5, 0.075, "tusk")
    wedge(bm, bend, tip, 0.07, "tusk")


def leg(bm: bmesh.types.BMesh, x: float, y: float) -> None:
    """Square leg from the body down to a dark hoof block of the same width."""
    box(bm, (x - 0.11, y - 0.11, HOOF - 0.01), (x + 0.11, y + 0.11, 0.42), "fur", bevel=0.015)
    box(bm, (x - 0.115, y - 0.115, 0.0), (x + 0.115, y + 0.115, HOOF), "hoof", bevel=0.015)


def build() -> bmesh.types.BMesh:
    bm = bmesh.new()
    # Body: a tall rounded block, narrower on top, chamfered all round.
    box(bm, (-0.47, -0.46, 0.27), (0.47, 0.80, 1.16), "fur", bevel=0.2, top_scale=0.84)
    # Head: a block set into the front of the body, a little lower than the back.
    box(bm, (-0.32, -0.76, 0.46), (0.32, -0.30, 0.96), "fur", bevel=0.05)
    # Snout: lighter, square, sticking out low on the head; nostrils are dark slots on its end.
    box(bm, (-0.23, -1.00, 0.40), (0.23, -0.70, 0.70), "snout", bevel=0.035)
    for side in (-1, 1):
        box(bm, (0.09 * side - 0.035, -1.006, 0.50), (0.09 * side + 0.035, -0.99, 0.62), "dark")
        box(bm, (0.15 * side - 0.03, -0.768, 0.79), (0.15 * side + 0.03, -0.75, 0.88), "dark")  # eyes
        wedge(bm, Vector((0.22 * side, -0.50, 0.92)), Vector((0.30 * side, -0.58, 1.13)), 0.11, "ear")
        tusk(bm, side)
    for x in (-0.26, 0.26):
        for y in (-0.20, 0.58):
            leg(bm, x, y)
    # Stub tail on the rump.
    box(bm, (-0.035, 0.79, 0.82), (0.035, 0.89, 0.94), "fur")
    return bm


def main() -> None:
    out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else sys.argv[1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    data = bpy.data.meshes.new("blocky_boar")
    build().to_mesh(data)
    for name, colour in COLOURS.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = 0.9
        data.materials.append(mat)
    obj = bpy.data.objects.new("blocky_boar", data)
    bpy.context.scene.collection.objects.link(obj)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB")
    print("triangles:", sum(len(p.vertices) - 2 for p in data.polygons))


if __name__ == "__main__":
    main()
