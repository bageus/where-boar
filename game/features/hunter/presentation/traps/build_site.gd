extends RefCounted

## A trap goes down as a see-through ghost that does nothing until it is built (owner, 2026-10-28):
## the hunter holds E next to it, or the hired trap setter walks over and builds it.

const GHOST_TRANSPARENCY := 0.6


## Turns a freshly placed trap into a ghost that takes seconds of work to build.
static func make_ghost(trap: Node3D, seconds: float) -> void:
	trap.set_meta("build_seconds", seconds)
	trap.set_meta("build_progress", 0.0)
	_set_working(trap, false)


static func is_ghost(trap: Node3D) -> bool:
	return trap.has_meta("build_progress")


## Built share 0..1; 1 for a trap that is not a ghost.
static func progress(trap: Node3D) -> float:
	return trap.get_meta("build_progress", 1.0)


## Adds delta seconds of work; the trap starts working once done. True when this call finished it.
static func build(trap: Node3D, delta: float) -> bool:
	if not is_ghost(trap):
		return false
	var done := progress(trap) + delta / float(trap.get_meta("build_seconds"))
	if done < 1.0:
		trap.set_meta("build_progress", done)
		return false
	trap.remove_meta("build_progress")
	_set_working(trap, true)
	return true


## A ghost neither catches boars (Area3D) nor blocks them (the fence); its meshes are see-through.
static func _set_working(trap: Node3D, on: bool) -> void:
	if trap is Area3D:
		trap.set_deferred("monitoring", on)
	elif trap is CollisionObject3D:
		if not on:
			trap.set_meta("build_layer", trap.collision_layer)
		trap.collision_layer = trap.get_meta("build_layer", trap.collision_layer) if on else 0
	for mesh in trap.find_children("*", "GeometryInstance3D", true, false):
		mesh.transparency = 0.0 if on else GHOST_TRANSPARENCY
