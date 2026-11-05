extends RefCounted

## A running boar crashes into a tree, stump, log, fence or cage, another boar or the ridden boar (owner, 2026-11-05):
## a dull thud, and both the boar and what it hit shake a little.
## Trees, stumps and logs drawn as MultiMesh copies carry meta "shake" = [MultiMesh, instance index] on their body
## or collision shape (hunt map); a placed trap (group "placed_traps") shakes whole; rocks, cliffs and walls do not.

const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## Tilt of a shaken object, radians, and how long it shakes, seconds.
const TILT := 0.05
const SECONDS := 0.45
const BOAR_TILT := 0.12
const TRAPS_GROUP := "placed_traps"


## The boar ran into a wall-like hit; thuds and shakes only when it is something that shakes. True if it was.
static func into_object(boar: Node3D, hit: KinematicCollision3D) -> bool:
	var collider := hit.get_collider() as Node
	var shape := hit.get_collider_shape() as Node
	var away := -hit.get_normal()
	if shape and shape.has_meta("shake"):
		_shake_copy(collider, shape.get_meta("shake"), away)
	elif collider.has_meta("shake"):
		_shake_copy(collider, collider.get_meta("shake"), away)
	else:
		var trap: Node = collider if collider.is_in_group(TRAPS_GROUP) else collider.get_parent()
		if not (trap is Node3D and trap.is_in_group(TRAPS_GROUP)):
			return false
		_shake_node(trap, away)
	thud(boar, null)
	return true


## The boar knocked into another boar or the hunter (on foot or riding): thud, and both boars shake.
static func thud(boar: Node3D, other: Object) -> void:
	Sfx.play(boar, "bump", 0.0, 30.0)
	_shake_model(boar)
	if other is Node3D and other.has_node("Model"):
		_shake_model(other)


static func _shake_model(body: Node3D) -> void:
	var model := body.get_node_or_null("Model") as Node3D
	if model == null:
		return
	var tween := model.create_tween()
	tween.tween_property(model, "rotation:x", BOAR_TILT, SECONDS * 0.2)
	tween.tween_property(model, "rotation:x", -BOAR_TILT * 0.5, SECONDS * 0.3)
	tween.tween_property(model, "rotation:x", 0.0, SECONDS * 0.5)


## Rocks one MultiMesh copy about its base, away from the boar; data gains the copy's rest transform on first use.
static func _shake_copy(owner: Node, data: Array, away: Vector3) -> void:
	var multimesh: MultiMesh = data[0]
	var index: int = data[1]
	if data.size() == 2:
		data.append(multimesh.get_instance_transform(index))
	var rest: Transform3D = data[2]
	var axis := Vector3.UP.cross(Vector3(away.x, 0.0, away.z)).normalized()
	if axis == Vector3.ZERO:
		return
	owner.create_tween().tween_method(func(t: float) -> void:
		multimesh.set_instance_transform(index, Transform3D(Basis(axis, _wave(t) * TILT) * rest.basis, rest.origin)),
		0.0, 1.0, SECONDS)


static func _shake_node(node: Node3D, away: Vector3) -> void:
	if not node.has_meta("shake_rest"):
		node.set_meta("shake_rest", node.basis)
	var rest: Basis = node.get_meta("shake_rest")
	var axis := Vector3.UP.cross(Vector3(away.x, 0.0, away.z)).normalized()
	if axis == Vector3.ZERO:
		return
	node.create_tween().tween_method(func(t: float) -> void: node.basis = Basis(axis, _wave(t) * TILT) * rest, 0.0, 1.0, SECONDS)


## A shake that dies out: 0 at both ends, three swings in between.
static func _wave(t: float) -> float:
	return sin(t * TAU * 1.5) * (1.0 - t)
