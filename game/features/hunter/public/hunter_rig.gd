extends RefCounted

## The owner's rigged hunters (assets/models/hunter/*.glb, owner 2026-11-23) come without animations: this
## gives each instance an AnimationPlayer with idle, walk, run, sneak, ride, sit, attack (spear or net throw),
## strong_attack (two-handed smash), club_swing, club_heavy, thrust (spear or knife), spear_heavy and bow_shot,
## built from poses on their 24-bone rig (root, pelvis,
## spine, chest, neck, head, clavicle/upper_arm/forearm/hand/thumb.L|R, thigh/shin/foot/toe.L|R).
## Poses are rotations in the model's rest frame (+X the left hand, +Y up, +Z the front), each applied
## before the parent's: a bone's local rotation is parent_rest⁻¹ · pose · rest. Right side mirrors left.

const LOOPS: Array[String] = ["idle", "walk", "run", "sneak", "ride", "sit"]
const LOOSE_TIME := 34.0 / 30.0  # bow_shot: string released, as the cavemen's (tools/rig_cavemen.py)
const ARM_DOWN := -72.0  # T-pose arms lowered to the sides
## Heavy blows (owner, 2026-11-23): the swing's wind-up is held this long, as while the attack is charged.
const CHARGE_HOLD := 0.8
## Every weapon's attach point: the middle of the fist in either hand bone's space (both hunters' hand meshes
## centre there; the bone runs wrist -> fingers along +Y).
const PALM := Vector3(0.0, 0.15, 0.0)
## A held item's frame in the hand bone: its +Y out of the thumb side of the fist, its -X toward the fingers.
const FIST := {"L": Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK), "R": Basis(Vector3.DOWN, Vector3.LEFT, Vector3.FORWARD)}

## Model scene path -> its AnimationLibrary, shared by every instance.
static var _libraries := {}
## Source mesh -> its copy with the belly freed from the arms (see _free_belly).
static var _freed := {}
## Arm bones the Meshy auto-weights also gave the plump hunter's belly sides (spikes when an arm went up).
const ARM_BONES: Array[String] = ["clavicle", "upper_arm", "forearm", "hand", "thumb"]
const BELOW_ARM := 0.18  # m under the T-pose arm: no arm vertex is that low


## Height scale per model file (owner, 2026-11-23): the raw models stand 2.37 (prehistoric), 2.44 (lanky), 2.46 (plump)
## and 2.53 m (young). Wanted: prehistoric 2.37, lanky half a head taller (2.54), plump a little shorter (2.32),
## young a head (0.35 m) below plump (1.97).
const HEIGHT_SCALE := {"lanky_hunter": 1.04, "plump_hunter": 0.943, "young_hunter": 0.78}


static func instance(scene: PackedScene) -> Node3D:
	var model: Node3D = scene.instantiate()
	model.scale = Vector3.ONE * HEIGHT_SCALE.get(scene.resource_path.get_file().get_basename(), 1.0)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D")
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)  # root_node ".." is the model
	player.owner = model  # find_child() only finds owned nodes
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.mesh = _free_belly(mesh, skeleton)
	if not _libraries.has(scene.resource_path):
		_libraries[scene.resource_path] = _build(skeleton, String(model.get_path_to(skeleton)))
	player.add_animation_library("", _libraries[scene.resource_path])
	return model


## Puts item in the fist of hand bone ("hand.R", "hand_l"...): grip is where the fist closes on it in the
## item's own frame, turn the item's rotation and scale in the fist.
static func hold(skeleton: Skeleton3D, bone: String, item: Node3D, grip := Vector3.ZERO, turn := Basis.IDENTITY) -> BoneAttachment3D:
	var socket := BoneAttachment3D.new()
	socket.bone_name = bone
	skeleton.add_child(socket)
	var basis: Basis = FIST["R" if bone.to_upper().ends_with("R") else "L"] * turn
	item.transform = Transform3D(basis, PALM - basis * grip)
	socket.add_child(item)
	return socket


