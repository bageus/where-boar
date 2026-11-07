#!/usr/bin/env python3
"""Paint, rig and animate the owner's rooster and turkey (2026-11-07) into assets/models/<bird>.glb.

The sources in assets/models/birds_source/ are bare faceted meshes (positions only, 50k triangles).
Each is cut to about TRIANGLES, coloured by body part (comb, beak, feathers, tail bands, legs), UV
unwrapped, and baked into a colour map and a feather normal map (TEXTURE_SIZE). A rigid-part
skeleton (body, neck, head, tail, legs, feet, rooster wings) gets idle, walk, run (wings flap) and
peck (beak to the ground). The model faces glTF -Z (Godot's forward), feet at y = 0.

Needs Blender as a Python module (`pip install bpy`). Run after a change:
    python tools/rig_birds.py rooster
    python tools/rig_birds.py turkey
Add `--preview DIR` to also render a contact sheet of every animation into DIR.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "models" / "birds_source"
OUT = ROOT / "assets" / "models"
TRIANGLES = 6000
TEXTURE_SIZE = 512
FPS = 30
## Game size against the source (the old birds were shown at 0.7 too).
SCALE = 0.7


def ramp(value: float, start: float, end: float) -> float:
    """0 at start, 1 at end, smooth between (either direction)."""
    t = min(1.0, max(0.0, (value - start) / (end - start)))
    return t * t * (3 - 2 * t)


# Landmarks and parts in source metres after the turn: +X side, +Y forward (the beak), +Z up.
def rooster_parts(p: Vector) -> dict:
    x, y, z = abs(p.x), p.y, p.z
    return {
        "leg": 1 - ramp(z, 0.15, 0.19),
        "wing": ramp(x, 0.075, 0.095) * ramp(z, 0.14, 0.18) * (1 - ramp(z, 0.40, 0.44)) * ramp(y, -0.06, -0.02),
        "tail": ramp(y, 0.04, -0.04) * ramp(z, 0.20, 0.26),
        "neck": ramp(y, -0.02, 0.04) * ramp(z, 0.38, 0.46),
        "head": ramp(y, -0.08, -0.03) * ramp(z, 0.58, 0.64),  # the comb reaches back over the neck
    }


def rooster_colour(p: Vector, part: str) -> tuple:
    x, y, z = abs(p.x), p.y, p.z
    if part == "leg":
        return (0.92, 0.62, 0.16), 0.0
    if part == "head":
        if z > 0.84:
            return (0.85, 0.08, 0.06), 0.0  # comb
        if y > 0.27 and z > 0.695:
            return (0.96, 0.72, 0.18), 0.0  # beak
        if y > 0.21 and z < 0.70:
            return (0.85, 0.08, 0.06), 0.0  # wattle
        return (0.93, 0.56, 0.14), 1.0
    if part == "neck":
        return (0.93, 0.52, 0.12), 1.0
    if part == "tail":
        return (0.07, 0.26, 0.24), 1.0
    if part == "wing":
        return (0.36, 0.14, 0.05), 1.0
    if y > 0.13 and z < 0.36:
        return (0.07, 0.09, 0.07), 1.0  # dark breast
    return (0.62, 0.20, 0.07), 1.0


def turkey_parts(p: Vector) -> dict:
    x, y, z = abs(p.x), p.y, p.z
    return {
        "leg": 1 - ramp(z, 0.14, 0.18),
        "wing": 0.0,
        "tail": ramp(y, -0.10, -0.16) * ramp(z, 0.14, 0.20),
        "neck": ramp(y, 0.18, 0.26) * ramp(z, 0.42, 0.52),
        "head": ramp(y, 0.22, 0.28) * ramp(z, 0.72, 0.78),
    }


def turkey_colour(p: Vector, part: str) -> tuple:
    x, y, z = abs(p.x), p.y, p.z
    if part == "leg":
        return (0.78, 0.52, 0.46), 0.0
    if part == "head":
        if y > 0.49 and z > 0.855:
            return (0.88, 0.76, 0.52), 0.0  # beak
        if (y > 0.46 and z <= 0.855) or z < 0.80:
            return (0.82, 0.10, 0.10), 0.0  # snood and wattle
        return (0.50, 0.68, 0.88), 0.0  # bare blue head
    if part == "neck":
        return (0.78, 0.30, 0.28), 0.3
    if part == "tail":
        reach = (p - Vector((0.0, -0.18, 0.24))).length
        if reach > 0.52:
            return (0.88, 0.78, 0.56), 1.0  # cream tips
        if reach > 0.44:
            return (0.08, 0.06, 0.05), 1.0  # dark band
        return (0.44, 0.26, 0.12), 1.0
    return (0.34, 0.21, 0.11), 1.0  # bronze body


BIRDS = {
    "rooster": {
        "turn": 90.0,  # the source's beak points +X
        "parts": rooster_parts,
        "colour": rooster_colour,
        "leg_top": 0.12,
        "hip_z": 0.19,
        "toe": 0.08,
        "body": [(0, 0.04, 0.22), (0, 0.17, 0.42)],
        "neck": [(0, 0.17, 0.42), (0, 0.19, 0.66)],
        "head": [(0, 0.19, 0.66), (0, 0.35, 0.72)],
        "tail": [(0, 0.0, 0.34), (0, -0.40, 0.55)],
        "wing": [(0.075, 0.14, 0.38), (0.18, 0.0, 0.24)],
    },
    "turkey": {
        "turn": 180.0,  # the source's beak points -Y
        "parts": turkey_parts,
        "colour": turkey_colour,
        "leg_top": 0.12,
        "hip_z": 0.19,
        "toe": 0.08,
        "body": [(0, -0.05, 0.22), (0, 0.28, 0.48)],
        "neck": [(0, 0.28, 0.48), (0, 0.40, 0.80)],
        "head": [(0, 0.40, 0.80), (0, 0.59, 0.86)],
        "tail": [(0, -0.16, 0.24), (0, -0.24, 0.86)],
        "wing": None,
    },
}
PARTS = ["leg", "wing", "tail", "neck", "head"]  # each takes its share from what came before


def build_mesh(kind: str, spec: dict) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / f"{kind}.glb"))
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    mesh.name = kind
    mesh.data.transform(Matrix.Rotation(math.radians(spec["turn"]), 4, "Z") @ mesh.matrix_world)
    mesh.matrix_world = Matrix()
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.mesh.dissolve_limited(angle_limit=math.radians(1.0))  # faceted: flat runs are one face
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")
    if len(mesh.data.polygons) > TRIANGLES:
        modifier = mesh.modifiers.new("cut", "DECIMATE")
        modifier.ratio = TRIANGLES / len(mesh.data.polygons)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.shade_flat()
    return mesh


def part_of(spec: dict, point: Vector) -> dict:
    """Bone weights at a point: body first, each part then takes its share."""
    shares = spec["parts"](point)
    weights = {"body": 1.0}
    for part in PARTS:
        t = shares[part]
        if t <= 0.0:
            continue
        weights = {k: w * (1 - t) for k, w in weights.items()}
        side = "_l" if point.x > 0 else "_r"
        name = part + side if part in ("leg", "wing") else part
        weights[name] = weights.get(name, 0.0) + t
    if "leg_l" in weights or "leg_r" in weights:
        side = "_l" if point.x > 0 else "_r"
        foot = 1 - ramp(point.z, 0.03, 0.05)
        if foot > 0:
            weights = {k: w * (1 - foot) for k, w in weights.items()}
            weights["foot" + side] = foot
    return {k: w for k, w in weights.items() if w > 0.001}


def paint(mesh: bpy.types.Object, spec: dict) -> None:
    """Face colours by body part (and a feather mask in alpha) into corner colours."""
    data = mesh.data
    colours = data.color_attributes.new("paint", "FLOAT_COLOR", "CORNER")
    for poly in data.polygons:
        weights = part_of(spec, poly.center)
        main = max(weights, key=weights.get).split("_")[0]
        rgb, feather = spec["colour"](poly.center, main if main != "foot" else "leg")
        linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]  # colours above are sRGB
        for loop in poly.loop_indices:
            colours.data[loop].color = (*linear, feather)


def unwrap(mesh: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(mesh: bpy.types.Object, kind: str) -> bpy.types.Material:
    """Colour map (paint plus light mottling) and tangent normal map (feather scales where alpha is 1)."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 4
    scene.render.bake.margin = 6
    material = bpy.data.materials.new(f"{kind}_feathers")
    mesh.data.materials.clear()
    mesh.data.materials.append(material)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    paint_node = nodes.new("ShaderNodeVertexColor")
    paint_node.layer_name = "paint"
    coords = nodes.new("ShaderNodeTexCoord")
    mottle = nodes.new("ShaderNodeTexNoise")
    mottle.inputs["Scale"].default_value = 18.0
    links.new(coords.outputs["Object"], mottle.inputs["Vector"])
    shade = nodes.new("ShaderNodeMapRange")
    shade.inputs["To Min"].default_value = 0.82
    shade.inputs["To Max"].default_value = 1.12
    links.new(mottle.outputs["Fac"], shade.inputs["Value"])
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    links.new(paint_node.outputs["Color"], tint.inputs["A"])
    links.new(shade.outputs["Result"], tint.inputs["B"])
    # Feather scales: cells of a stretched voronoi, raised in their middle.
    scales = nodes.new("ShaderNodeTexVoronoi")
    scales.feature = "DISTANCE_TO_EDGE"
    scales.inputs["Scale"].default_value = 70.0
    links.new(coords.outputs["Object"], scales.inputs["Vector"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Distance"].default_value = 0.004
    links.new(scales.outputs["Distance"], bump.inputs["Height"])
    links.new(paint_node.outputs["Alpha"], bump.inputs["Strength"])
    surface = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bump.outputs["Normal"], surface.inputs["Normal"])
    emit = nodes.new("ShaderNodeEmission")
    links.new(tint.outputs["Result"], emit.inputs["Color"])
    images = {}
    for name, colour_space in (("albedo", "sRGB"), ("normal", "Non-Color")):
        image = bpy.data.images.new(f"{kind}_{name}", TEXTURE_SIZE, TEXTURE_SIZE)
        image.colorspace_settings.name = colour_space
        images[name] = image
    target = nodes.new("ShaderNodeTexImage")
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    for name, kind_of_bake, shader in (("albedo", "EMIT", emit), ("normal", "NORMAL", surface)):
        links.new(shader.outputs[0], out.inputs["Surface"])
        target.image = images[name]
        nodes.active = target
        bpy.ops.object.bake(type=kind_of_bake, margin=6)
        images[name].pack()
    # The material that ships: baked maps only.
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    surface = nodes.new("ShaderNodeBsdfPrincipled")
    surface.inputs["Roughness"].default_value = 0.85
    links.new(surface.outputs[0], out.inputs["Surface"])
    colour = nodes.new("ShaderNodeTexImage")
    colour.image = images["albedo"]
    links.new(colour.outputs["Color"], surface.inputs["Base Color"])
    normal_tex = nodes.new("ShaderNodeTexImage")
    normal_tex.image = images["normal"]
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], surface.inputs["Normal"])
    mesh.data.color_attributes.remove(mesh.data.color_attributes["paint"])
    return material


