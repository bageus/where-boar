#!/usr/bin/env python3
"""Build the rigged toy roosters and turkeys into assets/models/<species>_<build>.glb.

Needs Blender as a Python module (`pip install bpy`). Each bird is made of smooth vinyl-toy parts
(egg body, comb, wattles, sickle tail or fan tail, wings, yellow feet) after the owner's reference
pictures, in our own colours, in two builds: "fat" (a round egg, like the coral rooster) and "thin"
(a small body on a long neck and long legs, like the lanky rooster). Every part is rigid on one
bone (the neck blends from body to head), so the skeleton is simple: body, neck, head, tail, wings,
thighs and shins. Animations: idle, walk, run, peck. Run after a change:
    python tools/build_birds.py [--preview DIR]
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from rig_boars import FPS, _interpolate, _quat  # noqa: E402  same pose conventions as the boars

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"

# sRGB. Own palettes (owner, 2026-10-29: change the colours of the references).
PALETTES = {
    "rooster": {"body": (0.97, 0.92, 0.8), "wing": (0.93, 0.62, 0.18), "comb": (0.86, 0.08, 0.12),
                "tail_a": (0.05, 0.5, 0.52), "tail_b": (0.12, 0.22, 0.5), "tail_c": (0.1, 0.38, 0.22),
                "neck": (0.97, 0.92, 0.8), "head": (0.97, 0.92, 0.8)},
    "turkey": {"body": (0.46, 0.26, 0.15), "wing": (0.78, 0.56, 0.33), "comb": (0.86, 0.12, 0.14),
               "tail_a": (0.3, 0.17, 0.1), "tail_b": (0.08, 0.5, 0.5), "tail_c": (0.96, 0.87, 0.66),
               "neck": (0.55, 0.78, 0.95), "head": (0.55, 0.78, 0.95)},
}
SHARED = {"beak": (1.0, 0.76, 0.18), "feet": (1.0, 0.8, 0.22), "eye": (0.12, 0.05, 0.14), "cheek": (1.0, 0.62, 0.6)}

# build -> body centre and radii (x, y, z), neck top, head radius, hip height, leg x.
BUILDS = {
    ("rooster", "fat"): {"body": ((0, 0, 0.42), (0.28, 0.3, 0.33)), "neck": None, "head": 0.0, "hip": 0.24, "leg_x": 0.11},
    ("rooster", "thin"): {"body": ((0, -0.04, 0.44), (0.17, 0.21, 0.22)), "neck": (0, 0.1, 0.98), "head": 0.11,
                          "hip": 0.36, "leg_x": 0.07},
    ("turkey", "fat"): {"body": ((0, -0.02, 0.46), (0.3, 0.32, 0.31)), "neck": (0, 0.16, 0.95), "head": 0.095,
                        "hip": 0.3, "leg_x": 0.11},
    ("turkey", "thin"): {"body": ((0, -0.03, 0.5), (0.2, 0.23, 0.24)), "neck": (0, 0.14, 1.12), "head": 0.085,
                         "hip": 0.4, "leg_x": 0.075},
}


class Parts:
    """Vertices, faces, a colour per face and bone weights per vertex, joined into one mesh."""

    def __init__(self) -> None:
        self.verts: list[Vector] = []
        self.faces: list[tuple] = []
        self.colours: list[str] = []
        self.weights: list[dict] = []

    def add(self, verts: list, faces: list, colour: str, bone) -> None:
        base = len(self.verts)
        for v in verts:
            self.verts.append(v)
            self.weights.append(bone(v) if callable(bone) else {bone: 1.0})
        self.faces += [tuple(base + i for i in f) for f in faces]
        self.colours += [colour] * len(faces)

    def ellipsoid(self, centre, radii, colour, bone, rot=None, seg=14, rings=9, egg=0.0) -> None:
        """Ellipsoid; egg > 0 narrows the top like an egg. rot turns it about its centre."""
        rot = rot or Matrix.Identity(3)
        verts = [Vector((0, 0, -1))]
        for r in range(1, rings):
            phi = math.pi * r / rings - math.pi / 2
            for s in range(seg):
                th = 2 * math.pi * s / seg
                verts.append(Vector((math.cos(phi) * math.cos(th), math.cos(phi) * math.sin(th), math.sin(phi))))
        verts.append(Vector((0, 0, 1)))
        out = []
        for v in verts:
            k = 1.0 - egg * v.z
            out.append(Vector(centre) + rot @ Vector((v.x * radii[0] * k, v.y * radii[1] * k, v.z * radii[2])))
        self.add(out, _sphere_faces(seg, rings), colour, bone)

    def sweep(self, path: list, radii: list, colour: str, bone, flat=1.0, thin_axis=(1, 0, 0), sides=10) -> None:
        """Tube along path with rounded ends; its section is squashed by flat along thin_axis."""
        path = [Vector(p) for p in path]
        thin = Vector(thin_axis)
        rings = []
        for i, p in enumerate(path):
            tangent = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
            a = (thin - tangent * thin.dot(tangent)).normalized()
            b = tangent.cross(a)
            rings.append((p, tangent, a, b, radii[i]))
        # Rounded caps: three shrinking rings past each end, then a pole.
        start, end = rings[0], rings[-1]
        cap = lambda ring, sign: [(ring[0] + ring[1] * sign * ring[4] * math.sin(t), ring[1], ring[2], ring[3],
                                   ring[4] * math.cos(t)) for t in (0.5, 0.9, 1.25)]
        rings = cap(start, -1)[::-1] + rings + cap(end, 1)
        verts = [start[0] - start[1] * start[4]]
        for p, _t, a, b, r in rings:
            for s in range(sides):
                th = 2 * math.pi * s / sides
                verts.append(p + a * (math.cos(th) * r * flat) + b * (math.sin(th) * r))
        verts.append(end[0] + end[1] * end[4])
        self.add(verts, _sphere_faces(sides, len(rings) + 1), colour, bone)

    def cone(self, base, tip, radius, colour, bone, squash=0.8, sides=8) -> None:
        base, tip = Vector(base), Vector(tip)
        axis = (tip - base).normalized()
        a = Vector((1, 0, 0))
        b = axis.cross(a).normalized()
        a = b.cross(axis)
        ring = lambda p, r: [p + a * (math.cos(2 * math.pi * s / sides) * r)
                             + b * (math.sin(2 * math.pi * s / sides) * r * squash) for s in range(sides)]
        verts = [base - axis * radius * 0.3] + ring(base, radius) + ring(base + (tip - base) * 0.55, radius * 0.6)
        verts.append(tip)
        self.add(verts, _sphere_faces(sides, 3), colour, bone)


def _sphere_faces(seg: int, rings: int) -> list:
    """Faces of a pole + (rings - 1) rings of seg vertices + pole."""
    faces = [(0, 1 + (s + 1) % seg, 1 + s) for s in range(seg)]
    for r in range(rings - 2):
        a, b = 1 + r * seg, 1 + (r + 1) * seg
        faces += [(a + s, a + (s + 1) % seg, b + (s + 1) % seg, b + s) for s in range(seg)]
    top, last = 1 + (rings - 1) * seg, 1 + (rings - 2) * seg
    faces += [(last + s, last + (s + 1) % seg, top) for s in range(seg)]
    return faces




class Surface:
    """An egg-shaped ellipsoid (as Parts.ellipsoid builds it) to put parts on: point and normal along a direction."""

    def __init__(self, centre, radii, egg=0.0) -> None:
        self.c, self.r, self.egg = Vector(centre), Vector(radii), egg

    def inside(self, p: Vector) -> float:
        q = p - self.c
        k = 1.0 - self.egg * q.z / self.r.z
        return (q.x / (self.r.x * k)) ** 2 + (q.y / (self.r.y * k)) ** 2 + (q.z / self.r.z) ** 2 - 1.0

    def at(self, direction) -> tuple[Vector, Vector]:
        d = Vector(direction).normalized()
        lo, hi = 0.0, 2.0 * max(self.r)
        for _ in range(30):
            mid = (lo + hi) / 2
            lo, hi = (mid, hi) if self.inside(self.c + d * mid) < 0 else (lo, mid)
        p = self.c + d * lo
        e = 1e-4
        n = Vector([self.inside(p + Vector(a) * e) - self.inside(p - Vector(a) * e)
                    for a in ((1, 0, 0), (0, 1, 0), (0, 0, 1))]).normalized()
        return p, n


def _facing(normal: Vector, axis=(0, 1, 0)) -> Matrix:
    """Rotation that turns the local axis to normal (a flat part lying on a surface)."""
    return Vector(axis).rotation_difference(normal).to_matrix()


def build_head(parts: Parts, species: str, head: Surface, s: float) -> Vector:
    """Eyes, cheeks, beak, comb or snood and wattles on the head; s is the feature size. Returns the beak tip."""
    for side in (1, -1):
        p, n = head.at((side * 0.42, 1, 0.42))
        parts.ellipsoid(p + n * 0.01 * s, (0.085 * s,) * 3, "eye", "head", seg=8, rings=6)
        p, n = head.at((side * 0.8, 0.8, 0.02))
        parts.ellipsoid(p + n * 0.01 * s, (0.15 * s, 0.03 * s, 0.11 * s), "cheek", "head", rot=_facing(n), seg=10, rings=6)
    base, n = head.at((0, 1, 0.08))
    tip = base + n * 0.42 * s + Vector((0, 0, -0.05 * s))
    parts.cone(base - n * 0.06 * s, tip, 0.2 * s, "beak", "head")
    if species == "rooster":
        for side in (1, -1):  # two wattle drops under the beak
            p, n = head.at((side * 0.12, 1, -0.2))
            parts.ellipsoid(p + Vector((side * 0.03 * s, 0.06 * s, -0.2 * s)), (0.15 * s, 0.12 * s, 0.27 * s), "comb",
                            "head", rot=Matrix.Rotation(side * 0.2, 3, "Y"), seg=10, rings=7)
        for dy, r in ((0.5, 0.3), (0.05, 0.36), (-0.4, 0.32)):  # comb: three lobes front to back
            p, n = head.at((0, dy, 1))
            parts.ellipsoid(p + n * r * 0.75 * s, (0.13 * s, r * s, r * 1.3 * s), "comb", "head",
                            rot=_facing(n, (0, 0, 1)), seg=12, rings=8)
    else:  # snood from the brow over the beak, a wattle under it
        top, _n = head.at((0.08, 0.8, 0.55))
        path = [top, top + Vector((0.03 * s, 0.25 * s, 0.02 * s)), top + Vector((0.08 * s, 0.4 * s, -0.3 * s)),
                top + Vector((0.12 * s, 0.38 * s, -0.7 * s))]
        parts.sweep(path, [0.07 * s, 0.08 * s, 0.09 * s, 0.11 * s], "comb", "head", sides=8)
        p, _n = head.at((0, 0.7, -0.75))
        parts.ellipsoid(p + Vector((0, 0.02 * s, -0.16 * s)), (0.11 * s, 0.1 * s, 0.24 * s), "comb", "head", seg=10, rings=7)
    return tip


def build_wings(parts: Parts, body: Surface) -> list:
    """A rounded wing lying on each side with three feather lobes at the back; returns the shoulders."""
    shoulders = []
    size = min(body.r.y, body.r.z)
    for side, bone in ((1, "wing_l"), (-1, "wing_r")):
        p, n = body.at((side, -0.12, -0.02))
        lie = _facing(n, (side, 0, 0)) @ Matrix.Rotation(0.35, 3, "X")  # feather tips down and back
        centre = p + n * 0.025
        parts.ellipsoid(centre, (0.045, size * 0.55, size * 0.42), "wing", bone, rot=lie, seg=12, rings=8)
        for i in range(3):
            lobe = centre + lie @ Vector((side * 0.008, -size * (0.4 + 0.1 * i), -size * (0.12 + 0.14 * i)))
            parts.ellipsoid(lobe, (0.04, size * 0.3, size * 0.11), "wing", bone,
                            rot=lie @ Matrix.Rotation(-0.45 - 0.3 * i, 3, "X"), seg=10, rings=6)
        shoulders.append(centre + lie @ Vector((0, size * 0.35, size * 0.25)))
    return shoulders


def build_tail(parts: Parts, species: str, root: Vector, size: float) -> None:
    if species == "rooster":  # sickle feathers: up and back, curling down at the tips
        for i, colour in enumerate(("tail_b", "tail_a", "tail_c", "tail_a")):
            reach = 1.0 - 0.15 * i
            path = []
            for k in range(15):
                a = math.radians(-20 + 200 * k / 14)  # an arc that rolls over backwards
                path.append(root + Vector((0, -size * reach * (0.55 - 0.55 * math.cos(a) + 0.2 * k / 14),
                                           size * reach * 0.75 * math.sin(a) * (1 - 0.1 * i) + size * 0.25 * (k / 14) - 0.12 * size * i)))
            radii = [size * (0.1 + 0.1 * math.sin(math.pi * min(1.0, (k + 2) / 14))) for k in range(15)]
            parts.sweep(path, radii, colour, "tail", flat=0.45, sides=10)
    else:  # fan: banded round feathers spread in a half circle behind the body
        count = 11
        for i in range(count):
            a = math.radians(-84 + 168 * i / (count - 1))
            out = Vector((math.sin(a), -0.3, math.cos(a))).normalized()
            for k, (colour, t0, t1, r) in enumerate((("tail_a", 0.1, 0.52, 0.075), ("tail_b", 0.48, 0.8, 0.09),
                                                     ("tail_c", 0.76, 1.0, 0.1))):
                lift = Vector((0, -0.006 * k, 0))
                p0, p1 = root + out * size * t0 + lift, root + out * size * t1 + lift
                parts.sweep([p0, (p0 + p1) / 2, p1], [size * r * 0.85, size * r, size * r * 0.95], colour, "tail",
                            flat=0.35, thin_axis=(0, 1, 0), sides=8)


def build_legs(parts: Parts, hip: float, leg_x: float, y: float, knee: float, radius: float) -> dict:
    """Yellow legs and three-toed feet; returns bone name -> (head, tail)."""
    bones = {}
    for side, tag in ((1, "l"), (-1, "r")):
        h, k, a = Vector((side * leg_x, y, hip)), Vector((side * leg_x, y + 0.01, knee)), Vector((side * leg_x, y + 0.02, 0.045))
        parts.sweep([h, k], [radius * 1.3, radius], "feet", f"thigh_{tag}", sides=8)
        parts.sweep([k, (k + a) / 2, a], [radius, radius, radius * 1.1], "feet", f"shin_{tag}", sides=8)
        for angle, length in ((-0.5, 0.075), (0.0, 0.09), (0.5, 0.075), (math.pi, 0.045)):
            d = Vector((math.sin(angle) * side, math.cos(angle), 0))
            parts.ellipsoid(a + d * length * 0.6 + Vector((0, 0, -0.018)), (radius * 0.85, length * 0.6, radius * 0.75),
                            "feet", f"shin_{tag}", rot=_facing(d), seg=10, rings=6)
        bones[f"thigh_{tag}"] = (h, k)
        bones[f"shin_{tag}"] = (k, a)
    return bones


def build_bird(species: str, build: str) -> tuple[Parts, dict, dict]:
    """The bird's parts, its bones (name -> head, tail, parent) and numbers the animations fit to."""
    spec = BUILDS[(species, build)]
    centre, radii = spec["body"]
    parts = Parts()
    egg = 0.1 if spec["neck"] is None else 0.05
    body = Surface(centre, radii, egg)
    parts.ellipsoid(centre, radii, "body", "body", seg=24, rings=16, egg=egg)
    c, r = body.c, body.r
    if spec["neck"] is None:  # the face sits on the front of the egg
        head, size = body, 0.27
        neck_base, head_joint = c + Vector((0, r.y * 0.3, r.z * 0.1)), c + Vector((0, r.y * 0.5, r.z * 0.45))
    else:
        head_joint = Vector(spec["neck"])
        hr = spec["head"]
        head, size = Surface(head_joint + Vector((0, 0.15 * hr, 0)), (hr, hr * 1.08, hr * 1.05)), hr * 1.9
        parts.ellipsoid(head.c, head.r, "head", "head", seg=16, rings=10)
        neck_base = c + Vector((0, r.y * 0.45, r.z * 0.45))
        thick = hr * (0.62 if species == "rooster" else 0.5)
        mid = (neck_base + head_joint) / 2 + Vector((0, 0.03, 0))
        span = (head_joint - neck_base).length

        def neck_weights(v: Vector) -> dict:
            t = max(0.0, min(1.0, (v - neck_base).dot(head_joint - neck_base) / span ** 2))
            w_body, w_head = max(0.0, 1 - t / 0.25), max(0.0, (t - 0.8) / 0.2)
            return {"body": w_body, "neck": 1 - w_body - w_head, "head": w_head}

        parts.sweep([neck_base - Vector((0, 0.04, 0.06)), neck_base, mid, head_joint],
                    [thick * 1.5, thick * 1.25, thick * 1.05, thick], "neck", neck_weights, sides=12)
    tip = build_head(parts, species, head, size)
    shoulders = build_wings(parts, body)
    tail_root = c + Vector((0, -r.y * (0.7 if species == "rooster" else 0.8), r.z * 0.3))
    tail_size = (r.z * 1.6 if spec["neck"] is None else r.z * 2.3) if species == "rooster" else r.z * 2.1
    build_tail(parts, species, tail_root, tail_size)
    hip = spec["hip"]
    knee = max(0.1, c.z - r.z * 0.8) if spec["neck"] is None else hip * 0.55
    leg_radius = 0.028 if build == "fat" else 0.02
    legs = build_legs(parts, hip, spec["leg_x"], c.y + 0.02, knee, leg_radius)
    pivot = Vector((0, c.y + 0.02, hip))
    bones = {"body": (pivot, pivot + Vector((0, 0.15, 0)), None),
             "neck": (neck_base, head_joint, "body"),
             "head": (head_joint, head_joint + Vector((0, 0.1, 0)), "neck"),
             "tail": (tail_root, tail_root + Vector((0, -0.1, 0.05)), "body"),
             "wing_l": (shoulders[0], shoulders[0] + Vector((0, -0.12, -0.04)), "body"),
             "wing_r": (shoulders[1], shoulders[1] + Vector((0, -0.12, -0.04)), "body")}
    for name, (a, b) in legs.items():
        bones[name] = (a, b, "body" if name.startswith("thigh") else "thigh" + name[4:])
    fit = {"long_neck": spec["neck"] is not None, "pivot": pivot, "neck": neck_base, "tip": tip, "height": c.z + r.z}
    return parts, bones, fit


