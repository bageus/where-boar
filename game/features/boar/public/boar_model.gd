extends Node3D

## A boar type's rigged model (assets/models/boar/boar_<id>.glb, tools/rig_boars.py, or the owner's
## assets/models/boar_new/*.glb, see _adopt) with its animations: idle, walk and run by speed, eat at bait,
## attack and death once.

const WALK_SPEED := 1.5  # ground speed the walk cycle was keyed for, m/s (ASSUMPTION)
const RUN_SPEED := 9.0
const RUN_FROM := 4.0

const Saddle = preload("res://assets/models/weapon_new/boar_saddle.glb")
const HeadIdle = preload("res://game/features/boar/presentation/boar_head_idle.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
## Seconds between chomps while eating (owner, 2026-11-05: chomping, takes in turn).
const CHOMP_SECONDS := Vector2(0.9, 1.6)
const SADDLE_LENGTH := 1.9  # boar length the saddle was modelled for (common boar), m
const SADDLE_HEIGHT := 1.1  # and its height, m
const SADDLE_SCALE := 0.6  # the saddle was 40% too big (owner, 2026-11-23)
const SADDLE_SINK := 0.1  # pressed into the back, in saddle-size units: it sat too high
const SADDLE_PAD := 0.03  # saddle height of the underside of its pad (boar_saddle.glb: pad bottom at 0.016)
## The owner's boar_new clips (the importer drops "_loop") under this file's names; the first one found wins.
const NEW_CLIPS := {
	"walk": ["Walk"], "run": ["Run"], "eat": ["Eat"], "attack": ["Tusk_attack"],
	"death": ["Death_left", "Death_side"],
}
## Back bone the saddle rides on: blocky boars, then boar_new rigs.
const BACK_BONES: Array[String] = ["spine_1", "Body", "Chest"]

var _player: AnimationPlayer
var _back_height := 0.85
var _dead := false
var _dust: CPUParticles3D
var _head_idle: SkeletonModifier3D
var _flash := StandardMaterial3D.new()
var _next_chomp := 0
## Source mesh -> its one-surface copy (see _one_surface), shared by every boar of the type.
static var _merged := {}


func show_type(boar_type: Resource) -> void:
	for child in get_children():
		child.free()
	_back_height = boar_type.back_height
	var model: Node3D = boar_type.model.instantiate()
	add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.mesh = _one_surface(mesh.mesh)
	_player = model.find_child("AnimationPlayer") as AnimationPlayer
	_adopt(_player.get_animation_library(""))
	for anim in ["idle", "walk", "run", "eat"]:
		_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_add_net_fall()
	_add_dust()
	_head_idle = HeadIdle.new()
	_player.get_parent().find_child("Skeleton3D").add_child(_head_idle)
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dead = false
	_player.play("idle")


## Picks idle, walk or run for a ground speed and keeps the feet in step with it; eat when standing at food.
func move(speed: float, eating := false) -> void:
	if _dead or (_player.current_animation == "attack" and _player.is_playing()):
		return
	var anim := ("eat" if eating else "idle") if speed < 0.3 else ("walk" if speed < RUN_FROM else "run")
	_player.play(anim, 0.4 if anim == "eat" else 0.2)
	_player.speed_scale = 1.0 if anim == "idle" else speed / (WALK_SPEED if anim == "walk" else RUN_SPEED)
	_dust.emitting = anim == "run"
	_head_idle.active = anim == "idle"
	if anim == "eat" and Time.get_ticks_msec() >= _next_chomp:
		_next_chomp = Time.get_ticks_msec() + roundi(randf_range(CHOMP_SECONDS.x, CHOMP_SECONDS.y) * 1000.0)
		Sfx.play(self, "chomping", -6.0, 15.0)


## boar_new models name their clips differently and have no idle: their clips are renamed once per
## (shared) library, and idle is the walk's first frame held.
static func _adopt(library: AnimationLibrary) -> void:
	if library.has_animation("idle"):
		return
	for anim: String in NEW_CLIPS:
		for clip: String in NEW_CLIPS[anim]:
			if library.has_animation(clip) and not library.has_animation(anim):
				library.rename_animation(clip, anim)
	var idle: Animation = library.get_animation("walk").duplicate()
	for track in idle.get_track_count():
		for key in range(idle.track_get_key_count(track) - 1, 0, -1):
			idle.track_remove_key(track, key)
	idle.length = 1.0
	library.add_animation("idle", idle)


## Whole model flashes white and fades back (hurt).
func flash() -> void:
	_flash.albedo_color = Color.WHITE
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _flash
	var tween := create_tween()
	tween.tween_property(_flash, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			mesh.material_overlay = null)


## Beauty hut paint (issue #18): every material under root multiplied by colour (copies, so shared
## materials stay as they are). Used for the painted mount and, in camp, the painted hut.
static func tint(root: Node, color: Color) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i)
			if material is BaseMaterial3D:
				var painted: BaseMaterial3D = material.duplicate()
				painted.albedo_color = color
				mesh.set_surface_override_material(i, painted)


