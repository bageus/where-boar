extends Node3D

## Rooster summoned from the camp pen (M016): flies to the far side of a herd and crows,
## driving those boars straight at the hunter.

const FLY_SPEED := 12.0
## ASSUMPTION (D013).
const CROW_RADIUS := 12.0

## Injected: where to land and the boar nodes that may hear the crow (each has driven_from).
var target := Vector3.ZERO
var boars: Array[Node] = []


func _physics_process(delta: float) -> void:
	global_position = global_position.move_toward(target, FLY_SPEED * delta)
	if global_position.distance_to(target) > 0.1:
		return
	for boar in boars:
		if is_instance_valid(boar) and boar.global_position.distance_to(target) <= CROW_RADIUS:
			boar.driven_from(target)
	queue_free()
