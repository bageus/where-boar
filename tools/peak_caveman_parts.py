"""Low-poly building blocks for tools/build_peak_cavemen.py (Blender as a Python module).

Blender axes as in rig_cavemen.py: +X is the character's left hand, -Y the front, +Z up; metres.
Every function returns a new mesh object linked to the scene, with one material (or several, by
face) and an optional `bind` bone: parts with a bind follow that bone only (hair, beard, belt);
parts without one are skinned by bone heat (skin, clothes that bend with the limbs).
"""

from __future__ import annotations

import math

import bmesh
import bpy
from mathutils import Matrix, Vector

MATERIALS: dict[str, bpy.types.Material] = {}


def srgb(hex_color: str) -> tuple:
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return (*lin, 1.0)


def material(name: str, hex_color: str) -> bpy.types.Material:
    if name not in MATERIALS:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = srgb(hex_color)
        bsdf.inputs["Roughness"].default_value = 0.9
        mat.diffuse_color = srgb(hex_color)
        MATERIALS[name] = mat
    return MATERIALS[name]


def finish(bm: bmesh.types.BMesh, name: str, materials: list, bind: str | None = None) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for mat in materials:
        obj.data.materials.append(mat)
    if bind:
        group = obj.vertex_groups.new(name=f"bind:{bind}")
        group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    return obj


def _frame(direction: Vector, up: Vector) -> tuple[Vector, Vector]:
    side = up.cross(direction)
    if side.length < 1e-6:
        side = Vector((0, 1, 0)).cross(direction)
    side.normalize()
    return side, direction.cross(side).normalized()


def loft(name: str, mat, points: list, radii: list, sides: int = 8, up=(0, -1, 0), closed: bool = False,
         caps: bool = True, bind: str | None = None, turn: float = 0.0) -> bpy.types.Object:
    """A faceted tube through `points`; radii are r or (r_side, r_normal) per point."""
    bm = bmesh.new()
    pts = [Vector(p) for p in points]
    up = Vector(up)
    rings = []
    count = len(pts)
    for i, p in enumerate(pts):
        if closed:
            d = pts[(i + 1) % count] - pts[i - 1]
        else:
            d = pts[min(i + 1, count - 1)] - pts[max(i - 1, 0)]
        side, normal = _frame(d.normalized(), up)
        r = radii[i]
        ra, rb = (r, r) if isinstance(r, (int, float)) else r
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides + turn + math.pi / sides
            ring.append(bm.verts.new(p + side * (math.cos(a) * ra) + normal * (math.sin(a) * rb)))
        rings.append(ring)
    links = range(count if closed else count - 1)
    for i in links:
        a, b = rings[i], rings[(i + 1) % count]
        for k in range(sides):
            bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if caps and not closed:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    return finish(bm, name, [mat], bind)


def ball(name: str, mat, centre, radii, segments: int = 10, rings: int = 7, bind: str | None = None) -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=1.0)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centre) @ Matrix.Diagonal((*radii, 1)), verts=bm.verts)
    return finish(bm, name, [mat], bind)


