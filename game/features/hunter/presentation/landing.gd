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
	elif item.has_node("Collision") and item.get_node("Collision").shape is CapsuleShape3D:
		_stick_in_ground.call_deferred(item)


## A missile that hit a tree, rock or the ground: finds the ground below it and stands in it, tip down, never in the air
## (owner, 2026-11-01). Stays where it is when no ground is found.
static func _stick_in_ground(item: RigidBody3D) -> void:
	if not is_instance_valid(item) or not item.is_inside_tree():
		return
	var from := item.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, 1)
	query.exclude = [item.get_rid()]
	var hit := item.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var forward := -item.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var down := (forward * 0.5 + Vector3.DOWN * 0.866).normalized()  # 60 degrees into the ground
	var shape: CapsuleShape3D = item.get_node("Collision").shape
	var up := Vector3.UP if absf(down.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	item.global_basis = Basis.looking_at(down, up)
	# A quarter of its length is buried.
	item.global_position = hit.position - down * (shape.height * 0.5 - shape.height * 0.25)


static func _stick(item: RigidBody3D, boar: Node3D) -> void:
	if not is_instance_valid(item) or not is_instance_valid(boar):
		return
	item.reparent(boar)
	item.top_level = false


## A thrown item can be taken back unless it is stuck in a boar that is still running.
static func can_pick(item: RigidBody3D) -> bool:
	var holder: Node3D = item.holder
	return holder == null or not is_instance_valid(holder) or not holder.boar.is_free()