## A mesh in flat colours, one material per colour (the blocky boar: six), as one surface with the colours in
## its vertices: one draw call per boar instead of six, 47 boars on the map (owner, 2026-11-07: 8 FPS on the hunt).
## Meshes with textures or materials differing in more than colour are kept as they are.
static func _one_surface(mesh: Mesh) -> Mesh:
	if not mesh is ArrayMesh or mesh.get_surface_count() < 2:
		return mesh
	if _merged.has(mesh):
		return _merged[mesh]
	var first := mesh.surface_get_material(0) as StandardMaterial3D
	var merged: Array = []
	merged.resize(Mesh.ARRAY_MAX)
	for s in mesh.get_surface_count():
		var material := mesh.surface_get_material(s) as StandardMaterial3D
		if material == null or material.albedo_texture or material.vertex_color_use_as_albedo \
				or material.roughness != first.roughness or material.metallic != first.metallic or material.cull_mode != first.cull_mode \
				or mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES or mesh.surface_get_format(s) != mesh.surface_get_format(0):
			return mesh
		var arrays := mesh.surface_get_arrays(s)
		var count: int = arrays[Mesh.ARRAY_VERTEX].size()
		var colours := PackedColorArray()
		colours.resize(count)
		colours.fill(material.albedo_color)
		arrays[Mesh.ARRAY_COLOR] = colours
		if arrays[Mesh.ARRAY_INDEX] != null and merged[Mesh.ARRAY_VERTEX] != null:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var offset: int = merged[Mesh.ARRAY_VERTEX].size()
			for i in indices.size():
				indices[i] += offset
			arrays[Mesh.ARRAY_INDEX] = indices
		for k in Mesh.ARRAY_MAX:
			if arrays[k] != null:
				merged[k] = arrays[k] if merged[k] == null else merged[k] + arrays[k]
	var one := ArrayMesh.new()
	one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged, [], {}, mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	var material := first.duplicate() as StandardMaterial3D
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true  # albedo colours are sRGB
	one.surface_set_material(0, material)
	_merged[mesh] = one
	return one


