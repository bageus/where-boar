#!/usr/bin/env python3
"""Rig, skin and animate the owner's caveman models into assets/models/caveman_<kind>.glb.

Needs Blender as a Python module (`pip install bpy`). The source models are Meshy exports in
T-pose, about 80k-110k triangles each; they are cut to TRIANGLES, given one 19-bone skeleton
(joints placed from the landmarks below), skinned with Blender's automatic weights, and get
the animations in ANIMATIONS. Run after a change:
    python tools/rig_cavemen.py skinny path/to/caveman_skinny.glb
    python tools/rig_cavemen.py heavy path/to/caveman_heavy.glb
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
    "skinny": {
        "height": 1.8,
        "spine": [(0, 0.02, -0.22), (0, 0.02, -0.05), (0, 0.02, 0.10), (0, 0.02, 0.26), (0, 0.0, 0.34), (0, 0.0, 0.72)],
        "arm": [(0.03, 0.02, 0.22), (0.13, 0.02, 0.19), (0.42, 0.02, 0.17), (0.72, 0.02, 0.17), (0.92, 0.02, 0.16)],
        "leg": [(0.09, 0.02, -0.24), (0.10, 0.05, -0.50), (0.12, 0.08, -0.72), (0.19, -0.18, -0.78)],
    },
    "heavy": {
        "height": 1.65,
        "spine": [(0, 0.03, -0.20), (0, 0.03, -0.02), (0, 0.03, 0.12), (0, 0.03, 0.28), (0, 0.0, 0.34), (0, 0.0, 0.62)],
        "arm": [(0.06, 0.03, 0.25), (0.30, 0.04, 0.23), (0.58, 0.04, 0.21), (0.78, 0.04, 0.20), (0.93, 0.04, 0.19)],
        "leg": [(0.17, 0.03, -0.22), (0.17, 0.04, -0.42), (0.18, 0.05, -0.56), (0.22, -0.15, -0.61)],
    },
}
SPINE = ["hips", "spine", "chest", "neck", "head"]
ARM = ["shoulder", "upper_arm", "forearm", "hand"]
LEG = ["thigh", "shin", "foot"]
AXES = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def build_mesh(source: str, spec: dict) -> tuple[bpy.types.Object, Matrix]:
    bpy.ops.import_scene.gltf(filepath=source)
    mesh = next(o for o in bpy.data.objects if o.type == "MESH")
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
    cut = mesh.modifiers.new("cut", "DECIMATE")
    cut.ratio = TRIANGLES / len(mesh.data.polygons)
    bpy.ops.object.modifier_apply(modifier=cut.name)
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
    rest = merge(ARMS_DOWN, {})
    windup = merge(sym({"upper_arm_l": [("Y", -78), ("X", 12)], "forearm_l": [("Z", 60)],
                        "thigh_l": [("X", -12)], "shin_l": [("X", 20)], "foot_l": [("X", -8)]}),
                   {"spine": [("X", -16)], "chest": [("X", -10)], "head": [("X", 10)], "lift": 0.03})
    slam = merge(sym({"upper_arm_l": [("Y", 72), ("X", -80)], "forearm_l": [("Z", -8)],
                      "thigh_l": [("X", -35)], "shin_l": [("X", 60)], "foot_l": [("X", -25)]}),
                 {"spine": [("X", 30)], "chest": [("X", 14)], "head": [("X", -32)], "lift": "crouch"})
    return [(0, rest), (20, windup), (28, windup), (34, slam), (46, slam), (60, rest)]


def bow_shot() -> list:
    rest = merge(ARMS_DOWN, {})
    aim = {"chest": [("Z", -25)], "neck": [("Z", 15)], "head": [("Z", 12)],
           "upper_arm_l": [("Z", -62), ("Y", -4)], "forearm_l": [("Z", -4)]}
    nock = merge(ARMS_DOWN, aim, {"upper_arm_r": [("Y", 8), ("Z", 20)], "forearm_r": [("Z", 95)]})
    draw = merge(ARMS_DOWN, aim, {"upper_arm_r": [("Y", 12), ("Z", -12)], "forearm_r": [("Z", 140)]})
    loose = merge(ARMS_DOWN, aim, {"upper_arm_r": [("Y", 16), ("Z", -32)], "forearm_r": [("Z", 105)]})
    return [(0, rest), (10, nock), (24, draw), (32, draw), (34, loose), (44, loose), (58, rest)]


# The game viewer loops idle, walk, run, sneak and ride.
ANIMATIONS = {"idle": idle, "walk": walk, "run": run, "sneak": sneak, "ride": ride,
              "attack": attack, "strong_attack": strong_attack, "bow_shot": bow_shot}


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
        for bone in rig.pose.bones:
            rest = bone.bone.matrix_local.to_quaternion()
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = rest.inverted() @ _quat(pose.get(bone.name, [])) @ rest
            bone.keyframe_insert("rotation_quaternion", frame=frame)
        hips = rig.pose.bones["hips"]
        hips.location = hips_rest.inverted() @ Vector((0, 0, lift))
        hips.keyframe_insert("location", frame=frame)
    return action


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
    actions = [animate(rig, name, make()) for name, make in ANIMATIONS.items()]
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