def build_skeleton(mesh: bpy.types.Object, spec: dict, kind: str) -> bpy.types.Object:
    data = bpy.data.armatures.new(f"{kind}_skeleton")
    rig = bpy.data.objects.new(f"{kind}_rig", data)
    bpy.context.scene.collection.objects.link(rig)
    feet = {s: [v.co for v in mesh.data.vertices if v.co.z < spec["leg_top"] and (v.co.x > 0) == (s > 0)] for s in (1, -1)}
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = data.edit_bones

    def bone(name: str, head, tail, parent=None) -> bpy.types.EditBone:
        b = bones.new(name)
        b.head, b.tail = Vector(head), Vector(tail)
        b.parent = parent
        b.roll = 0.0
        return b

    body = bone("body", *spec["body"])
    neck = bone("neck", *spec["neck"], body)
    bone("head", *spec["head"], neck)
    bone("tail", *spec["tail"], body)
    for side, sign in (("_l", 1), ("_r", -1)):
        points = feet[sign]
        centre = sum(points, Vector()) / len(points)
        hip = (centre.x, centre.y, spec["hip_z"])
        ankle = (centre.x, centre.y, 0.035)
        leg = bone("leg" + side, hip, ankle, body)
        bone("foot" + side, ankle, (centre.x, centre.y + spec["toe"], 0.01), leg)
        if spec["wing"]:
            (x0, y0, z0), (x1, y1, z1) = spec["wing"]
            bone("wing" + side, (x0 * sign, y0, z0), (x1 * sign, y1, z1), body)
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in mesh.data.vertices:
        for name, weight in part_of(spec, v.co).items():
            group = mesh.vertex_groups.get(name) or mesh.vertex_groups.new(name=name)
            group.add([v.index], weight, "REPLACE")
    modifier = mesh.modifiers.new("skin", "ARMATURE")
    modifier.object = rig
    mesh.parent = rig
    return rig