def make_mesh(name: str, parts: Parts, palette: dict) -> bpy.types.Object:
    import bmesh
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(v) for v in parts.verts], [], parts.faces)
    names = list(dict.fromkeys(parts.colours))
    for colour in names:
        material = bpy.data.materials.new(colour)
        material.use_nodes = True
        bsdf = material.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*[_linear(x) for x in palette[colour]], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.55  # soft vinyl
        data.materials.append(material)
    for polygon, colour in zip(data.polygons, parts.colours):
        polygon.material_index = names.index(colour)
        polygon.use_smooth = True
    mesh = bmesh.new()
    mesh.from_mesh(data)
    bmesh.ops.recalc_face_normals(mesh, faces=mesh.faces)  # every part is closed: normals face out
    mesh.to_mesh(data)
    mesh.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def _linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def make_rig(name: str, bones: dict, mesh: bpy.types.Object, parts: Parts) -> bpy.types.Object:
    data = bpy.data.armatures.new("skeleton")
    rig = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for bone_name, (head, tail, parent) in bones.items():
        bone = data.edit_bones.new(bone_name)
        bone.head, bone.tail, bone.roll = head, tail, 0.0
        bone.parent = data.edit_bones[parent] if parent else None
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = {b: mesh.vertex_groups.new(name=b) for b in bones}
    for i, weights in enumerate(parts.weights):
        for bone_name, w in weights.items():
            if w > 0.0:
                groups[bone_name].add([i], w, "REPLACE")
    mesh.parent = rig
    mesh.modifiers.new("skin", "ARMATURE").object = rig
    return rig


