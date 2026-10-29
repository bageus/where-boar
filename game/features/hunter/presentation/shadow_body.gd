extends Node3D

## The hunter's body, seen only through its shadow (owner, 2026-10-29: the hunter cast no shadow on
## the buildings): a caveman that never renders but casts a shadow, playing idle, walk, run, sneak or
## ride to match its parent hunter. Child of the hunter; reads its parent.

const Caveman = preload("res://assets/models/caveman_skinny.glb")
const RUN_SPEED := 5.0  # between the hunter's walk and sprint speeds
const MOVING_SPEED := 0.3

var _player: AnimationPlayer

@onready var _hunter: CharacterBody3D = get_parent()


func _ready() -> void:
	var body: Node3D = Caveman.instantiate()
	body.rotation.y = PI  # the model faces +z, the hunter looks along -z
	add_child(body)
	for mesh: GeometryInstance3D in body.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_player = body.find_child("AnimationPlayer") as AnimationPlayer
	_player.animation_finished.connect(func(anim: StringName) -> void: _player.play(anim))


func _process(_delta: float) -> void:
	var speed := Vector2(_hunter.velocity.x, _hunter.velocity.z).length()
	var anim := "idle"
	if _hunter.ride.is_riding():
		anim = "ride"
	elif speed > MOVING_SPEED:
		anim = "sneak" if _hunter.crouching else ("run" if speed > RUN_SPEED else "walk")
	if _player.current_animation != anim:
		_player.play(anim, 0.2)