## Vertices well below the T-pose arms lose their arm weights to the chest: raising an arm then no longer
## pulls the belly out after it.
static func _free_belly(mi: MeshInstance3D, skeleton: Skeleton3D) -> Mesh:
	var mesh := mi.mesh as ArrayMesh
	if mesh == null or mi.skin == null:
		return mi.mesh
	if _freed.has(mesh):
		return _freed[mesh]
	var shoulder := skeleton.get_bone_global_rest(skeleton.find_bone("upper_arm.L")).origin.y
	var chest := -1
	var arm := {}
	for bind in mi.skin.get_bind_count():
		var bone_name := String(mi.skin.get_bind_name(bind))
		if bone_name == "chest":
			chest = bind
		if bone_name.get_basename() in ARM_BONES:
			arm[bind] = true
	var freed := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		@warning_ignore("integer_division")
		var per := bones.size() / vertices.size()
		for v in vertices.size():
			if chest < 0 or (mi.transform * vertices[v]).y > shoulder - BELOW_ARM:
				continue
			for k in per:
				if arm.has(bones[v * per + k]):
					bones[v * per + k] = chest
		arrays[Mesh.ARRAY_BONES] = bones
		freed.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {},
				mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		freed.surface_set_material(s, mesh.surface_get_material(s))
	_freed[mesh] = freed
	return freed


static func _build(skeleton: Skeleton3D, path: String) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var sit_drop := skeleton.get_bone_global_rest(skeleton.find_bone("thigh.L")).origin.y \
			- skeleton.get_bone_global_rest(skeleton.find_bone("shin.L")).origin.y
	var clips := {
		"idle": [3.0, [[0.0, _stand()], [1.5, _stand({"chest": rx(3.0), "head": rx(-2.0)})], [3.0, _stand()]]],
		"walk": [1.1, _gait(1.1, 25.0, 35.0, 20.0, 15.0, 0.03, 3.0, 0.0, 0.0, 5.0)],
		"run": [0.65, _gait(0.65, 45.0, 75.0, 40.0, 80.0, 0.06, 12.0, -0.03, -8.0, 10.0)],
		"sneak": [1.3, _gait(1.3, 18.0, 25.0, 10.0, 40.0, 0.02, 25.0, -0.16, -45.0, 70.0)],
		"ride": [0.8, _ride()],
		"sit": [4.0, _sit(sit_drop)],
		"attack": [1.0, _throw()],
		"strong_attack": [1.2, _smash()],
		"bow_shot": [1.6, _bow()],
		"club_swing": [1.0, _club()],
		"club_heavy": [1.0 + CHARGE_HOLD, _held(_club(), 1)],
		"thrust": [0.9, _thrust()],
		"spear_heavy": [1.0 + CHARGE_HOLD, _held(_spear_swing(), 1)],
	}
	for clip: String in clips:
		library.add_animation(clip, _clip(skeleton, path, clips[clip][0], clips[clip][1], clip in LOOPS))
	return library


static func rx(degrees: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, deg_to_rad(degrees))


static func ry(degrees: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(degrees))


static func rz(degrees: float) -> Quaternion:
	return Quaternion(Vector3.BACK, deg_to_rad(degrees))


## The right side's rotation for a left side one: mirrored across the body's middle plane.
static func mirror(q: Quaternion) -> Quaternion:
	return Quaternion(q.x, -q.y, -q.z, q.w)


## Arms down, elbows a little bent; extra overrides bones (".L" entries also set ".R" mirrored unless given).
static func _stand(extra := {}) -> Dictionary:
	var pose := {"upper_arm.L": rz(ARM_DOWN), "forearm.L": ry(-12.0)}
	pose.merge(extra, true)
	for bone: String in pose.keys():
		if bone.ends_with(".L") and not pose.has(bone.trim_suffix(".L") + ".R"):
			pose[bone.trim_suffix(".L") + ".R"] = mirror(pose[bone])
	return pose


## A walking cycle as 8 keys: legs swing by swing degrees, knees bend while a leg swings forward, arms
## swing against the legs; lean bends the spine forward, crouch lowers the pelvis (m), thigh/knee are the
## base bends (sneak).
static func _gait(length: float, swing: float, knee: float, arm: float, elbow: float, bob: float,
		lean: float, crouch: float, thigh: float, base_knee: float) -> Array:
	var keys := []
	for i in 9:
		var phase := TAU * i / 8.0
		var s := sin(phase)
		var c := cos(phase)
		keys.append([length * i / 8.0, {
			"thigh.L": rx(thigh - swing * s), "thigh.R": rx(thigh + swing * s),
			"shin.L": rx(base_knee + knee * maxf(0.0, c)), "shin.R": rx(base_knee + knee * maxf(0.0, -c)),
			"foot.L": rx(-base_knee * 0.5), "foot.R": rx(-base_knee * 0.5),
			"upper_arm.L": rx(arm * s) * rz(ARM_DOWN), "upper_arm.R": rx(-arm * s) * mirror(rz(ARM_DOWN)),
			"forearm.L": ry(-elbow), "forearm.R": ry(elbow),
			"spine": rx(lean * 0.6), "chest": rx(lean * 0.4) * ry(arm * 0.15 * s),
			"pelvis": crouch - bob * (1.0 - cos(phase * 2.0)) * 0.5,
		}])
	return keys


