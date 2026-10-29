#!/usr/bin/env python3
"""Rig, skin and animate the owner's caveman models into assets/models/caveman_<kind>.glb.

The "hunter" kind is the player's body (shadow only) and also writes hunter_arm.glb, its right
forearm and fist for the first-person view. The "helper" kind is the tavern's tribesman
(tribal_character_04_12000.glb): his own animations (walk, run, sneak, crouch, hammer, sit) and the
owner's stone hammer in his right fist.

Needs Blender as a Python module (`pip install bpy`). The source models are the owner's Meshy
exports in assets/models/ (T-pose, 12k triangles, three 1024 maps); they are cut to TRIANGLES, given one 25-bone skeleton
(joints placed from the landmarks below), skinned with Blender's automatic weights, and get
the animations in ANIMATIONS. Run after a change:
    python tools/rig_cavemen.py hunter assets/models/tribal_hunter_12000.glb
    python tools/rig_cavemen.py skinny assets/models/tribal_character_02_12000.glb
    python tools/rig_cavemen.py heavy assets/models/tribal_character_05_12000.glb
    python tools/rig_cavemen.py helper assets/models/tribal_character_04_12000.glb
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
TRIANGLES = 5000
TEXTURE_SIZE = 1024
FPS = 30

# Joints in the source model's own coordinates (Blender axes: +X is the left hand, -Y is the
# front, +Z is up), read off orthographic renders. Left side only; the right side mirrors X.
MODELS = {
    "hunter": {
        "height": 1.8,
        "spine": [(0, 0.02, 0.22), (0, 0.02, 0.32), (0, 0.02, 0.44), (0, 0.0, 0.58), (0, -0.01, 0.66), (0, -0.01, 0.90)],
        "arm": [(0.04, 0.02, 0.60), (0.20, 0.02, 0.605), (0.36, 0.01, 0.60), (0.47, 0, 0.60), (0.51, 0, 0.60)],
        "fingers": [(0.51, 0, 0.60), (0.54, 0, 0.60), (0.57, 0, 0.60)],
        "thumb": [(0.47, -0.03, 0.59), (0.49, -0.06, 0.55)],
        "leg": [(0.11, 0.02, 0.22), (0.13, 0.02, 0.135), (0.14, 0.03, 0.05), (0.16, -0.12, 0.02)],
        "arm_out": "hunter_arm",
    },
    "skinny": {
        "height": 1.8,
        "spine": [(0, 0.01, 0.33), (0, 0.01, 0.40), (0, 0.01, 0.50), (0, 0.01, 0.62), (0, 0.0, 0.69), (0, 0.0, 0.99)],
        "arm": [(0.03, 0, 0.61), (0.09, 0, 0.615), (0.25, 0, 0.605), (0.43, 0, 0.60), (0.48, 0, 0.60)],
        "fingers": [(0.48, 0, 0.60), (0.53, 0, 0.60), (0.58, 0, 0.60)],
        "thumb": [(0.44, -0.03, 0.59), (0.47, -0.06, 0.55)],
        "leg": [(0.06, 0.01, 0.33), (0.065, 0.01, 0.20), (0.07, 0.02, 0.06), (0.09, -0.10, 0.02)],
    },
    "heavy": {
        "height": 1.65,
        "spine": [(0, 0.02, 0.18), (0, 0.02, 0.27), (0, 0.02, 0.38), (0, 0.0, 0.52), (0, -0.01, 0.58), (0, -0.01, 0.79)],
        "arm": [(0.05, 0.02, 0.53), (0.20, 0.02, 0.53), (0.35, 0.02, 0.52), (0.48, 0.02, 0.51), (0.52, 0.02, 0.51)],
        "fingers": [(0.52, 0.02, 0.51), (0.55, 0.02, 0.51), (0.58, 0.02, 0.51)],
        "thumb": [(0.47, -0.01, 0.49), (0.49, -0.04, 0.45)],
        "leg": [(0.11, 0.02, 0.18), (0.12, 0.02, 0.10), (0.13, 0.0, 0.04), (0.14, -0.12, 0.015)],
    },
    "helper": {
        "height": 1.5,
        "spine": [(0, -0.02, 0.29), (0, -0.02, 0.40), (0, -0.02, 0.52), (0, -0.02, 0.66), (0, -0.01, 0.74), (0, -0.01, 1.05)],
        "arm": [(0.03, 0, 0.68), (0.17, 0, 0.68), (0.31, 0, 0.67), (0.44, 0, 0.665), (0.48, 0, 0.665)],
        "fingers": [(0.48, 0, 0.665), (0.52, 0, 0.665), (0.56, 0, 0.665)],
        "thumb": [(0.44, -0.03, 0.66), (0.47, -0.07, 0.65)],
        "leg": [(0.07, -0.01, 0.29), (0.07, -0.01, 0.19), (0.075, 0.0, 0.07), (0.08, -0.14, 0.02)],
        "animations": ["idle", "walk", "run", "sneak", "crouch", "hammer", "sit"],
        "hammer": ROOT / "assets" / "models" / "primitive_stone_hammer.glb",
    },
}
HAMMER_LENGTH = 0.5  # metres, handle end to head
HAMMER_TRIANGLES = 800
SPINE = ["hips", "spine", "chest", "neck", "head"]
ARM = ["shoulder", "upper_arm", "forearm", "hand"]
LEG = ["thigh", "shin", "foot"]
FINGERS = ["fingers", "fingertips"]  # the cartoon hands have three fingers and a thumb
AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def build_mesh(source: str, spec: dict) -> tuple[bpy.types.Object, Matrix]:
    bpy.ops.import_scene.gltf(filepath=source)
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
    mesh.data.transform(mesh.matrix_world)  # some exports stand the mesh up with a node rotation
    mesh.matrix_world = Matrix()
    low_z = min(v.co.z for v in mesh.data.vertices)
    high_z = max(v.co.z for v in mesh.data.vertices)
    scale = spec["height"] / (high_z - low_z)
    # Source coordinates -> metres with the feet on the ground.
    place = Matrix.Translation((0, 0, -low_z * scale)) @ Matrix.Scale(scale, 4)
    mesh.data.transform(place)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)  # Meshy splits vertices at UV seams
    bpy.ops.object.mode_set(mode="OBJECT")
    for image in bpy.data.images:
        if image.size[0] > TEXTURE_SIZE:
            image.scale(TEXTURE_SIZE, TEXTURE_SIZE)
    return mesh, place


def build_skeleton(spec: dict, place: Matrix) -> bpy.types.Object:
    data = bpy.data.armatures.new("skeleton")
    rig = bpy.data.objects.new("caveman", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    def chain(names: list[str], points: list, parent=None) -> None:
        for name, head, tail in zip(names, points, points[1:]):
            bone = data.edit_bones.new(name)
            bone.head, bone.tail = place @ Vector(head), place @ Vector(tail)
            bone.parent = parent
            bone.use_connect = parent is not None and (parent.tail - bone.head).length < 1e-4
            parent = bone

    chain(SPINE, spec["spine"])
    for side, sign in (("l", 1), ("r", -1)):
        mirror = lambda points: [(x * sign, y, z) for x, y, z in points]
        chain([f"{n}_{side}" for n in ARM], mirror(spec["arm"]), data.edit_bones["chest"])
        chain([f"{n}_{side}" for n in FINGERS], mirror(spec["fingers"]), data.edit_bones[f"hand_{side}"])
        chain([f"thumb_{side}"], mirror(spec["thumb"]), data.edit_bones[f"hand_{side}"])
        chain([f"{n}_{side}" for n in LEG], mirror(spec["leg"]), data.edit_bones["hips"])
    for bone in data.edit_bones:
        bone.roll = 0.0
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # Bone heat leaves loose bits (hair, teeth) unweighted when it fails: give them the nearest bone.
    bones = rig.data.bones
    for vertex in mesh.data.vertices:
        if any(g.weight > 0.01 for g in vertex.groups):
            continue
        nearest = min(bones, key=lambda b: _segment_distance(vertex.co, b.head_local, b.tail_local))
        mesh.vertex_groups[nearest.name].add([vertex.index], 1.0, "REPLACE")
    # The finger bones run down the middle finger, so bone heat leaves the outer fingers on the
    # hand and they stay straight in a fist: everything past the knuckles follows the finger bones.
    for side in ("l", "r"):
        groups = [mesh.vertex_groups[f"{n}_{side}"] for n in ("hand", "fingers", "fingertips")]
        knuckle, middle = bones[f"fingers_{side}"].head_local, bones[f"fingertips_{side}"].head_local
        along = (bones[f"hand_{side}"].tail_local - bones[f"hand_{side}"].head_local).normalized()
        for vertex in mesh.data.vertices:
            hand = sum(g.weight for g in vertex.groups if g.group in [x.index for x in groups])
            if hand < 0.5 or (vertex.co - knuckle).dot(along) < 0.005:
                continue
            for group in groups:
                group.remove([vertex.index])
            tip = (vertex.co - middle).dot(along) > 0
            groups[2 if tip else 1].add([vertex.index], 1.0, "REPLACE")


def cut(mesh: bpy.types.Object) -> None:
    """Decimate after skinning: weights computed on the full mesh keep fingers and joints clean."""
    bpy.context.view_layer.objects.active = mesh
    modifier = mesh.modifiers.new("cut", "DECIMATE")
    modifier.ratio = TRIANGLES / len(mesh.data.polygons)
    bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def _segment_distance(point: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    t = max(0.0, min(1.0, (point - a).dot(ab) / ab.length_squared))
    return (point - (a + ab * t)).length


# --- Animation --------------------------------------------------------------------------------
# A pose maps bone -> rotations [(axis, degrees), ...] in armature space, applied in order and
# carried by the parent bones. Rest is the T-pose. Useful facts: left arm Y+ lowers it, X-
# swings a hanging arm or leg forward, forearm_l Z- bends the elbow forward, shin X+ bends the
# knee, spine X+ leans forward, spine Z+ turns the chest to the left. sym() mirrors left-side
# rotations to the right side (Y and Z flip sign). "lift" moves the hips up (metres);
# "crouch" lowers them until the feet touch the ground.


def sym(pose: dict) -> dict:
    out = {}
    for bone, rots in pose.items():
        if bone.endswith("_l"):
            out[bone[:-2] + "_r"] = [(a, -d if a in "YZ" else d) for a, d in rots]
        out[bone] = rots
    return out


def merge(*poses: dict) -> dict:
    out: dict = {}
    for pose in poses:
        for bone, rots in pose.items():
            out[bone] = rots
    return out


ARMS_DOWN = sym({"upper_arm_l": [("Y", 72)], "forearm_l": [("Z", -12)]})
# Fists around a weapon handle; every pose has them unless it says otherwise.
FISTS = sym({"fingers_l": [("Y", 85)], "fingertips_l": [("Y", 80)], "thumb_l": [("Z", 55), ("Y", 20)]})


def stride(swing_l: float, knee_l: float, swing_r: float, knee_r: float, arm: float, elbow: float) -> dict:
    """Legs swing (X- forward) with knees bent; arms swing opposite the legs."""
    return {
        "thigh_l": [("X", swing_l)], "shin_l": [("X", knee_l)], "foot_l": [("X", -(swing_l + knee_l) * 0.6)],
        "thigh_r": [("X", swing_r)], "shin_r": [("X", knee_r)], "foot_r": [("X", -(swing_r + knee_r) * 0.6)],
        "upper_arm_l": [("Y", 72), ("X", arm)], "upper_arm_r": [("Y", -72), ("X", -arm)],
        "forearm_l": [("Z", -elbow)], "forearm_r": [("Z", elbow)],
    }


def gait(length: int, swing: float, knee: float, arm: float, elbow: float, bob: float, extra: dict) -> list:
    contact = merge(extra, stride(-swing, 5, swing * 0.8, 15, arm, elbow), {"lift": -bob})
    passing = merge(extra, stride(0, 5, -swing * 0.4, knee, 0, elbow), {"lift": bob})
    mirror = lambda p: {_flip(b): [(a, -d if a in "YZ" else d) for a, d in r] if b != "lift" else r for b, r in p.items()}
    keys = [contact, passing, mirror(contact), mirror(passing), contact]
    return [(round(i * length / 4), pose) for i, pose in enumerate(keys)]


def _flip(bone: str) -> str:
    return bone[:-2] + {"_l": "_r", "_r": "_l"}[bone[-2:]] if bone[-2:] in ("_l", "_r") else bone


def idle() -> list:
    breathe = lambda d: merge(ARMS_DOWN, {"chest": [("X", d)], "head": [("X", -d)]})
    return [(0, breathe(0)), (30, breathe(3)), (60, breathe(0))]


def walk() -> list:
    return gait(30, 25, 45, 18, 15, 0.02, {"spine": [("X", 4)]})


def run() -> list:
    return gait(20, 45, 95, 40, 85, 0.05, {"spine": [("X", 14)], "head": [("X", -10)]})


def sneak() -> list:
    hunch = merge(sym({"upper_arm_l": [("Y", 72), ("X", -35)], "forearm_l": [("Z", -75)]}),
                  {"spine": [("X", 22)], "chest": [("X", 12)], "head": [("X", -28)]})
    step = lambda s: merge(hunch, {
        "thigh_l": [("X", -50 - s)], "shin_l": [("X", 85 + abs(s) * 0.5)], "foot_l": [("X", -35 + s * 0.5)],
        "thigh_r": [("X", -50 + s)], "shin_r": [("X", 85 + abs(s) * 0.5)], "foot_r": [("X", -35 - s * 0.5)],
        "lift": "crouch"})
    return [(0, step(15)), (10, merge(step(0), {"spine": [("X", 22), ("Z", 4)]})), (20, step(-15)),
            (30, merge(step(0), {"spine": [("X", 22), ("Z", -4)]})), (40, step(15))]


def ride() -> list:
    seat = merge(sym({"thigh_l": [("X", -50), ("Y", -42)], "shin_l": [("X", 70)], "foot_l": [("X", -10)],
                      "upper_arm_l": [("Y", 70), ("X", -40)], "forearm_l": [("Z", -45)]}),
                 {"lift": 0.0})
    bounce = lambda up, lean: merge(seat, {"spine": [("X", lean)], "head": [("X", -lean * 0.8)],
                                           "lift": up})
    return [(0, bounce(0.0, 10)), (6, bounce(0.05, 18)), (12, bounce(0.0, 10)), (18, bounce(0.04, 16)), (24, bounce(0.0, 10))]


def attack() -> list:
    rest = merge(ARMS_DOWN, {})
    windup = merge(ARMS_DOWN, {"upper_arm_r": [("Y", 82), ("X", 8)], "forearm_r": [("Z", -80)],
                               "chest": [("Z", -22), ("X", -6)], "spine": [("X", -4)]})
    strike = merge(ARMS_DOWN, {"upper_arm_r": [("Y", -72), ("X", -75)], "forearm_r": [("Z", 10)],
                               "chest": [("Z", 22), ("X", 14)], "spine": [("X", 10)], "head": [("X", -14)]})
    return [(0, rest), (8, windup), (13, strike), (20, strike), (30, rest)]


def strong_attack() -> list:
    """Charged blow: a deep wind-up held while the weapon shakes with effort, then the release."""
    rest = merge(ARMS_DOWN, {})
    held = lambda shake: merge(ARMS_DOWN, {
        "upper_arm_r": [("Y", 85), ("X", 30 + shake)], "forearm_r": [("Z", -110)],
        "chest": [("Z", -40), ("X", -10 + shake * 0.5)], "spine": [("X", -6), ("Z", -10)], "head": [("Z", 25)],
        "upper_arm_l": [("Y", 60), ("X", -45)], "forearm_l": [("Z", -40)],
        "thigh_l": [("X", -25)], "shin_l": [("X", 35)], "foot_l": [("X", -10)],
        "thigh_r": [("X", 15)], "shin_r": [("X", 35)], "foot_r": [("X", -50)], "lift": "crouch"})
    release = merge(ARMS_DOWN, {
        "upper_arm_r": [("Y", -72), ("X", -85)], "forearm_r": [("Z", 5)],
        "chest": [("Z", 30), ("X", 18)], "spine": [("X", 16)], "head": [("X", -20)],
        "thigh_l": [("X", -35)], "shin_l": [("X", 50)], "foot_l": [("X", -15)],
        "thigh_r": [("X", 20)], "shin_r": [("X", 30)], "foot_r": [("X", -50)], "lift": "crouch"})
    hold = [(18 + i * 4, held(2.5 if i % 2 else -2.5)) for i in range(9)]
    return [(0, rest), (14, held(0))] + hold + [(56, held(0)), (61, release), (72, release), (90, rest)]


def bow_shot() -> list:
    """The bow arm aims in front of the face; the right fist finds the string at the bow ("reach",
    solved in animate) and draws it back along the arrow line to the chin."""
    rest = merge(ARMS_DOWN, {})
    aim = {"chest": [("Z", -25)], "neck": [("Z", 15)], "head": [("Z", 12)],
           "upper_arm_l": [("X", -90), ("Z", -78), ("Y", -4)], "forearm_l": [("Z", -4)]}  # X -90 stands the bow upright
    nock = merge(ARMS_DOWN, aim, {"reach": 0.0})
    draw = merge(ARMS_DOWN, aim, {"reach": 1.0})
    loose = merge(ARMS_DOWN, aim, {"reach": 1.15})
    return [(0, rest), (10, nock), (24, draw), (32, draw), (34, loose), (44, loose), (58, rest)]


# The helper's squat: heels down, knees up to the chest; the left hand rests on the knee.
SQUAT = merge(sym({"thigh_l": [("X", -100), ("Y", -15)], "shin_l": [("X", 140)], "foot_l": [("X", -40)]}),
              {"upper_arm_l": [("Y", 72), ("X", -45)], "forearm_l": [("Z", -40)],
               "upper_arm_r": [("Y", -72)], "spine": [("X", 28)], "chest": [("X", 8)], "head": [("X", -25)],
               "lift": "crouch"})
# Right arm at the bottom of a hammer blow: reaching down in front, so the head meets the ground.
HAMMER_STRIKE = {"upper_arm_r": [("Y", -72), ("X", -55)], "forearm_r": [("Z", 25)]}


def crouch() -> list:
    breathe = lambda d: merge(SQUAT, {"chest": [("X", 8 + d)]})
    return [(0, breathe(0)), (30, breathe(3)), (60, breathe(0))]


def hammer() -> list:
    """Squatting at a trap ghost: the hammer goes up over the shoulder and comes down on the ground."""
    up = merge(SQUAT, {"upper_arm_r": [("Y", -72), ("X", -150)], "forearm_r": [("Z", 100)], "chest": [("X", 2), ("Z", -8)]})
    strike = merge(SQUAT, HAMMER_STRIKE, {"chest": [("X", 14), ("Z", 6)]})
    return [(0, up), (7, strike), (10, merge(strike, {"forearm_r": [("Z", 30)]})), (20, up)]


def sit() -> list:
    """At the tavern table: on a bench of knee height, forearms on the table."""
    seat = merge(sym({"thigh_l": [("X", -88)], "shin_l": [("X", 88)], "foot_l": [("X", 0)],
                      "upper_arm_l": [("Y", 72), ("X", -40)], "forearm_l": [("Z", -70)]}), {"lift": "crouch"})
    breathe = lambda d: merge(seat, {"chest": [("X", 4 + d)], "head": [("X", -d), ("Z", d * 2)]})
    return [(0, breathe(0)), (45, breathe(4)), (90, breathe(0))]


# The game viewer loops idle, walk, run, sneak and ride.
ANIMATIONS = {"idle": idle, "walk": walk, "run": run, "sneak": sneak, "ride": ride,
              "attack": attack, "strong_attack": strong_attack, "bow_shot": bow_shot,
              "crouch": crouch, "hammer": hammer, "sit": sit}
DEFAULT_ANIMATIONS = ["idle", "walk", "run", "sneak", "ride", "attack", "strong_attack", "bow_shot"]


def _quat(rots: list) -> Quaternion:
    q = Quaternion()
    for axis, degrees in rots:
        q = Quaternion(AXES[axis], math.radians(degrees)) @ q
    return q


def _crouch(rig: bpy.types.Object, pose: dict) -> float:
    """How far the hips move so that the left foot stays on the ground in this pose."""
    bones = rig.data.bones
    thigh, shin = bones["thigh_l"], bones["shin_l"]
    hip = thigh.head_local
    q_thigh = _quat(pose.get("thigh_l", []))
    knee = hip + q_thigh @ (thigh.tail_local - thigh.head_local)
    ankle = knee + q_thigh @ _quat(pose.get("shin_l", [])) @ (shin.tail_local - shin.head_local)
    return shin.tail_local.z - ankle.z


def _fk(rig: bpy.types.Object, pose: dict) -> dict:
    """Armature-space (head, rotation) of every posed bone; parents come before children."""
    out = {}
    for bone in rig.data.bones:
        q = _quat(pose.get(bone.name, []))
        if bone.parent:
            head, rotation = out[bone.parent.name]
            out[bone.name] = (head + rotation @ (bone.head_local - bone.parent.head_local), rotation @ q)
        else:
            out[bone.name] = (bone.head_local.copy(), q)
    return out


def _reach(rig: bpy.types.Object, pose: dict, pull: float) -> dict:
    """Right arm rotations that put the right fist on the bow string, drawn back `pull` of the way
    from the bow to the chin along the arrow line."""
    bones = _fk(rig, pose)
    grip = bones["fingers_l"][0]
    aim = (grip - bones["hand_l"][0]).normalized()
    chin = bones["head"][0] + aim * 0.05
    target = grip - aim * (0.1 + ((grip - chin).dot(aim) - 0.1) * pull)
    angles = [10.0, 0.0, 90.0]
    arm = lambda a: {"upper_arm_r": [("Y", a[0]), ("Z", a[1])], "forearm_r": [("Z", a[2])]}
    miss = lambda a: (_fk(rig, merge(pose, arm(a)))["fingers_r"][0] - target).length
    for step in (16, 8, 4, 2, 1, 0.5):
        for i in range(3):
            for delta in (step, -step):
                trial = angles.copy()
                trial[i] += delta
                while miss(trial) < miss(angles):
                    angles = trial.copy()
                    trial[i] += delta
    return arm(angles)


def animate(rig: bpy.types.Object, name: str, keys: list) -> bpy.types.Action:
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action["keys"] = [frame for frame, _ in keys]
    rig.animation_data_create()
    rig.animation_data.action = action
    hips_rest = rig.data.bones["hips"].matrix_local.to_quaternion()
    for frame, pose in keys:
        lift = pose.get("lift", 0.0)
        if lift == "crouch":
            lift = _crouch(rig, pose)
        pose = merge(FISTS, pose)
        if "reach" in pose:
            pose = merge(pose, _reach(rig, pose, pose["reach"]))
        for bone in rig.pose.bones:
            rest = bone.bone.matrix_local.to_quaternion()
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = rest.inverted() @ _quat(pose.get(bone.name, [])) @ rest
            bone.keyframe_insert("rotation_quaternion", frame=frame)
        hips = rig.pose.bones["hips"]
        hips.location = hips_rest.inverted() @ Vector((0, 0, lift))
        hips.keyframe_insert("location", frame=frame)
    return action


def add_hammer(rig: bpy.types.Object, source: Path) -> None:
    """The owner's stone hammer in the right fist, angled so that its head meets the ground at the
    bottom of the blow; it rides on the hand bone."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(source))
    parts = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.join()
    tool = bpy.context.view_layer.objects.active
    tool.name = "hammer"
    tool.data.transform(tool.matrix_world)
    tool.matrix_world = Matrix()
    for leftover in [o for o in bpy.data.objects if o not in before and o != tool]:
        bpy.data.objects.remove(leftover)
    modifier = tool.modifiers.new("cut", "DECIMATE")
    modifier.ratio = min(1.0, HAMMER_TRIANGLES / len(tool.data.polygons))
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    low = min(v.co.z for v in tool.data.vertices)
    tool.data.transform(Matrix.Scale(HAMMER_LENGTH / (max(v.co.z for v in tool.data.vertices) - low), 4))
    # Handle along local +Z from the grip at the origin. At the strike the handle points down and forward.
    bones = _fk(rig, merge(FISTS, SQUAT, HAMMER_STRIKE))
    hand = bones["hand_r"][1]
    down = Vector((0, -0.6, -1)).normalized()
    side = Vector((1, 0, 0))
    aim = Matrix((side, down.cross(side), down)).transposed().to_quaternion()
    rest_hand = hand.inverted() @ aim  # the handle's turn relative to the hand
    rest_fist = rig.data.bones["fingers_r"].head_local
    tool.matrix_world = Matrix.Translation(rest_fist) @ rest_hand.to_matrix().to_4x4()
    tool.parent = rig
    tool.parent_type = "BONE"
    tool.parent_bone = "hand_r"
    tool.matrix_parent_inverse = (rig.matrix_world @ Matrix.Translation(rig.data.bones["hand_r"].tail_local)
                                  @ rig.data.bones["hand_r"].matrix_local.to_3x3().to_4x4()).inverted()


