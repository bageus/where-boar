extends Node3D

## A rooster or turkey from the owner's static thin models, given idle, walk, run and peck by moving the
## whole body (no skeleton). The scene faces -Z like the other models and has an "AnimationPlayer".

## The owner's glb; its beak points along +X (rooster) or +Z (turkey).
@export var source: PackedScene
## Turn about Y that brings the beak to -Z, degrees.
@export var yaw := 0.0
@export var model_scale := 0.7

var _player := AnimationPlayer.new()


func _ready() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	var mesh: Node3D = source.instantiate()
	mesh.rotation_degrees.y = yaw
	mesh.scale = Vector3.ONE * model_scale
	body.add_child(mesh)
	_player.name = "AnimationPlayer"
	add_child(_player)
	_player.owner = self  # find_child("AnimationPlayer") only sees owned nodes
	var library := AnimationLibrary.new()
	#             name    secs  bounces  roll    lean  (peck: dips)
	library.add_animation("idle", _cycle(2.0, 1, 0.01, 0.02, 0.0))
	library.add_animation("walk", _cycle(1.0, 2, 0.03, 0.10, -0.05))
	library.add_animation("run", _cycle(0.5, 2, 0.06, 0.15, -0.25))
	library.add_animation("peck", _peck(1.2))
	_player.add_animation_library("", library)


## Body hops `bounces` times and rolls side to side once per cycle; `lean` pitches it (negative = beak down).
func _cycle(secs: float, bounces: int, hop: float, roll: float, lean: float) -> Animation:
	var anim := _new(secs)
	var hops := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(hops, "Body:position:y")
	for i in bounces * 2 + 1:
		anim.track_insert_key(hops, secs * i / (bounces * 2.0), hop if i % 2 == 1 else 0.0)
	_keys(anim, "Body:rotation:z", secs, [0.0, roll, 0.0, -roll, 0.0])
	_keys(anim, "Body:rotation:x", secs, [lean, lean, lean, lean, lean])
	return anim


## Beak to the ground twice.
func _peck(secs: float) -> Animation:
	var anim := _new(secs)
	_keys(anim, "Body:rotation:x", secs, [0.0, -0.9, 0.0, -0.9, 0.0])
	return anim


func _new(secs: float) -> Animation:
	var anim := Animation.new()
	anim.length = secs
	anim.loop_mode = Animation.LOOP_LINEAR
	return anim


## Evenly spaced keys from 0 to the full length, the last equal to the first for a clean loop.
func _keys(anim: Animation, path: String, secs: float, values: Array) -> void:
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, path)
	for i in values.size():
		anim.track_insert_key(track, secs * i / (values.size() - 1), values[i])
