extends RefCounted

## Where a thrown spear, arrow or net ends up (owner, 2026-10-27): a miss lies where it landed;
## a hit stays stuck in the boar, to be taken back once the boar is dead or caught.

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")

## How far a missile that hit a boar is pushed into it, in metres.
const STICK_DEPTH := 0.45
## A pointed missile's tip goes this far under the surface it hit, in metres.
const TIP_DEPTH := 0.18
## The boar's flesh as a capsule around its body (the hitbox is wider): half the straight part, radius, centre height.
const FLESH_HALF := 0.4
const FLESH_RADIUS := 0.52
const FLESH_Y := 0.5


## Stops item and, when body is a boar or its hitbox, sticks it into that boar (item.holder).
## velocity is the item's velocity just before the hit (the engine has already bounced it by now).
static func land(item: RigidBody3D, body: Node, velocity := Vector3.ZERO) -> void:
	item.set_deferred("freeze", true)
	item.set_deferred("collision_layer", 0)
	item.set_deferred("collision_mask", 0)
	var boar: Node = body if body is BoarBody else body.get_parent()
	if boar is BoarBody:
		item.holder = boar
		_stick.call_deferred(item, boar, velocity)
	elif item.has_node("Collision") and item.get_node("Collision").shape is CapsuleShape3D:
		_stick_in_ground.call_deferred(item, velocity)


## A missile that hit a tree, rock or the ground: finds the ground below it and stands in it, tip down, never in the air
## (owner, 2026-11-01). Stays where it is when no ground is found.
static func _stick_in_ground(item: RigidBody3D, velocity: Vector3) -> void:
	if not is_instance_valid(item) or not item.is_inside_tree():
		return
	var shape: CapsuleShape3D = item.get_node("Collision").shape
	# Hit a rock or cliff head on: the tip stays in the very spot it struck, along the flight line (owner, 2026-11-02).
	if velocity.length() > 1.0:
		var dir := velocity.normalized()
		var rq := PhysicsRayQueryParameters3D.create(item.global_position - dir * 0.5, item.global_position + dir * 1.2, 1)
		rq.exclude = [item.get_rid()]
		var rhit := item.get_world_3d().direct_space_state.intersect_ray(rq)
		if not rhit.is_empty():
			var up0 := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			item.global_basis = Basis.looking_at(dir, up0)
			item.global_position = rhit.position + dir * (shape.height * 0.25 - shape.height * 0.5)
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
	var up := Vector3.UP if absf(down.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	item.global_basis = Basis.looking_at(down, up)
	# A quarter of its length is buried.
	item.global_position = hit.position - down * (shape.height * 0.5 - shape.height * 0.25)


static func _stick(item: RigidBody3D, boar: Node3D, velocity: Vector3) -> void:
	if not is_instance_valid(item) or not is_instance_valid(boar):
		return
	var capsule := item.has_node("Collision") and item.get_node("Collision").shape is CapsuleShape3D
	var hit := _flesh_hit(item.global_position, velocity, boar) if capsule else {}
	if not hit.is_empty():
		# The tip sits just under the skin where the flight line meets the body (owner, 2026-11-02).
		var dir: Vector3 = hit.dir
		var half: float = item.get_node("Collision").shape.height * 0.5
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		item.global_basis = Basis.looking_at(dir, up)
		item.global_position = hit.point + dir * (TIP_DEPTH - half)
	else:
		# Line missed the flesh (the hitbox is wider) or is unknown: the tip goes just under the skin nearest the item, pointing inward (owner, 2026-11-07).
		var local := boar.to_local(item.global_position)
		var axis := Geometry3D.get_closest_point_to_segment(local, Vector3(0.0, FLESH_Y, -FLESH_HALF), Vector3(0.0, FLESH_Y, FLESH_HALF))
		var out := (local - axis).normalized() if local.distance_to(axis) > 0.01 else Vector3.UP
		var dir_in: Vector3 = -(boar.global_basis * out).normalized()
		var tip := boar.to_global(axis + out * (FLESH_RADIUS - TIP_DEPTH))
		var up_in := Vector3.UP if absf(dir_in.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		item.global_basis = Basis.looking_at(dir_in, up_in)
		var half_len := item.get_node("Collision").shape.height * 0.5 if capsule else 0.0
		item.global_position = tip - dir_in * half_len
	item.reparent(boar)
	item.top_level = false


## Where the line from point along velocity first enters the boar's body capsule (world coordinates), or {}.
static func _flesh_hit(point: Vector3, velocity: Vector3, boar: Node3D) -> Dictionary:
	if velocity.length() < 1.0:
		return {}
	var dir := velocity.normalized()
	var a := boar.to_local(point - dir * 1.2)
	var d := boar.global_basis.inverse() * dir
	var axis_a := Vector3(0.0, FLESH_Y, -FLESH_HALF)
	var axis_b := Vector3(0.0, FLESH_Y, FLESH_HALF)
	for i in 120:  # 2 cm steps along 2.4 m
		var p := a + d * (0.02 * i)
		var q := Geometry3D.get_closest_point_to_segment(p, axis_a, axis_b)
		if p.distance_to(q) <= FLESH_RADIUS:
			return {"point": boar.to_global(p), "dir": dir}
	return {}


## A thrown item can be taken back unless it is stuck in a boar that is still running.
static func can_pick(item: RigidBody3D) -> bool:
	var holder: Node3D = item.holder
	return holder == null or not is_instance_valid(holder) or not holder.boar.is_free()
