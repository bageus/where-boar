extends RefCounted

## A trap goes down as a see-through ghost that does nothing until it is built (owner, 2026-10-28):
## the hunter holds E next to it, or the hired trap setter walks over and builds it.

const TrapPlacement = preload("res://game/features/hunter/presentation/trap_placement.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const GHOST_TRANSPARENCY := 0.6


## Turns a freshly placed trap into a ghost that takes seconds of work to build.
## reach: how far from the trap's middle its builders may stand, so any side will do.
static func make_ghost(trap: Node3D, seconds: float, reach: float) -> void:
	trap.set_meta("build_reach", reach)
	trap.set_meta("build_seconds", seconds)
	trap.set_meta("build_progress", 0.0)
	_set_working(trap, false)


## A tripwire whose second peg is still being placed ("laying") is not ready to build yet.
static func is_ghost(trap: Node3D) -> bool:
	return trap.has_meta("build_progress") and not trap.has_meta("laying")


## How far from the middle of a ghost the builder may stand.
static func reach(trap: Node3D) -> float:
	return trap.get_meta("build_reach", 0.0)


## Ground distance from point p to the edge of the trap's footprint (0 inside), from any side.
static func edge_distance(trap: Node3D, p: Vector3) -> float:
	var fp: Dictionary = TrapPlacement.FOOTPRINTS.get(trap.get_meta("item_id", ""), {})
	var local := trap.global_transform.affine_inverse() * p
	var size: Vector3 = fp.get("size", Vector3.ZERO)
	if fp.get("shape", "") == "box":
		var out := Vector2(maxf(absf(local.x) - size.x * 0.5, 0.0), maxf(absf(local.z) - size.z * 0.5, 0.0))
		return out.length()
	return maxf(Vector2(local.x, local.z).length() - size.x, 0.0)


## Built share 0..1; 1 for a trap that is not a ghost.
static func progress(trap: Node3D) -> float:
	return trap.get_meta("build_progress", 1.0)


## Adds delta seconds of work; the trap starts working once done. True when this call finished it.
## While anyone builds, building takes follow one another at the trap (owner, 2026-11-05: mixed and looped).
static func build(trap: Node3D, delta: float) -> bool:
	if not is_ghost(trap):
		return false
	if not (trap.has_meta("build_sound") and is_instance_valid(trap.get_meta("build_sound"))):
		trap.set_meta("build_sound", Sfx.play(trap, "building", -4.0, 25.0))
	var done := progress(trap) + delta / float(trap.get_meta("build_seconds"))
	if done < 1.0:
		trap.set_meta("build_progress", done)
		return false
	trap.remove_meta("build_progress")
	_set_working(trap, true)
	return true


## A ghost neither catches boars (Area3D) nor blocks them (fence, cage walls); its meshes are see-through
## except those marked "solid".
static func _set_working(trap: Node3D, on: bool) -> void:
	if trap is Area3D:
		trap.set_deferred("monitoring", on)
	var bodies := trap.find_children("*", "StaticBody3D", true, false)
	if trap is StaticBody3D:
		bodies.append(trap)
	for body: StaticBody3D in bodies:
		if not on:
			body.set_meta("build_layer", body.collision_layer)
		body.collision_layer = body.get_meta("build_layer", body.collision_layer) if on else 0
	for mesh: GeometryInstance3D in trap.find_children("*", "GeometryInstance3D", true, false):
		if not mesh.get_meta("solid", false):
			mesh.transparency = 0.0 if on else GHOST_TRANSPARENCY