def block(name: str, mat, centre, size, bevel: float = 0.0, bind: str | None = None, tilt=(0, 0, 0)) -> bpy.types.Object:
    """A box, its edges cut by `bevel` metres; tilt is an XYZ rotation in degrees about its centre."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES", profile=0.5)
    rot = Matrix.Rotation(math.radians(tilt[2]), 4, "Z") @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y") \
        @ Matrix.Rotation(math.radians(tilt[0]), 4, "X")
    bmesh.ops.transform(bm, matrix=Matrix.Translation(centre) @ rot, verts=bm.verts)
    return finish(bm, name, [mat], bind)


def spike(name: str, mat, base, tip, width: float, sides: int = 4, bind: str | None = None, depth: float | None = None):
    """A pyramid from a base centred at `base` to a point at `tip` (hair locks, ears of the hat)."""
    bm = bmesh.new()
    base, tip = Vector(base), Vector(tip)
    side, normal = _frame((tip - base).normalized(), Vector((0, -1, 0)))
    depth = width if depth is None else depth
    ring = [bm.verts.new(base + side * math.cos(2 * math.pi * k / sides + math.pi / sides) * width
                         + normal * math.sin(2 * math.pi * k / sides + math.pi / sides) * depth) for k in range(sides)]
    apex = bm.verts.new(tip)
    for k in range(sides):
        bm.faces.new((ring[k], ring[(k + 1) % sides], apex))
    bm.faces.new(list(reversed(ring)))
    return finish(bm, name, [mat], bind)


def slab(name: str, mat, outline: list, y_front: float, depth: float, z0: float = 0.0, bind: str | None = None,
         bulge: float = 0.0) -> bpy.types.Object:
    """A flat shape cut from the front view: outline (x, z) points, pushed back `depth` from y_front.
    bulge > 0 bows its front out in the middle (beards)."""
    bm = bmesh.new()
    width = max(abs(x) for x, _ in outline) or 1.0
    front = [bm.verts.new((x, y_front - bulge * (1 - (x / width) ** 2), z + z0)) for x, z in outline]
    back = [bm.verts.new((x, y_front + depth, z + z0)) for x, z in outline]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(outline)
    for k in range(n):
        bm.faces.new((front[(k + 1) % n], front[k], back[k], back[(k + 1) % n]))
    return finish(bm, name, [mat], bind)


def skirt(name: str, mats: list, z_top: float, top: tuple, z_bottom: float, bottom: tuple, teeth: int, tooth: float,
          y: float = 0.0, thickness: float = 0.025, pattern=None, rings: int = 2) -> bpy.types.Object:
    """An open hide skirt or tunic from an ellipse at z_top to a zigzag hem; `pattern(ring, k)` picks a
    material index per face for patchwork."""
    bm = bmesh.new()
    sides = teeth * 2
    levels = []
    for r in range(rings + 1):
        t = r / rings
        rx, ry = top[0] + (bottom[0] - top[0]) * t, top[1] + (bottom[1] - top[1]) * t
        z = z_top + (z_bottom - z_top) * t
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            dz = tooth * (k % 2) * (1 if r == rings else 0.0)
            ring.append(bm.verts.new((math.cos(a) * rx, y + math.sin(a) * ry, z + dz)))
        levels.append(ring)
    for r in range(rings):
        a, b = levels[r], levels[r + 1]
        for k in range(sides):
            face = bm.faces.new((a[k], b[k], b[(k + 1) % sides], a[(k + 1) % sides]))
            face.material_index = pattern(r, k) if pattern else 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for face in bm.faces:  # outward from the body axis
        centre = face.calc_center_median()
        if face.normal.dot(Vector((centre.x, centre.y - y, 0))) < 0:
            face.normal_flip()
    obj = finish(bm, name, mats, bind="skirt")
    solid = obj.modifiers.new("solid", "SOLIDIFY")
    solid.thickness = thickness
    solid.offset = 1.0
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=solid.name)
    return obj


def band(name: str, mat, centre, radii, tilt_deg: float, width: float, thickness: float, segments: int = 16,
         bind: str | None = None, axis: str = "Y") -> bpy.types.Object:
    """A strap or belt: a flat ring around the body, tilted about `axis` (a sash over one shoulder)."""
    rot = Matrix.Rotation(math.radians(tilt_deg), 3, axis)
    c = Vector(centre)
    pts = [c + rot @ Vector((math.cos(2 * math.pi * k / segments) * radii[0], math.sin(2 * math.pi * k / segments) * radii[1], 0))
           for k in range(segments)]
    half = math.sqrt(2) / 2  # a square cross-section's corners sit at 45 degrees
    return loft(name, mat, pts, [(thickness / 2 / half, width / 2 / half)] * segments, sides=4,
                up=rot @ Vector((0, 0, 1)), closed=True, bind=bind)