# Poses: bone -> [(axis, degrees)] about armature axes (X side: + swings forward/up, Y forward,
# Z up); "_l" wings mirror to "_r"; "drop" lowers the body, metres.
def _quat(rots: list) -> Quaternion:
    q = Quaternion()
    for axis, degrees in rots:
        q = Quaternion(Vector({"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[axis]), math.radians(degrees)) @ q
    return q


def gait(length: int, swing: float, lean: float, nod: float, flap: float, bob: float) -> list:
    keys = []
    for frame in range(0, length + 1, max(1, length // 8)):
        phase = 2 * math.pi * frame / length
        s = math.sin(phase)
        lift_l, lift_r = max(0.0, math.cos(phase)), max(0.0, -math.cos(phase))
        keys.append((frame, {
            "body": [("X", -lean), ("Y", 4 * s)],
            "leg_l": [("X", lean + swing * s)],
            "leg_r": [("X", lean - swing * s)],
            "foot_l": [("X", -40 * lift_l * (s > 0))],
            "foot_r": [("X", -40 * lift_r * (s < 0))],
            "neck": [("X", lean * 0.6 + nod * math.cos(2 * phase))],
            "head": [("X", -nod * math.cos(2 * phase))],
            "tail": [("X", 4 * math.cos(2 * phase))],
            "wing_l": [("Y", -flap * (0.5 + 0.5 * math.sin(2 * phase)))],
            "drop": bob * (1 - math.cos(2 * phase)) / 2,
        }))
    return keys


ANIMATIONS = {
    "idle": lambda: [(0, {}), (15, {"head": [("Z", 25)]}), (30, {"head": [("Z", 25)], "tail": [("X", 3)]}),
                     (40, {"head": [("Z", -20)], "drop": 0.004}), (52, {"head": [("Z", -20)]}), (60, {})],
    "walk": lambda: gait(30, 28, 4, 8, 0, 0.012),
    "run": lambda: gait(16, 42, 16, 5, 55, 0.02),
    "peck": lambda: [(0, {}), (7, PECK), (11, {}), (18, {}), (25, PECK), (29, {}), (36, {})],
}
PECK = {"body": [("X", -28)], "neck": [("X", -55)], "head": [("X", -20)], "leg_l": [("X", 28)], "leg_r": [("X", 28)],
        "tail": [("X", 10)], "drop": 0.02}


def animate(rig: bpy.types.Object, name: str, keys: list) -> bpy.types.Action:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action["keys"] = [frame for frame, _ in keys]
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame, pose in keys:
        for bone in rig.pose.bones:
            rots = pose.get(bone.name, [])
            if bone.name == "wing_r":
                rots = [(axis, -deg) for axis, deg in pose.get("wing_l", [])]
            rest = bone.bone.matrix_local.to_quaternion()
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = rest.inverted() @ _quat(rots) @ rest
            bone.keyframe_insert("rotation_quaternion", frame=frame)
        body = rig.pose.bones["body"]
        body.location = rig.data.bones["body"].matrix_local.to_quaternion().inverted() @ Vector((0, 0, -pose.get("drop", 0.0)))
        body.keyframe_insert("location", frame=frame)
    return action


def preview(rig: bpy.types.Object, actions: list, out_dir: Path, kind: str) -> None:
    scene = bpy.context.scene
    scene.cycles.samples = 8
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 2.0
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.7, 0.2, 0.6)
    scene.collection.objects.link(sun)
    scene.render.resolution_x = scene.render.resolution_y = 300
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.0
    views = [((3.0, 0.1, 0.35), (90, 0, 90)), ((2.2, 2.2, 1.3), (70, 0, 135))]
    for action in actions:
        rig.animation_data.action = action
        for i, frame in enumerate(list(action["keys"])[::2]):
            scene.frame_set(frame)
            for v, (location, rotation) in enumerate(views):
                camera.location = location
                camera.rotation_euler = [math.radians(a) for a in rotation]
                scene.render.filepath = str(out_dir / f"{kind}_{action.name}_{i:02d}_{v}.png")
                bpy.ops.render.render(write_still=True)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    kind = args[0]
    preview_dir = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    spec = BIRDS[kind]
    mesh = build_mesh(kind, spec)
    paint(mesh, spec)
    unwrap(mesh)
    bake(mesh, kind)
    rig = build_skeleton(mesh, spec, kind)
    actions = [animate(rig, name, make()) for name, make in ANIMATIONS.items()]
    rig.animation_data.action = actions[0]
    rig.scale = (SCALE, SCALE, SCALE)
    print(kind, "triangles:", len(mesh.data.polygons))
    if preview_dir:
        preview(rig, actions, preview_dir, kind)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{kind}.glb"), export_format="GLB",
                              export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_frame_step=1, use_selection=True)


if __name__ == "__main__":
    main()
