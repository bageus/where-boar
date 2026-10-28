#!/usr/bin/env python3
"""Rig, skin and animate the owner's boar models into assets/models/boar_<type id>.glb.

Needs Blender as a Python module (`pip install bpy`). The sources are Meshy exports (20k-170k
triangles, flat shaded, snout towards -Y); each is turned to face the game's forward, scaled to
its length, cut to TRIANGLES, given a quadruped skeleton whose joints are found from the mesh
itself (feet, belly, back line, snout, tail), skinned with Blender's automatic weights and given
the animations in ANIMATIONS. Run after a change, naming the source by the file stem in TYPES:
    python tools/rig_boars.py common_brown path/to/boar_buddy.glb
Add `--preview DIR` to also render a contact sheet of every animation into DIR.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
TEXTURE_SIZE = 512
FPS = 30

# Boar type id -> owner's model, nose-to-tail length in metres, spine bones, triangles.
TYPES = {
    "common_brown": ("boar_buddy", 1.9, 3, 3000),
    "runner_grey": ("neon_boar", 1.8, 3, 3000),
    "aggressive_red": ("tusker_totem", 2.0, 3, 3000),
    "armored_black": ("blocky_boar", 2.0, 3, 3000),
    "golden_tusk": ("golden_piggy_bank", 1.9, 3, 3000),
    "bone": ("bone_boar", 1.9, 3, 4000),
    "bun": ("cinnamon_tuskboar", 1.8, 3, 3000),
    "bubble": ("bubble_boar", 1.6, 3, 3000),
    "mohawk": ("spiky_boar_monster", 2.0, 3, 3000),
    "dachshund": ("boaripede", 2.8, 6, 3000),
    "camo": ("camouflage_boar_scout", 1.9, 3, 3000),
    "hairy": ("cozy_boar_cloak", 2.0, 3, 3000),
    "tiny": ("tiny_tusker", 1.0, 3, 3000),
}
LEGS = {"fl": (1, 1), "fr": (-1, 1), "hl": (1, -1), "hr": (-1, -1)}  # name: (side +X left, +1 front)
AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def build_mesh(source: str, length: float, triangles: int) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=source)
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world = Matrix.Identity(4)
    ys = [v.co.y for v in mesh.data.vertices]
    scale = length / (max(ys) - min(ys))
    low_z = min(v.co.z for v in mesh.data.vertices)
    # Snout to +Y (exported as the game's -Z forward), metres, feet on the ground.
    mesh.data.transform(Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Scale(scale, 4) @ Matrix.Translation((0, 0, -low_z)))
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)  # Meshy splits vertices at UV seams
    bpy.ops.object.mode_set(mode="OBJECT")
    # The models are flat-shaded low poly: collapsing to a few thousand triangles keeps the
    # silhouette (compared on renders), and flat shading keeps the facets.
    modifier = mesh.modifiers.new("cut", "DECIMATE")
    modifier.ratio = min(1.0, triangles / len(mesh.data.polygons))
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.shade_flat()
    for image in bpy.data.images:
        if image.size[0] > TEXTURE_SIZE:
            image.scale(TEXTURE_SIZE, TEXTURE_SIZE)
    return mesh


def landmarks(mesh: bpy.types.Object, spine_count: int) -> dict:
    """Joint positions read off the mesh: feet are the lowest vertices on each side and end."""
    vs = [v.co.copy() for v in mesh.data.vertices]
    height = max(v.z for v in vs)
    tail_y, snout_y = min(v.y for v in vs), max(v.y for v in vs)
    mid_y = (tail_y + snout_y) / 2
    low = [v for v in vs if v.z < 0.05 * height]
    feet = {}
    for name, (side, end) in LEGS.items():
        group = [v for v in low if v.x * side > 0 and (v.y - mid_y) * end > 0]
        feet[name] = sum(group, Vector()) / len(group)
    front_y = (feet["fl"].y + feet["fr"].y) / 2
    back_y = (feet["hl"].y + feet["hr"].y) / 2

    def slice_z(y: float, reach: float) -> tuple[float, float]:
        for width in (0.15, 0.3, 1.0):  # widen where the centre line has a gap (snout holes)
            zs = [v.z for v in vs if abs(v.y - y) < reach and abs(v.x) < width]
            if zs:
                return min(zs), max(zs)
        return belly_guess, height

    belly_guess = 0.4 * height
    reach = length_step = (front_y - back_y) / 8
    belly = max(slice_z(back_y + (front_y - back_y) * t, reach)[0] for t in (0.4, 0.5, 0.6))
    belly = min(max(belly, 0.25 * height), 0.6 * height)  # skirts of hair reach the ground
    centre = lambda y: max((slice_z(y, length_step)[1] + belly) / 2, belly + 0.05)
    spine = [Vector((0, y, centre(y))) for y in
             [back_y + (front_y - back_y) * i / spine_count for i in range(spine_count + 1)]]
    neck_end = Vector((0, front_y + (snout_y - front_y) * 0.45, centre(front_y) + 0.05 * height))
    snout_z = sum(slice_z(snout_y - 0.05, 0.05)) / 2
    return {"feet": feet, "belly": belly, "spine": spine, "neck": neck_end,
            "snout": Vector((0, snout_y, snout_z)), "tail": Vector((0, tail_y, centre(back_y)))}


def build_skeleton(marks: dict) -> bpy.types.Object:
    data = bpy.data.armatures.new("skeleton")
    rig = bpy.data.objects.new("boar", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name: str, head: Vector, tail: Vector, parent=None):
        b = data.edit_bones.new(name)
        b.head, b.tail, b.parent = head, tail, parent
        b.use_connect = parent is not None and (parent.tail - head).length < 1e-4
        b.roll = 0.0
        return b

    spine = marks["spine"]
    parent = None
    names = ["hips"] + [f"spine_{i}" for i in range(1, len(spine) - 2)] + ["chest"]
    for name, head, tail in zip(names, spine, spine[1:]):
        parent = bone(name, head, tail, parent)
    neck = bone("neck", spine[-1], marks["neck"], parent)
    bone("head", marks["neck"], marks["snout"], neck)
    bone("tail", spine[0], marks["tail"], data.edit_bones["hips"])
    belly = marks["belly"]
    for name, (side, end) in LEGS.items():
        foot = marks["feet"][name]
        top = Vector((foot.x * 0.8, foot.y, (belly + spine[0].z) / 2))
        knee = Vector((foot.x, foot.y, belly * 0.45))
        upper = bone(f"leg_{name}", top, knee, data.edit_bones["chest" if end > 0 else "hips"])
        bone(f"shin_{name}", knee, Vector((foot.x, foot.y, 0.0)), upper)
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # Bone heat leaves loose bits (bones, spikes, tusks) unweighted when it fails: nearest bone.
    bones = rig.data.bones
    for vertex in mesh.data.vertices:
        if any(g.weight > 0.01 for g in vertex.groups):
            continue
        nearest = min(bones, key=lambda b: _segment_distance(vertex.co, b.head_local, b.tail_local))
        mesh.vertex_groups[nearest.name].add([vertex.index], 1.0, "REPLACE")


def _segment_distance(point: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    t = max(0.0, min(1.0, (point - a).dot(ab) / ab.length_squared))
    return (point - (a + ab * t)).length


# --- Animation --------------------------------------------------------------------------------
# A pose maps bone -> rotations [(axis, degrees), ...] in armature space (applied in order and
# carried by the child bones); rest is the model as authored. +Y is forward, so X+ swings a leg's
# foot forward and lifts the head, Y+ rolls the body onto its right side. "move" shifts the hips
# (metres, armature space). Each animation is a function of the cycle phase t in [0, 1).


def leg_pose(name: str, phase: float, swing: float, lift: float) -> dict:
    """One leg's stride: swings forward while up (first half), back along the ground (second)."""
    s = math.sin(phase * 2 * math.pi)
    up = max(0.0, math.cos(phase * 2 * math.pi))  # the foot is off the ground in the forward swing
    return {f"leg_{name}": [("X", swing * s + lift * 0.4 * up)], f"shin_{name}": [("X", -lift * up)]}