## Astride a boar: legs forward and apart, hands forward on the bristles, rocking with the gallop.
static func _ride() -> Array:
	var keys := []
	for i in 3:
		var dip := 0.03 if i == 1 else 0.0
		keys.append([0.4 * i, _stand({
			"thigh.L": rx(-70.0) * rz(25.0), "shin.L": rx(85.0),
			"upper_arm.L": rx(-50.0 - dip * 200.0) * rz(ARM_DOWN), "forearm.L": ry(-35.0),
			"spine": rx(15.0 + dip * 100.0), "pelvis": -dip,
		})])
	return keys


## On a bench at a table: thighs level, shins down, upper arms raised and out, elbows on the table, now and then looking about.
static func _sit(drop: float) -> Array:
	var base := {"thigh.L": rx(-88.0), "shin.L": rx(88.0), "upper_arm.L": rx(-45.0) * rz(-50.0),
			"forearm.L": ry(-60.0), "spine": rx(6.0), "pelvis": -drop}
	var keys := []
	for k: Array in [[0.0, 0.0, 0.0], [1.2, 3.0, 25.0], [2.4, 0.0, -20.0], [4.0, 0.0, 0.0]]:
		var pose := base.duplicate()
		pose["chest"] = rx(k[1])
		pose["head"] = ry(k[2])
		keys.append([k[0], _stand(pose)])
	return keys


## Spear thrown with the right hand: wound up over the shoulder, hurled forward, follow-through.
static func _throw() -> Array:
	return [
		[0.0, _stand()],
		[0.35, _stand({"upper_arm.R": rx(-30.0) * rz(-60.0), "forearm.R": ry(70.0),
				"upper_arm.L": rx(-50.0) * rz(ARM_DOWN + 30.0), "chest": ry(-25.0), "spine": rx(-8.0)})],
		# Arms wide of the body: the plump hunter's belly swallowed them close in.
		[0.55, _stand({"upper_arm.R": rx(-80.0) * rz(-ARM_DOWN - 30.0), "forearm.R": ry(5.0),
				"upper_arm.L": rx(-20.0) * rz(ARM_DOWN + 15.0), "chest": ry(10.0), "spine": rx(15.0)})],
		[0.8, _stand({"upper_arm.R": rx(-45.0) * rz(-ARM_DOWN - 30.0), "forearm.R": ry(10.0), "chest": ry(5.0), "spine": rx(18.0)})],
		[1.0, _stand()],
	]


## Two-handed smash: both arms up over the head, then down in front, bending forward.
static func _smash() -> Array:
	return [
		[0.0, _stand()],
		# Up through the sides and kept wide over the head: straight up, the arms went through head and belly.
		[0.2, _stand({"upper_arm.L": rx(-10.0) * rz(-5.0), "forearm.L": ry(-10.0), "spine": rx(-5.0)})],
		[0.45, _stand({"upper_arm.L": rx(-30.0) * rz(55.0), "forearm.L": ry(-20.0), "spine": rx(-12.0)})],
		[0.7, _stand({"upper_arm.L": rx(-75.0) * rz(-40.0), "forearm.L": ry(-10.0), "spine": rx(30.0),
				"pelvis": -0.08, "thigh.L": rx(-15.0), "shin.L": rx(25.0)})],
		[0.95, _stand({"upper_arm.L": rx(-70.0) * rz(-40.0), "forearm.L": ry(-10.0), "spine": rx(28.0),
				"pelvis": -0.08, "thigh.L": rx(-15.0), "shin.L": rx(25.0)})],
		[1.2, _stand()],
	]