# --- Animation --------------------------------------------------------------------------------
# Poses as in tools/rig_boars.py: bone -> armature-space rotations, carried by the child bones; +Y is
# forward, X+ lifts the head and swings a foot forward, Y+ rolls onto the right side. "move" shifts
# the body (the root bone, pivoting between the hips). The thighs undo the body's turn so the feet
# stay on the ground.


def _pose(body: list, legs: dict, extra: dict, move=(0, 0, 0)) -> dict:
    undo = [(axis, -deg) for axis, deg in reversed(body)]
    pose = {"body": body, "move": Vector(move), **extra}
    for tag, (swing, lift) in legs.items():
        pose[f"thigh_{tag}"] = [("X", swing + lift * 0.5)] + undo
        pose[f"shin_{tag}"] = [("X", -lift)]
    return pose


def _flap(angle: float) -> dict:
    return {"wing_l": [("Y", -angle)], "wing_r": [("Y", angle)]}


def idle(t: float, fit: dict) -> dict:
    breathe = math.sin(t * 2 * math.pi)
    look = 18 * math.sin(t * 2 * math.pi) * abs(math.sin(t * 2 * math.pi))
    extra = {"tail": [("Z", 6 * math.sin(t * 4 * math.pi))], **_flap(3 + 3 * breathe)}
    body = [("X", 2 * breathe)]
    if fit["long_neck"]:
        extra["head"] = [("Z", look), ("Y", 0.4 * look)]
        extra["neck"] = [("X", 3 * breathe)]
    else:
        body.append(("Z", 0.5 * look))
    return _pose(body, {"l": (0, 0), "r": (0, 0)}, extra, (0, 0, 0.006 * breathe))


