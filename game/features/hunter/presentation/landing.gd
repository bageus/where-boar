extends RefCounted

## Where a thrown spear, arrow or net ends up (owner, 2026-10-27): a miss lies where it landed;
## a hit stays stuck in the boar, to be taken back once the boar is dead or caught.

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")


## Stops item and, when body is a boar or its hitbox, sticks it into that boar (item.holder).
static func land(item: RigidBody3D, body: Node) -> void:
	item.set_deferred("freeze", true)
	item.set_deferred("collision_layer", 0)
	item.set_deferred("collision_mask", 0)
	var boar: Node = body if body is BoarBody else body.get_parent()
	if boar is BoarBody:
		item.holder = boar
		_stick.call_deferred(item, boar)


static func _stick(item: RigidBody3D, boar: Node3D) -> void:
	if not is_instance_valid(item) or not is_instance_valid(boar):
		return
	item.reparent(boar)
	item.top_level = false


## A thrown item can be taken back unless it is stuck in a boar that is still running.
static func can_pick(item: RigidBody3D) -> bool:
	var holder: Node3D = item.holder
	return holder == null or not is_instance_valid(holder) or not holder.boar.is_free()