## A few tan low-poly cubes kicked up behind the feet while running; local space off, so they stay where they fell.
func _add_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 8
	_dust.lifetime = 0.5
	_dust.local_coords = false
	_dust.emitting = false
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dust.visibility_range_end = 40.0  # 47 boars on the map: one draw call each otherwise
	_dust.position = Vector3(0.0, 0.1, 0.4)
	_dust.direction = Vector3(0.0, 1.0, 0.5)
	_dust.spread = 30.0
	_dust.initial_velocity_min = 0.5
	_dust.initial_velocity_max = 1.2
	_dust.gravity = Vector3(0.0, -1.0, 0.0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.0
	_dust.scale_amount_curve = Curve.new()
	_dust.scale_amount_curve.add_point(Vector2(0.0, 1.0))
	_dust.scale_amount_curve.add_point(Vector2(1.0, 0.0))
	var puff := BoxMesh.new()
	puff.size = Vector3.ONE * 0.25
	puff.material = StandardMaterial3D.new()
	puff.material.albedo_color = Color(0.82, 0.72, 0.55)
	puff.material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust.mesh = puff
	add_child(_dust)


func attack() -> void:
	if not _dead:
		_head_idle.active = false
		_player.speed_scale = 1.0
		_player.play("attack", 0.1)


## Rolls onto its side and stays there.
func die() -> void:
	_dead = true
	_player.speed_scale = 1.0
	_player.play("death", 0.1)


## Caught in a net: falls forward onto the chest and front legs and stays there.
func net_fall() -> void:
	_dead = true
	_player.speed_scale = 1.0
	_player.play("net", 0.1)


## Gets up again when the net is shaken off (a held boar breaking free).
func stand() -> void:
	_dead = false
	_player.play("idle", 0.3)


## "net" is built here, not in the .glb: the sources are not in the repo, so tools/rig_boars.py cannot
## re-export them. Poses are armature-space rotations as in rig_boars.py, mapped to Godot axes.
func _add_net_fall() -> void:
	var library := _player.get_animation_library("")
	if library.has_animation("net"):
		return
	var skeleton := _player.get_parent().find_child("Skeleton3D") as Skeleton3D
	var anim := Animation.new()
	anim.length = 1.2
	var pose := {"spine_0": -8.0, "spine_1": -10.0, "chest": -12.0, "neck": -28.0, "head": -10.0,
			"Body": -10.0, "Chest": -12.0, "Head": -20.0}
	for leg in ["fl", "fr"]:
		pose["leg_" + leg] = 40.0
		pose["shin_" + leg] = -95.0
	for leg in ["Front_L_", "Front_R_", "Fore_L_", "Fore_R_"]:  # boar_new front legs
		pose[leg + "Upper"] = 40.0
		pose[leg + "Lower"] = -95.0
	for bone in pose:
		var i := skeleton.find_bone(bone)
		if i < 0:
			continue
		var rest := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		var global := skeleton.get_bone_global_rest(i).basis.get_rotation_quaternion()
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("%s:%s" % [_player.get_node(_player.root_node).get_path_to(skeleton), bone]))
		var fallen := rest * (global.inverse() * Quaternion(Vector3.RIGHT, deg_to_rad(pose[bone])) * global)
		anim.rotation_track_insert_key(track, 0.0, rest)
		anim.rotation_track_insert_key(track, 0.35, rest.slerp(fallen, 0.3))  # knees buckle first
		anim.rotation_track_insert_key(track, 0.8, fallen)
		anim.rotation_track_insert_key(track, 1.2, fallen)
	library.add_animation("net", anim)


func player() -> AnimationPlayer:
	return _player


## Height of the model's highest point above its feet, metres.
func top() -> float:
	var height := 0.0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		height = maxf(height, mesh.get_aabb().end.y)
	return height


## Straps the saddle (assets/models/weapon_new/boar_saddle.glb) on the middle of the back, scaled to the boar's length and height (the smaller ratio, so small and low boars get a small saddle); it follows the spine bone.
func put_saddle() -> void:
	var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
	var back: String = BACK_BONES.filter(func(b: String) -> bool: return skeleton.find_bone(b) >= 0)[0]
	var bone := skeleton.find_bone(back)
	var box := AABB()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		box = box.merge(mesh.get_aabb()) if box.has_volume() else mesh.get_aabb()
	var fit := clampf(minf(box.size.z / SADDLE_LENGTH, top() / SADDLE_HEIGHT), 0.4, 1.3) * SADDLE_SCALE
	# Saddle front is +Z, the boar's is -Z. The back is a share of the top, below ears and bristles (BoarType.back_height).
	var on_back := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * fit),
			Vector3(0.0, top() * _back_height - (SADDLE_PAD + SADDLE_SINK) * fit, box.get_center().z - 0.05))
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = back
	skeleton.add_child(attachment)
	var rest := global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(bone)
	var saddle: Node3D = Saddle.instantiate()
	attachment.add_child(saddle)
	saddle.transform = rest.affine_inverse() * on_back