## Bow arm straight out in front, bow upright; the right fist draws the string back to the cheek with the
## arrow running on from it, and lets go at LOOSE_TIME. Arm rotations solved for the fist's place and the
## weapon's direction (tools/solve_arm_poses.py), so they are quaternions, not angles.
static func _bow() -> Array:
	var aim := {"upper_arm.L": Quaternion(0.514, 0.636, 0.454, -0.353), "forearm.L": Quaternion(0.000, 0.000, 0.000, 1.000), "hand.L": Quaternion(-0.002, 0.084, 0.095, 0.992), "chest": ry(-20.0), "head": ry(20.0)}
	var nock := aim.duplicate()
	nock.merge({"upper_arm.R": Quaternion(0.279, -0.685, -0.652, -0.167), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(0.001, -0.014, 0.009, 1.000)}, true)
	var drawn := aim.duplicate()
	drawn.merge({"upper_arm.R": Quaternion(0.305, -0.746, -0.591, 0.028), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(-0.002, -0.167, -0.152, 0.974)}, true)
	var loose := aim.duplicate()
	loose.merge({"upper_arm.R": Quaternion(0.391, -0.768, -0.480, 0.165), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(0.001, -0.357, -0.226, 0.906)}, true)
	return [
		[0.0, _stand()], [0.3, _stand(nock)], [0.55, _stand(nock)], [1.0, _stand(drawn)],
		[LOOSE_TIME - 0.03, _stand(drawn)], [LOOSE_TIME + 0.05, _stand(loose)], [1.4, _stand(loose)],
		[1.6, _stand()],
	]


## Club in the right hand: raised up and back over the shoulder, club pointing back, then brought down hard
## in front.
static func _club() -> Array:
	var raised := {"upper_arm.R": Quaternion(0.580, -0.792, -0.183, 0.056), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(0.002, -0.113, -0.041, 0.993), "chest": ry(-20.0), "spine": rx(-8.0)}
	var struck := {"upper_arm.R": Quaternion(0.581, 0.043, -0.803, 0.124), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(0.012, -0.439, -0.096, 0.893), "chest": ry(15.0), "spine": rx(18.0), "pelvis": -0.04}
	return [[0.0, _stand()], [0.35, _stand(raised)], [0.5, _stand(struck)], [0.75, _stand(struck)], [1.0, _stand()]]


## Spear or knife in the right hand, held low: drawn back by the hip, then jabbed straight forward.
static func _thrust() -> Array:
	var low := {"upper_arm.R": Quaternion(-0.022, 0.208, 0.873, 0.440), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(-0.029, -0.225, -0.657, 0.719)}
	var jab := {"upper_arm.R": Quaternion(0.554, -0.219, -0.771, -0.226), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(0.009, -0.245, -0.008, 0.969), "chest": ry(10.0), "spine": rx(12.0)}
	return [[0.0, _stand()], [0.2, _stand(low)], [0.4, _stand(jab)], [0.6, _stand(jab)], [0.9, _stand()]]


## Charged spear: gripped at the middle, raised over the shoulder with the point forward, then driven down
## and forward like the heavy club blow.
static func _spear_swing() -> Array:
	var raised := {"upper_arm.R": Quaternion(-0.020, 0.251, -0.793, 0.554), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(0.000, -0.085, -0.057, 0.995), "chest": ry(-20.0), "spine": rx(-6.0)}
	var struck := {"upper_arm.R": Quaternion(0.512, 0.102, -0.827, 0.210), "forearm.R": Quaternion(0.000, -0.000, 0.000, 1.000), "hand.R": Quaternion(0.008, -0.355, -0.109, 0.928), "chest": ry(15.0), "spine": rx(18.0), "pelvis": -0.04}
	return [[0.0, _stand()], [0.35, _stand(raised)], [0.5, _stand(struck)], [0.75, _stand(struck)], [1.0, _stand()]]


## keys with key index held for CHARGE_HOLD: the later keys move that much later.
static func _held(keys: Array, index: int) -> Array:
	var held := keys.slice(0, index + 1)
	for key: Array in keys.slice(index):
		held.append([key[0] + CHARGE_HOLD, key[1]])
	return held


## One clip from [time, pose] keys; a bone missing from a key is at rest then, "pelvis" is its drop (m).
static func _clip(skeleton: Skeleton3D, path: String, length: float, keys: Array, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var bones := {}
	for key: Array in keys:
		for bone: String in key[1]:
			bones[bone] = true
	for bone: String in bones:
		var b := skeleton.find_bone(bone)
		var track := anim.add_track(Animation.TYPE_POSITION_3D if bone == "pelvis" else Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("%s:%s" % [path, bone]))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		var rest := skeleton.get_bone_global_rest(b).basis.get_rotation_quaternion()
		var parent := skeleton.get_bone_parent(b)
		var parent_rest := skeleton.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		for key: Array in keys:
			if bone == "pelvis":
				anim.position_track_insert_key(track, key[0], skeleton.get_bone_rest(b).origin + Vector3(0.0, key[1].get(bone, 0.0), 0.0))
			else:
				anim.rotation_track_insert_key(track, key[0], (parent_rest.inverse() * key[1].get(bone, Quaternion.IDENTITY) * rest).normalized())
	return anim
