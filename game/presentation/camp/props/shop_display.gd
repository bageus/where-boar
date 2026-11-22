extends Node3D

## The traps on show by the hunting hut: the game's own trap models, purely decorative (no collision, no
## trigger logic). The new stalls carry their own goods (owner's models, 2026-11-22), so nothing stands on
## the counters any more.

const TRAPS := "res://assets/models/peak_traps/"
## Traps around the hunting hut, in camp (world) coordinates so they clear the tents, the tavern and each
## other: [file, x, z, yaw, scale]. East and south of the hut, nowhere near the way from the campfire.
const TRAP_SPOTS := [
	["pit", 20.5, -0.5, 0.0, 0.6], ["snare", 20.0, 6.5, 0.3, 1.0], ["fence", 20.3, 3.0, PI / 2, 0.8],
	["tripwire", 17.0, 6.0, PI / 2, 1.0], ["cage", 20.3, 9.5, 0.0, 0.7],
]
## The strip they stand in, kept free of rim rocks (scenery.gd) and of plants (dressing.gd): x, z, width, depth.
const TRAP_ZONE := Rect2(16.3, -2.0, 5.4, 12.8)


func _ready() -> void:
	for t: Array in TRAP_SPOTS:
		_put(TRAPS + t[0] + ".tscn", to_local(Vector3(t[1], 0.0, t[2])), Vector3(0.0, t[3] - global_rotation.y, 0.0), t[4])


func _put(path: String, at: Vector3, euler: Vector3, scale_by := 1.0) -> Node3D:
	var model: Node3D = load(path).instantiate()
	add_child(model)
	model.position = at
	model.rotation = euler
	model.scale = Vector3.ONE * scale_by
	return model