def export_arm(mesh: bpy.types.Object, rig: bpy.types.Object, name: str) -> None:
    """The right forearm and fist at full detail for the first-person view (hands.tscn): posed into
    a fist, cut at the elbow, fist at the origin, thumb up and the forearm reaching back to the
    bottom right of the view."""
    action = animate(rig, "fist", [(0, {})])
    bpy.context.scene.frame_set(0)
    arm = mesh.copy()
    arm.data = mesh.data.copy()
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.modifier_apply(modifier=arm.modifiers[0].name)
    arm.parent = None
    names = {g.index: g.name for g in arm.vertex_groups}
    owner = lambda v: names[max(v.groups, key=lambda g: g.weight).group] if v.groups else ""
    keep = {f"{n}_r" for n in ("forearm", "hand", "fingers", "fingertips", "thumb")}
    fist = [v.co.copy() for v in arm.data.vertices if owner(v) in keep - {"forearm_r"}]
    thumb = [v.co.copy() for v in arm.data.vertices if owner(v) == "thumb_r"]
    drop = [v.index for v in arm.data.vertices if owner(v) not in keep]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for i in drop:
        arm.data.vertices[i].select = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.vertex_groups.clear()
    smooth = arm.modifiers.new("smooth", "SUBSURF")  # the source has about 300 triangles here; seen up close
    smooth.levels = 1
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    bpy.ops.object.shade_smooth()
    centre = sum(fist, Vector()) / len(fist)
    back = (_fk(rig, FISTS)["forearm_r"][0] - centre).normalized()
    up = sum(thumb, Vector()) / len(thumb) - centre
    # Blender axes of hand.glb's forearm (glTF (0.05, -0.11, 0.29)): back toward the camera, down, right.
    to_back = Vector((0.05, -0.29, -0.11)).normalized()
    to_up = Vector((0, 0, 1))
    basis = lambda b, u: Matrix((b, (u - b * u.dot(b)).normalized(), b.cross((u - b * u.dot(b)).normalized()))).transposed()
    turn = basis(to_back, to_up) @ basis(back, up).inverted()
    arm.data.transform(turn.to_4x4() @ Matrix.Translation(-centre))
    print(name, "triangles:", sum(len(p.vertices) - 2 for p in arm.data.polygons))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB", export_image_format="JPEG",
                              export_animations=False, export_skins=False, use_selection=True)
    bpy.data.objects.remove(arm)
    bpy.data.actions.remove(action)