def gait(t: float, phases: dict, swing: float, lift: float, bob: float, flex: float, spine: list) -> dict:
    pose: dict = {}
    for name, offset in phases.items():
        pose.update(leg_pose(name, t + offset, swing, lift))
    bend = math.sin(t * 2 * math.pi) * 3 / len(spine)  # the same total arch for long backs
    for name in spine:
        pose[name] = [("X", flex * bend)]
    pose["neck"] = [("X", -flex * 1.5 * bend)]
    pose["tail"] = [("Z", 20 * math.sin(t * 4 * math.pi))]
    pose["move"] = Vector((0, 0, bob * abs(math.cos(t * 2 * math.pi))))
    return pose


def idle(t: float, spine: list) -> dict:
    breathe = math.sin(t * 2 * math.pi)
    sniff = max(0.0, math.sin(t * 2 * math.pi)) ** 2
    return {"neck": [("X", -12 * sniff)], "head": [("X", -8 * sniff + 3 * breathe)],
            "tail": [("Z", 25 * math.sin(t * 6 * math.pi))], "move": Vector((0, 0, 0.008 * breathe))}


def walk(t: float, spine: list) -> dict:
    return gait(t, {"fl": 0.0, "hr": 0.0, "fr": 0.5, "hl": 0.5}, 18, 30, 0.02, 2, spine)


def run(t: float, spine: list) -> dict:
    # Gallop: the front legs land together, then the hind legs; the back flexes with the stride.
    pose = gait(t, {"fl": 0.0, "fr": 0.08, "hl": 0.5, "hr": 0.58}, 34, 55, 0.08, 7, spine)
    pose["neck"] = [("X", -8 + 6 * math.sin(t * 2 * math.pi))]
    return pose