def _stride(t: float, fit: dict, swing: float, lift: float, lean: float, bob: float, flap: float) -> dict:
    s = 2 * math.pi * t
    legs = {tag: (swing * math.sin(s + off), lift * max(0.0, math.cos(s + off))) for tag, off in (("l", 0.0), ("r", math.pi))}
    pump = math.sin(2 * s)  # the head bobs twice per stride
    extra = {"tail": [("X", 6 * pump), ("Z", 8 * math.sin(s))], **_flap(flap * (0.6 + 0.4 * math.sin(2 * s)))}
    body = [("X", -lean + (0 if fit["long_neck"] else 3 * pump)), ("Y", 6 * math.sin(s))]
    if fit["long_neck"]:
        extra["neck"] = [("X", -lean * 0.8 + 8 * pump)]
        extra["head"] = [("X", lean * 0.8 - 8 * pump)]
    return _pose(body, legs, extra, (0, 0, bob * abs(math.sin(s))))


def walk(t: float, fit: dict) -> dict:
    return _stride(t, fit, 28, 40, 0, 0.02, 4)


def run(t: float, fit: dict) -> dict:
    return _stride(t, fit, 45, 65, 18, 0.045, 55)


def peck(t: float, fit: dict) -> dict:
    """Bends down until the beak touches the ground, pecks three times, stands up again."""
    keys = [(0.0, 0), (0.2, 1), (0.3, 0.82), (0.4, 1), (0.5, 0.82), (0.6, 1), (0.7, 0.82), (0.8, 1), (1.0, 0)]
    (down,) = _interpolate(keys, t)
    body = [("X", -fit["peck_body"] * down)]
    extra = {"tail": [("X", 12 * down)], **_flap(6 * down)}
    if fit["long_neck"]:
        extra["neck"] = [("X", -fit["peck_neck"] * down)]
    return _pose(body, {"l": (0, 0), "r": (0, 0)}, extra)