def preview(rig: bpy.types.Object, actions: list, out_dir: Path, kind: str) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"  # Workbench needs EGL, which headless machines often lack
    scene.cycles.samples = 4
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 3.0
    scene.world = world
    scene.render.resolution_x = scene.render.resolution_y = 240
    camera = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.6
    frames = []
    views = [((0.8, -4.5, 1.0), (88, 0, 10)), ((4.5, -0.8, 1.0), (88, 0, 80))]
    for action in actions:
        rig.animation_data.action = action
        keys = list(action["keys"])
        for i, frame in enumerate(keys):
            scene.frame_set(frame)
            for v, (location, rotation) in enumerate(views):
                camera.location = location
                camera.rotation_euler = [math.radians(a) for a in rotation]
                path = out_dir / f"{kind}_{action.name}_{i}_{v}.png"
                scene.render.filepath = str(path)
                bpy.ops.render.render(write_still=True)
                frames.append(path)
    print("preview frames:", len(frames))


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    kind, source = args[0], args[1]
    preview_dir = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    spec = MODELS[kind]
    mesh, place = build_mesh(source, spec)
    rig = build_skeleton(spec, place)
    skin(mesh, rig)
    if "arm_out" in spec:
        export_arm(mesh, rig, spec["arm_out"])
    cut(mesh)
    actions = [animate(rig, name, ANIMATIONS[name]()) for name in spec.get("animations", DEFAULT_ANIMATIONS)]
    if "hammer" in spec:
        add_hammer(rig, spec["hammer"])
    rig.animation_data.action = actions[0]
    print(kind, "triangles:", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
    if preview_dir:
        preview(rig, actions, preview_dir, kind)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"caveman_{kind}.glb"), export_format="GLB",
                              export_animation_mode="ACTIONS", export_image_format="JPEG",
                              export_force_sampling=True, export_frame_step=1, use_selection=True)


if __name__ == "__main__":
    main()