def attack(t: float, spine: list) -> dict:
    """Head low and back, a lunge with an upward tusk rip, then back to standing."""
    keys = [(0.0, 0, 0, 0), (0.3, -28, -0.12, -8), (0.45, 30, 0.3, 6), (0.6, 18, 0.25, 4), (1.0, 0, 0, 0)]
    head, push, crouch = _interpolate(keys, t)
    return {"neck": [("X", head)], "head": [("X", head * 0.5)], "move": Vector((0, push, 0)),
            "leg_hl": [("X", crouch)], "leg_hr": [("X", crouch)], "leg_fl": [("X", -crouch)],
            "leg_fr": [("X", -crouch)], "tail": [("X", 30 * min(1.0, t * 3))]}


def death(t: float, spine: list, roll_drop: float) -> dict:
    """Legs buckle, the boar rolls onto its right side and the legs stiffen; the last frame holds."""
    keys = [(0.0, 0, 0, 0), (0.3, 0, -0.15, 1), (0.6, 90, -roll_drop, 1), (0.75, 85, -roll_drop, 0.4), (1.0, 90, -roll_drop, 0)]
    roll, drop, buckle = _interpolate(keys, t)
    stiff = min(1.0, max(0.0, (t - 0.6) / 0.4))
    pose = {"hips": [("Y", roll)], "move": Vector((0, 0, drop)), "neck": [("X", -25 * buckle - 10 * stiff)],
            "tail": [("Z", -30 * stiff)]}
    for name, (_side, end) in LEGS.items():
        pose[f"leg_{name}"] = [("X", (-35 * buckle) * end + 25 * stiff * end)]
        pose[f"shin_{name}"] = [("X", 60 * buckle * -end)]
    return pose


def _interpolate(keys: list, t: float) -> tuple:
    for (t0, *a), (t1, *b) in zip(keys, keys[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            k = k * k * (3 - 2 * k)
            return tuple(x + (y - x) * k for x, y in zip(a, b))
    return tuple(keys[-1][1:])


# name: (pose function, frames, loops). The game loops idle, walk and run.
ANIMATIONS = {"idle": (idle, 60, True), "walk": (walk, 30, True), "run": (run, 18, True),
              "attack": (attack, 24, False), "death": (death, 36, False)}


def _quat(rots: list) -> Quaternion:
    q = Quaternion()
    for axis, degrees in rots:
        q = Quaternion(AXES[axis], math.radians(degrees)) @ q
    return q


def animate(rig: bpy.types.Object, name: str, make, frames: int, loops: bool, spine: list, roll_drop: float):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    hips_rest = rig.data.bones["hips"].matrix_local.to_quaternion()
    for frame in range(0, frames + 1, 2):
        t = frame / frames
        pose = make(t, spine, roll_drop) if make is death else make(t % 1.0 if loops else t, spine)
        for bone in rig.pose.bones:
            rest = bone.bone.matrix_local.to_quaternion()
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = rest.inverted() @ _quat(pose.get(bone.name, [])) @ rest
            bone.keyframe_insert("rotation_quaternion", frame=frame)
        hips = rig.pose.bones["hips"]
        hips.location = hips_rest.inverted() @ pose.get("move", Vector())
        hips.keyframe_insert("location", frame=frame)
    return action


def preview(rig: bpy.types.Object, actions: list, out_dir: Path, kind: str, length: float) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"  # Workbench needs EGL, which headless machines often lack
    scene.cycles.samples = 8
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3
    sun.rotation_euler = (math.radians(40), 0, math.radians(30))
    scene.collection.objects.link(sun)
    scene.render.resolution_x = scene.render.resolution_y = 200
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = length * 1.25
    camera.location = (length * 2, length * 0.6, length * 0.45)
    camera.rotation_euler = (math.radians(82), 0, math.radians(105))
    for action in actions:
        rig.animation_data.action = action
        end = int(action.frame_range[1])
        for i in range(4):
            scene.frame_set(round(end * i / 3) if action.name in ("attack", "death") else round(end * i / 4))
            scene.render.filepath = str(out_dir / f"{kind}_{action.name}_{i}.png")
            bpy.ops.render.render(write_still=True)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    kind, source = args[0], args[1]
    preview_dir = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    _model, length, spine_count, triangles = TYPES[kind]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    mesh = build_mesh(source, length, triangles)
    marks = landmarks(mesh, spine_count)
    rig = build_skeleton(marks)
    skin(mesh, rig)
    half_width = max(abs(v.co.x) for v in mesh.data.vertices if v.co.z > marks["belly"])
    roll_drop = max(0.0, marks["spine"][0].z - half_width * 0.8)
    spine = [b.name for b in rig.data.bones if b.name.startswith("spine_") or b.name == "chest"]
    actions = [animate(rig, name, make, frames, loops, spine, roll_drop)
               for name, (make, frames, loops) in ANIMATIONS.items()]
    rig.animation_data.action = actions[0]
    print(kind, "triangles:", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
    if preview_dir:
        preview(rig, actions, preview_dir, kind, length)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"boar_{kind}.glb"), export_format="GLB",
                              export_animation_mode="ACTIONS", export_image_format="JPEG",
                              export_force_sampling=True, export_frame_step=1, use_selection=True)


if __name__ == "__main__":
    main()
