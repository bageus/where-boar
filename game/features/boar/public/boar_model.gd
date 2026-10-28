extends Node3D

## A boar type's rigged model (assets/models/boar_<id>.glb, tools/rig_boars.py) with its animations:
## idle, walk and run by speed, eat at bait, attack and death once.

const WALK_SPEED := 1.5  # ground speed the walk cycle was keyed for, m/s (ASSUMPTION)
const RUN_SPEED := 9.0
const RUN_FROM := 4.0

var _player: AnimationPlayer
var _dead := false


func show_type(boar_type: Resource) -> void:
	for child in get_children():
		child.free()
	var model: Node3D = boar_type.model.instantiate()
	add_child(model)
	_player = model.find_child("AnimationPlayer") as AnimationPlayer
	for anim in ["idle", "walk", "run", "eat"]:
		_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_dead = false
	_player.play("idle")


## Picks idle, walk or run for a ground speed and keeps the feet in step with it; eat when standing at food.
func move(speed: float, eating := false) -> void:
	if _dead or (_player.current_animation == "attack" and _player.is_playing()):
		return
	var anim := ("eat" if eating else "idle") if speed < 0.3 else ("walk" if speed < RUN_FROM else "run")
	_player.play(anim, 0.4 if anim == "eat" else 0.2)
	_player.speed_scale = 1.0 if anim == "idle" else speed / (WALK_SPEED if anim == "walk" else RUN_SPEED)


func attack() -> void:
	if not _dead:
		_player.speed_scale = 1.0
		_player.play("attack", 0.1)


## Rolls onto its side and stays there.
func die() -> void:
	_dead = true
	_player.speed_scale = 1.0
	_player.play("death", 0.1)


func player() -> AnimationPlayer:
	return _player


## Height of the model's highest point above its feet, metres.
func top() -> float:
	var height := 0.0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		height = maxf(height, mesh.get_aabb().end.y)
	return height
