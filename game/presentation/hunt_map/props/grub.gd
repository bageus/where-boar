extends Node3D

## A grub crawling back and forth near where it was put (a stump, a log or a trunk): it walks along its own forward axis.

const SPEED := 0.05
const LEASH := 0.35

var anim: AnimationPlayer
var anim_name := ""
var home := Vector3.ZERO


func _ready() -> void:
	anim.play(anim_name)
	anim.seek(randf() * anim.current_animation_length)


func _process(delta: float) -> void:
	translate_object_local(Vector3(0.0, 0.0, -SPEED * delta))
	if position.distance_to(home) > LEASH:
		rotate_object_local(Vector3.UP, PI)
