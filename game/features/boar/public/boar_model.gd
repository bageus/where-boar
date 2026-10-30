extends Node3D

## A boar type's rigged model (assets/models/boar_<id>.glb, tools/rig_boars.py) with its animations:
## idle, walk and run by speed, eat at bait, attack and death once.

const WALK_SPEED := 1.5  # ground speed the walk cycle was keyed for, m/s (ASSUMPTION)
const RUN_SPEED := 9.0
const RUN_FROM := 4.0

const Saddle = preload("res://assets/models/saddle.glb")
const SADDLE_WIDTH := 0.8  # boar width the saddle was modelled for, m
const SADDLE_PAD := 0.3  # saddle height of the underside of its pad

var _player: AnimationPlayer
var _dead := false
var _dust: CPUParticles3D
var _flash := StandardMaterial3D.new()


func show_type(boar_type: Resource) -> void:
	for child in get_children():
		child.free()
	var model: Node3D = boar_type.model.instantiate()
	add_child(model)
	_player = model.find_child("AnimationPlayer") as AnimationPlayer
	for anim in ["idle", "walk", "run", "eat"]:
		_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_add_net_fall()
	_add_dust()
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


## A few tan low-poly cubes kicked up behind the feet while running; local space off, so they stay where they fell.
func _add_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 8
	_dust.lifetime = 0.5
	_dust.local_coords = false
	_dust.emitting = false
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
	var pose := {"spine_0": -8.0, "spine_1": -10.0, "chest": -12.0, "neck": -28.0, "head": -10.0}
	for leg in ["fl", "fr"]:
		pose["leg_" + leg] = 40.0
		pose["shin_" + leg] = -95.0
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


## Straps the saddle (assets/models/saddle.glb) on the middle of the back, scaled to the boar's width; it follows the spine bone.
func put_saddle() -> void:
	var skeleton: Skeleton3D = find_children("*", "Skeleton3D", true, false)[0]
	var bone := skeleton.find_bone("spine_1")
	var box := AABB()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		box = box.merge(mesh.get_aabb()) if box.has_volume() else mesh.get_aabb()
	var fit := clampf(box.size.x / SADDLE_WIDTH, 0.7, 1.2)
	# Saddle front is +Z, the boar's is -Z. The y is a guess at the back below ears and bristles.
	var on_back := Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * fit),
			Vector3(0.0, top() * 0.85 - SADDLE_PAD * fit, box.get_center().z - 0.05))
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "spine_1"
	skeleton.add_child(attachment)
	var rest := global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(bone)
	var saddle: Node3D = Saddle.instantiate()
	attachment.add_child(saddle)
	saddle.transform = rest.affine_inverse() * on_back
