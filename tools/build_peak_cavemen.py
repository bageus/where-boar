#!/usr/bin/env python3
"""Owner's reference cavemen (2026-11-02) as low-poly models: three hunters the player picks in the
settings (bearded, plump, lanky) and the helper in a hamster hat and patchwork tunic.

Builds each T-pose from simple faceted parts (tools/peak_caveman_parts.py), then rigs and animates it
with tools/rig_cavemen.py (same 25-bone skeleton and animations as before, so the backpack, the
helper's hammer and every animation name still work). Writes assets/models/peak_cavemen/<kind>.glb
and, for hunters, arm_<kind>.glb (the first-person forearm and fist). Needs `pip install bpy`.
    python tools/build_peak_cavemen.py bearded [--preview DIR]
    python tools/build_peak_cavemen.py all
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import peak_caveman_parts as P  # noqa: E402
import rig_cavemen as R  # noqa: E402

OUT = R.ROOT / "assets" / "models" / "peak_cavemen"
SKIN, HAIR, HIDE, BELT, DARK = "ec7036", "64193f", "8a4a22", "7d2a5c", "3b1d16"
HAIR_LIGHT = "6e1f5e"


def mats() -> dict:
    return {"skin": P.material("skin", SKIN), "hair": P.material("hair", HAIR), "hair2": P.material("hair2", HAIR_LIGHT),
            "hide": P.material("hide", HIDE), "belt": P.material("belt", BELT), "dark": P.material("dark", DARK),
            "orange": P.material("orange", "e06a28"), "cream": P.material("cream", "f7d09c"),
            "brown": P.material("brown", "86421f"), "rust": P.material("rust", "cf5a1c"), "pink": P.material("pink", "ef7f6f")}


def body(p: dict, m: dict) -> dict:
    """Skin parts every character shares; returns the skeleton landmarks for rig_cavemen."""
    hx, hz, kz, az = p["hip_x"], p["hip_z"], p["knee_z"], p["ankle_z"]
    lr = p["leg_r"]
    fx, fy, fz = p["foot"]
    sz, sx, ex, wx = p["shoulder_z"], p["shoulder_x"], p["elbow_x"], p["wrist_x"]
    palm, finger, hw, hh = p["hand"]
    for s in (1, -1):
        P.loft("leg", m["skin"], [(s * hx, 0, hz + 0.05), (s * hx, 0, kz), (s * (hx + 0.005), 0, az)], lr, sides=7)
        P.block("foot", m["skin"], (s * (hx + 0.01), -fy * 0.3, fz / 2), (fx, fy, fz), bevel=min(fx, fz) * 0.3)
        P.loft("arm", m["skin"], [(s * (sx - 0.04), 0, sz), (s * ex, 0, sz), (s * (wx + 0.01), 0, sz)], p["arm_r"], sides=7, up=(0, 0, 1))
        P.ball("shoulder", m["skin"], (s * sx, 0, sz), (p["arm_r"][0] * 1.15,) * 3, segments=8, rings=6)
        P.block("palm", m["skin"], (s * (wx + palm / 2), 0, sz), (palm + 0.01, hw, hh), bevel=hh * 0.25)
        P.block("fingers", m["skin"], (s * (wx + palm + finger / 2), 0, sz - hh * 0.06), (finger, hw * 0.92, hh * 0.85), bevel=hh * 0.3)
        P.loft("thumb", m["skin"], [(s * (wx + palm * 0.35), -hw * 0.3, sz - 0.005), (s * (wx + palm * 0.75), -hw * 0.95, sz - hh * 0.55)],
               [hh * 0.28, hh * 0.24], sides=6)
    P.loft("torso", m["skin"], [(0, y, z) for z, _, _, y in p["torso"]], [(rx, ry) for _, rx, ry, _ in p["torso"]],
           sides=10, up=(0, -1, 0))
    if "neck" in p:
        z0, z1, r = p["neck"]
        P.loft("neck", m["skin"], [(0, 0, z0), (0, 0, z1)], [r, r], sides=7)
    hc, hs = p["head"]
    P.block("head", m["skin"], hc, hs, bevel=hs[0] * 0.18, bind="head")
    face = hc[1] - hs[1] / 2 - 0.003
    ex_, ez, er = p["eyes"]
    for s in (1, -1):
        P.ball("eye", m["dark"], (s * ex_, face, ez), (er, er * 0.5, er * 1.45), segments=8, rings=5, bind="head")
        ox, oz, orad = p["ears"]
        P.ball("ear", m["skin"], (s * ox, hc[1] + 0.01, oz), (orad * 0.7, orad * 0.55, orad), segments=8, rings=5, bind="head")
    mz, mw = p["mouth"]
    P.block("mouth", m["dark"], (0, face, mz), (mw, 0.012, 0.009), bind="head")
    top = hc[2] + hs[2] / 2 + 0.06
    return {
        "height": p["height"],
        "spine": [(0, 0, hz), (0, 0, hz + (sz - hz) * 0.3), (0, 0, hz + (sz - hz) * 0.62), (0, 0, sz), (0, 0, hc[2] - hs[2] * 0.42), (0, 0, top)],
        "arm": [(0.04, 0, sz), (sx, 0, sz), (ex, 0, sz), (wx, 0, sz), (wx + palm, 0, sz)],
        "fingers": [(wx + palm, 0, sz), (wx + palm + finger / 2, 0, sz), (wx + palm + finger, 0, sz)],
        "thumb": [(wx + palm * 0.35, -hw * 0.3, sz - 0.005), (wx + palm * 0.75, -hw * 0.95, sz - hh * 0.55)],
        "leg": [(hx, 0, hz), (hx, 0, kz), (hx + 0.005, 0, az), (hx + 0.01, -fy * 0.75, 0.02)],
    }


def hide_outfit(m: dict, waist: tuple, hem: tuple, sash: tuple, teeth: int = 7) -> None:
    """Hide skirt with a zigzag hem, a belt and a sash over the left shoulder (hunters 1-3)."""
    zt, rxt, ryt, yt = waist
    zb, rxb, ryb, tooth = hem
    P.skirt("skirt", [m["hide"]], zt + 0.03, (rxt, ryt), zb, (rxb, ryb), teeth, tooth, y=yt)
    P.band("belt", m["belt"], (0, yt, zt), (rxt + 0.02, ryt + 0.02), 0, 0.075, 0.035, bind="hips", segments=14)
    centre, radii, tilt, width = sash
    P.band("sash", m["hide"], centre, radii, tilt, width, 0.03, bind="chest", segments=16)


def crown(m, mat: str, centre, inner: float, outer: float, width: float, angles, lean: float) -> None:
    """Locks fanned round the head in the front view (angle 0 is straight up); lean > 0 tips them back."""
    c = Vector(centre)
    for i, a in enumerate(angles):
        wobble = 0.12 * ((i * 37) % 5 - 2)
        d = Vector((math.sin(math.radians(a) + wobble * 0.3), lean, math.cos(math.radians(a)))).normalized()
        P.spike("lock", m[mat], c + d * inner, c + d * (outer + 0.02 * ((i * 13) % 3)), width, bind="head", depth=width * 0.75)


def spikes(m, mat: str, root, tips: list, width: float) -> None:
    for tip in tips:
        P.spike("lock", m[mat], root, tip, width, bind="head", depth=width * 0.7)


def bearded(m: dict) -> dict:
    p = {"height": 1.8, "hip_x": 0.14, "hip_z": 0.52, "knee_z": 0.3, "ankle_z": 0.12, "leg_r": [0.125, 0.115, 0.105],
         "foot": (0.22, 0.29, 0.14), "shoulder_z": 1.08, "shoulder_x": 0.27, "elbow_x": 0.52, "wrist_x": 0.76,
         "arm_r": [0.1, 0.088, 0.072], "hand": (0.1, 0.1, 0.12, 0.13),
         "torso": [(0.46, 0.29, 0.19, 0), (0.6, 0.31, 0.2, 0), (0.86, 0.32, 0.21, 0), (1.04, 0.32, 0.21, 0), (1.14, 0.28, 0.19, 0), (1.2, 0.15, 0.12, 0)],
         "head": ((0, -0.01, 1.43), (0.4, 0.36, 0.42)), "eyes": (0.08, 1.47, 0.026), "mouth": (1.405, 0.065), "ears": (0.215, 1.43, 0.06)}
    lm = body(p, m)
    hide_outfit(m, (0.68, 0.31, 0.21, 0), (0.36, 0.35, 0.25, 0.09), ((0, 0, 0.92), (0.44, 0.235), -40, 0.2))
    # Hair: a bushy mass behind and over the head, spiky locks all round, and a full beard round the face.
    P.ball("hair", m["hair"], (0, 0.06, 1.52), (0.215, 0.2, 0.25), segments=8, rings=6, bind="head")
    crown(m, "hair", (0, 0.03, 1.5), 0.16, 0.29, 0.1, range(-105, 106, 30), lean=-0.15)
    crown(m, "hair", (0, 0.1, 1.5), 0.14, 0.28, 0.1, range(-90, 91, 45), lean=0.6)
    beard = [(0.2, 0.15), (0.21, -0.02), (0.2, -0.12), (0.17, -0.2), (0.13, -0.17), (0.11, -0.27), (0.06, -0.23), (0.02, -0.3),
             (-0.02, -0.25), (-0.07, -0.29), (-0.11, -0.22), (-0.15, -0.25), (-0.19, -0.14), (-0.21, -0.03), (-0.2, 0.15),
             (-0.14, 0.15), (-0.14, 0.0), (-0.09, -0.06), (-0.035, -0.055), (0.0, -0.065), (0.035, -0.055), (0.09, -0.06), (0.14, 0.0), (0.14, 0.15)]
    P.slab("beard", m["hair"], beard, -0.205, 0.13, z0=1.43, bind="head", bulge=0.025)
    P.ball("jaw", m["hair"], (0, -0.02, 1.32), (0.2, 0.17, 0.16), segments=9, rings=6, bind="head")
    return lm


def plump(m: dict) -> dict:
    p = {"height": 1.7, "hip_x": 0.16, "hip_z": 0.44, "knee_z": 0.26, "ankle_z": 0.11, "leg_r": [0.13, 0.12, 0.11],
         "foot": (0.23, 0.29, 0.14), "shoulder_z": 1.08, "shoulder_x": 0.28, "elbow_x": 0.54, "wrist_x": 0.78,
         "arm_r": [0.1, 0.085, 0.068], "hand": (0.085, 0.085, 0.11, 0.125),
         "torso": [(0.46, 0.3, 0.22, 0), (0.6, 0.36, 0.3, -0.04), (0.8, 0.38, 0.32, -0.05), (0.96, 0.33, 0.25, -0.02), (1.08, 0.27, 0.19, 0), (1.15, 0.15, 0.12, 0)],
         "head": ((0, -0.01, 1.33), (0.33, 0.31, 0.36)), "eyes": (0.065, 1.37, 0.021), "mouth": (1.3, 0.055), "ears": (0.185, 1.34, 0.05)}
    lm = body(p, m)
    P.ball("belly", m["skin"], (0, -0.1, 0.72), (0.43, 0.31, 0.33), segments=12, rings=8)
    hide_outfit(m, (0.5, 0.38, 0.28, -0.04), (0.28, 0.42, 0.31, 0.08), ((0, -0.07, 0.86), (0.53, 0.35), -38, 0.17), teeth=8)
    for z, y in ((0.47, -0.31), (0.4, -0.31)):
        P.block("knot", m["belt"], (-0.26, y, z - 0.06), (0.07, 0.04, 0.07), bevel=0.012, bind="hips")
    P.block("knot_tail", m["belt"], (-0.28, -0.29, 0.29), (0.06, 0.03, 0.14), bevel=0.01, bind="hips", tilt=(0, 10, 0))
    # Hair: a short crest of big locks on top and strips down the temples; a goatee under the mouth.
    P.ball("hair_top", m["hair2"], (0, 0.01, 1.47), (0.15, 0.15, 0.05), segments=8, rings=5, bind="head")
    spikes(m, "hair2", (0, 0.0, 1.5), [(-0.13, -0.08, 1.66), (0.0, -0.06, 1.72), (0.12, -0.02, 1.67), (0.18, 0.05, 1.58), (-0.04, 0.12, 1.66)], 0.1)
    for s in (1, -1):
        P.block("temple", m["hair2"], (s * 0.16, -0.03, 1.42), (0.025, 0.1, 0.12), bind="head")
    P.slab("goatee", m["hair2"], [(-0.035, 0.0), (0.035, 0.0), (0.02, -0.06), (0.0, -0.09), (-0.02, -0.06)], -0.17, 0.05, z0=1.28,
           bind="head")
    return lm


def lanky(m: dict) -> dict:
    p = {"height": 1.9, "hip_x": 0.08, "hip_z": 0.86, "knee_z": 0.47, "ankle_z": 0.1, "leg_r": [0.055, 0.045, 0.04],
         "foot": (0.13, 0.26, 0.09), "shoulder_z": 1.37, "shoulder_x": 0.14, "elbow_x": 0.42, "wrist_x": 0.72,
         "arm_r": [0.045, 0.038, 0.033], "hand": (0.08, 0.07, 0.08, 0.09),
         "torso": [(0.82, 0.13, 0.09, 0), (0.95, 0.14, 0.09, 0), (1.15, 0.15, 0.095, 0), (1.32, 0.16, 0.1, 0), (1.39, 0.12, 0.08, 0), (1.42, 0.05, 0.05, 0)],
         "neck": (1.38, 1.52, 0.04), "head": ((0, -0.01, 1.66), (0.25, 0.25, 0.34)), "eyes": (0.05, 1.7, 0.019),
         "mouth": (1.63, 0.045), "ears": (0.14, 1.67, 0.05)}
    lm = body(p, m)
    hide_outfit(m, (0.96, 0.15, 0.1, 0), (0.64, 0.18, 0.12, 0.07), ((0, 0, 1.17), (0.21, 0.12), -45, 0.1), teeth=6)
    for z in (0.92, 0.86):
        P.block("knot", m["belt"], (-0.1, -0.1, z), (0.04, 0.03, 0.05), bind="hips")
    P.block("knot_tail", m["belt"], (-0.12, -0.1, 0.8), (0.04, 0.02, 0.12), bind="hips", tilt=(0, 12, 0))
    # Hair: locks swept up and to the right, sideburns; a pointed goatee.
    P.ball("hair_top", m["hair2"], (0, 0.0, 1.8), (0.115, 0.115, 0.05), segments=8, rings=5, bind="head")
    spikes(m, "hair2", (0.0, 0.0, 1.8), [(-0.05, -0.1, 2.0), (0.05, -0.05, 2.02), (0.12, 0.0, 1.97), (0.17, -0.06, 1.88),
                                         (-0.1, 0.05, 1.95), (0.02, 0.1, 1.98)], 0.085)
    for s in (1, -1):
        P.block("sideburn", m["hair2"], (s * 0.12, -0.04, 1.73), (0.025, 0.1, 0.14), bind="head")
    P.slab("goatee", m["hair2"], [(-0.035, 0.0), (0.035, 0.0), (0.025, -0.07), (0.0, -0.11), (-0.025, -0.07)], -0.137, 0.05,
           z0=1.6, bind="head")
    return lm


def helper(m: dict) -> dict:
    p = {"height": 1.5, "hip_x": 0.07, "hip_z": 0.55, "knee_z": 0.3, "ankle_z": 0.08, "leg_r": [0.05, 0.045, 0.04],
         "foot": (0.12, 0.22, 0.08), "shoulder_z": 0.92, "shoulder_x": 0.15, "elbow_x": 0.33, "wrist_x": 0.5,
         "arm_r": [0.042, 0.036, 0.032], "hand": (0.07, 0.06, 0.075, 0.085),
         "torso": [(0.53, 0.14, 0.09, 0), (0.7, 0.14, 0.09, 0), (0.88, 0.15, 0.095, 0), (0.95, 0.1, 0.07, 0)],
         "neck": (0.93, 1.0, 0.04), "head": ((0, -0.01, 1.12), (0.27, 0.26, 0.3)), "eyes": (0.055, 1.12, 0.02),
         "mouth": (1.05, 0.04), "ears": (0.145, 1.11, 0.045)}
    lm = body(p, m)
    # Patchwork tunic to the knees: faces painted orange, cream, brown and rust in diagonal patches.
    patch = lambda r, k: [0, 3, 1, 0, 2, 3, 1, 2][((k + r) // 2 + (k * 5 + r * 3) % 3) % 8]
    P.skirt("tunic", [m["orange"], m["cream"], m["brown"], m["rust"]], 0.95, (0.12, 0.08), 0.42, (0.21, 0.15), 8, 0.07,
            rings=4, pattern=patch)
    for s in (1, -1):  # short sleeves with a ragged edge
        P.loft("sleeve", m["cream"] if s > 0 else m["orange"], [(s * 0.08, 0, 0.92), (s * 0.24, 0, 0.92)], [(0.075, 0.075), (0.06, 0.06)],
               sides=6, up=(0, 0, 1))
        P.block("collar", m["rust"], (s * 0.035, -0.105, 0.87), (0.035, 0.02, 0.17), tilt=(0, s * 28, 0))
    # Hamster hat: a furry dome with a cream muzzle, round ears, dark eyes and a pink nose.
    P.ball("hat", m["orange"], (0, 0.01, 1.25), (0.24, 0.22, 0.19), segments=10, rings=7, bind="head")
    P.ball("hat_rim", m["cream"], (0, 0.0, 1.18), (0.235, 0.215, 0.05), segments=10, rings=5, bind="head")
    P.ball("muzzle", m["cream"], (0, -0.18, 1.23), (0.13, 0.06, 0.06), segments=8, rings=5, bind="head")
    P.ball("nose", m["pink"], (0, -0.235, 1.26), (0.024, 0.018, 0.018), segments=6, rings=4, bind="head")
    for s in (1, -1):
        P.ball("hat_eye", m["dark"], (s * 0.075, -0.19, 1.32), (0.017, 0.01, 0.02), segments=6, rings=4, bind="head")
        P.ball("hat_ear", m["orange"], (s * 0.165, 0.0, 1.4), (0.07, 0.035, 0.07), segments=8, rings=5, bind="head")
        P.ball("hat_ear_in", m["cream"], (s * 0.165, -0.03, 1.4), (0.043, 0.012, 0.043), segments=8, rings=4, bind="head")
        P.block("hair_side", m["hair2"], (s * 0.13, 0.04, 1.15), (0.025, 0.12, 0.12), bind="head")
    P.spike("fringe", m["hair2"], (0.05, -0.12, 1.21), (-0.07, -0.15, 1.13), 0.04, bind="head", depth=0.015)
    P.spike("fringe", m["hair2"], (0.0, -0.12, 1.21), (0.08, -0.15, 1.15), 0.035, bind="head", depth=0.015)
    lm["animations"] = ["idle", "walk", "run", "sneak", "crouch", "hammer", "sit"]
    lm["hammer"] = R.ROOT / "assets" / "models" / "primitive_stone_hammer.glb"
    return lm


CHARACTERS = {"bearded": bearded, "plump": plump, "lanky": lanky, "helper": helper}


def assemble(kind: str) -> tuple[bpy.types.Object, dict]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = R.FPS
    P.MATERIALS.clear()
    spec = CHARACTERS[kind](mats())
    parts = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    mesh = bpy.context.view_layer.objects.active
    mesh.name = kind
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.set_sharpness_by_angle(angle=math.radians(50))
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.shade_smooth(keep_sharp_edges=True)
    return mesh, spec


def skin(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    """Bone heat for the skin, then the bound parts (hair, face, belt, sash) follow one bone, and a
    skirt hangs from the hips, its hem going half way with the thigh on its side."""
    binds = [g for g in mesh.vertex_groups if g.name.startswith("bind:")]
    R.skin(mesh, rig)
    for group in binds:
        bone = group.name.split(":", 1)[1]
        members = [v for v in mesh.data.vertices if any(g.group == group.index for g in v.groups)]
        for other in mesh.vertex_groups:
            if not other.name.startswith("bind:"):
                other.remove([v.index for v in members])
        if bone != "skirt":
            mesh.vertex_groups[bone].add([v.index for v in members], 1.0, "REPLACE")
            continue
        top, low = max(v.co.z for v in members), min(v.co.z for v in members)
        for v in members:
            t = (top - v.co.z) / (top - low)
            side = min(1.0, abs(v.co.x) / 0.08) * 0.55 * t
            mesh.vertex_groups["hips"].add([v.index], 1.0 - side, "REPLACE")
            if side > 0:
                mesh.vertex_groups["thigh_l" if v.co.x > 0 else "thigh_r"].add([v.index], side, "REPLACE")
    for group in binds:
        mesh.vertex_groups.remove(group)


def build(kind: str, preview_dir: Path | None) -> None:
    mesh, spec = assemble(kind)
    rig = R.build_skeleton(spec, Matrix())
    rig.name = kind
    skin(mesh, rig)
    OUT.mkdir(parents=True, exist_ok=True)
    R.OUT = OUT
    if kind != "helper":
        R.export_arm(mesh, rig, f"arm_{kind}")
    actions = [R.animate(rig, name, R.ANIMATIONS[name]()) for name in spec.get("animations", R.DEFAULT_ANIMATIONS)]
    if "hammer" in spec:
        R.add_hammer(rig, spec["hammer"])
        tool = bpy.data.objects["hammer"]
        tool.data.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))  # head in the plane of the swing (fix_helper_hammer.py)
        tool.data.materials.clear()  # the game swaps in the PEAK hammer mesh (trap_setter.gd): no textures
        tool.data.materials.append(P.material("hide", HIDE))
    rig.animation_data.action = actions[0]
    print(kind, "triangles:", sum(len(p.vertices) - 2 for p in mesh.data.polygons))
    if preview_dir:
        R.preview(rig, actions, preview_dir, kind)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{kind}.glb"), export_format="GLB", export_animation_mode="ACTIONS",
                              export_image_format="JPEG",
                              export_force_sampling=True, export_frame_step=1, use_selection=True)


def main() -> None:
    args = sys.argv[1:]
    preview_dir = Path(args[args.index("--preview") + 1]) if "--preview" in args else None
    kinds = list(CHARACTERS) if args[0] == "all" else [args[0]]
    for kind in kinds:
        build(kind, preview_dir)


if __name__ == "__main__":
    main()