def peck_angles(fit: dict) -> None:
    """Neck bend (long necks) and body pitch that bring the beak tip to the ground."""
    def turn(p: Vector, centre: Vector, deg: float) -> Vector:
        a = math.radians(deg)
        q = p - centre
        return centre + Vector((0, q.y * math.cos(a) - q.z * math.sin(a), q.y * math.sin(a) + q.z * math.cos(a)))

    fit["peck_neck"] = 60.0 if fit["long_neck"] else 0.0
    lo, hi = 0.0, 85.0
    for _ in range(30):
        mid = (lo + hi) / 2
        tip = turn(turn(fit["tip"], fit["neck"], -fit["peck_neck"]), fit["pivot"], -mid)
        lo, hi = (mid, hi) if tip.z > 0.04 else (lo, mid)
    fit["peck_body"] = lo


# name: (pose function, frames). All loop.
ANIMATIONS = {"idle": (idle, 60), "walk": (walk, 24), "run": (run, 14), "peck": (peck, 48)}


def animate(rig: bpy.types.Object, name: str, make, frames: int, fit: dict):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    root_rest = rig.data.bones["body"].matrix_local.to_quaternion()
    for frame in range(0, frames + 1, 2):
        pose = make((frame / frames) % 1.0, fit)
        for bone in rig.pose.bones:
            rest = bone.bone.matrix_local.to_quaternion()
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = rest.inverted() @ _quat(pose.get(bone.name, [])) @ rest
            bone.keyframe_insert("rotation_quaternion", frame=frame)
        root = rig.pose.bones["body"]
        root.location = root_rest.inverted() @ pose["move"]
        root.keyframe_insert("location", frame=frame)
    return action


def build(species: str, kind: str, preview_dir: Path | None) -> None:
    from rig_boars import preview
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    name = f"{species}_{kind}"
    parts, bones, fit = build_bird(species, kind)
    mesh = make_mesh(name, parts, {**PALETTES[species], **SHARED})
    rig = make_rig(species, bones, mesh, parts)
    peck_angles(fit)
    actions = [animate(rig, anim, make, frames, fit) for anim, (make, frames) in ANIMATIONS.items()]
    rig.animation_data.action = actions[0]
    print(name, "triangles:", sum(len(p.vertices) - 2 for p in mesh.data.polygons), "peck:", round(fit["peck_body"]))
    if preview_dir:
        preview(rig, actions, preview_dir, name, fit["height"] * 1.6)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB",
                              export_animation_mode="ACTIONS", export_force_sampling=True, export_frame_step=1,
                              use_selection=True)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    preview_dir = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    for species, kind in BUILDS:
        build(species, kind, preview_dir)


if __name__ == "__main__":
    main()
