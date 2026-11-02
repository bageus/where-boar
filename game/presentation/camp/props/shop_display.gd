extends Node3D

## The goods on show at a camp shop: the game's own weapon, bait and trap models, purely decorative (no
## collision, no trigger logic). A child of the shop's station, so everything is in the stall's local space
## (front +z, counter at y 1.1). The traps stand beside and behind the hunting hut, off the walking paths.

enum Kind { WEAPONS, BAITS }

const WEAPONS := "res://assets/models/peak_weapons/"
const FRUIT := "res://assets/models/peak_fruit/"
const TRAPS := "res://assets/models/peak_traps/"
const COUNTER_Y := 1.1
## Baits as bait.gd lists them, two rows on the counter: [file, x, z].
const BAITS := [
	["01_acorns", -1.3, 0.36], ["02_red_berries", -0.45, 0.36], ["03_blueberries", 0.4, 0.36], ["04_apple", 1.25, 0.36],
	["05_pear", -1.4, 0.66], ["06_bananas", -0.7, 0.66], ["07_mandarin", 0.0, 0.66], ["08_mango", 0.7, 0.66],
	["09_mixed_berries", 1.4, 0.66],
]
## Traps around the hunting hut: [file, x, z, yaw, scale].
const TRAP_SPOTS := [
	["pit", -3.8, 2.6, 0.0, 0.6], ["snare", -5.2, 0.6, 0.4, 1.0], ["tripwire", 4.6, 2.4, 0.2, 1.0],
	["cage", 5.0, -0.4, 0.5, 0.7], ["fence", -0.6, -2.8, 0.0, 0.8],
]

@export var kind := Kind.WEAPONS


func _ready() -> void:
	if kind == Kind.WEAPONS:
		_weapons()
	else:
		_baits()
		for t: Array in TRAP_SPOTS:
			_put(TRAPS + t[0] + ".tscn", Vector3(t[1], 0.0, t[2]), Vector3(0.0, t[3], 0.0), t[4])


func _weapons() -> void:
	# Three spears in the rack to the right of the counter, leaning back a little.
	for x in [2.3, 2.48, 2.66]:
		_put(WEAPONS + "spear.tscn", Vector3(x, 1.0, 0.18), Vector3(-0.08, 0.0, 0.0))
	# A bow hung on the back wall, bending towards the viewer.
	_put(WEAPONS + "bow.tscn", Vector3(0.0, 1.9, -0.8), Vector3(0.0, PI / 2, 0.0), 1.2)
	# On the counter: a club, a knife, a sling, a heap of stones, arrows.
	_put(WEAPONS + "club.tscn", Vector3(-1.1, COUNTER_Y + 0.1, 0.5), Vector3(PI / 2, 0.0, 1.2))
	_put(WEAPONS + "knife.tscn", Vector3(-0.35, COUNTER_Y + 0.03, 0.55), Vector3(PI / 2, 0.0, 0.5), 1.5)
	_put(WEAPONS + "sling.tscn", Vector3(0.25, COUNTER_Y + 0.03, 0.45), Vector3(PI / 2, 0.0, 0.0), 1.5)
	for i in 3:
		_put(WEAPONS + "stone.tscn", Vector3(0.75 + i * 0.16, COUNTER_Y, 0.5 + (i % 2) * 0.1), Vector3(0.0, i * 1.3, 0.0), 1.2)
	for i in 3:
		_put(WEAPONS + "arrow.tscn", Vector3(1.2 + i * 0.1, COUNTER_Y + 0.03, 0.5), Vector3(PI / 2, 0.0, 1.45 + i * 0.1))


func _baits() -> void:
	for b: Array in BAITS:
		var model := _put(FRUIT + b[0] + ".tscn", Vector3(b[1], COUNTER_Y, b[2]), Vector3.ZERO, 1.0)
		# The colours live in vertex colours (as bait.gd does for the bait on the ground).
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D"):
			var paint := StandardMaterial3D.new()
			paint.vertex_color_use_as_albedo = true
			paint.roughness = 0.82
			mesh.material_override = paint


func _put(path: String, at: Vector3, euler: Vector3, scale_by := 1.0) -> Node3D:
	var model: Node3D = load(path).instantiate()
	add_child(model)
	model.position = at
	model.rotation = euler
	model.scale = Vector3.ONE * scale_by
	return model
