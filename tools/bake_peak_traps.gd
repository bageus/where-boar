extends SceneTree

## Bakes the traps and the bait fruit in the style of the game PEAK (owner, 2026-11-02), to match the rocks, trees,
## buildings and weapons (bake_peak_*.gd). Our own procedural shapes, nothing taken from that game: chunky
## prisms and faceted lumps, flat shaded, one surface per part with bright vertex colours.
## Traps keep the node layout of the old glb files (TrapRoot/Static, SnareLoop, PitWalls, PitFloor, PitCover_nn,
## CageGate, TriggerPlate, AnimationPlayer with the same animation names), so trap.gd, build_site.gd and the
## placement preview work unchanged. Tripwire: all the rope lies between x = -0.9 and 0.9 and the pegs outside
## x = +-0.45, which is what Trap.stretch_to() relies on.
## Run: godot --headless --path . -s res://tools/bake_peak_traps.gd

const PeakSmooth := preload("res://tools/peak_smooth.gd")
const OUT := "res://assets/models/peak_traps/"
const FRUIT_OUT := "res://assets/models/peak_fruit/"
const WOOD := Color(0.8, 0.5, 0.24)
const WOOD_DARK := Color(0.6, 0.35, 0.16)
const WOOD_LIGHT := Color(0.92, 0.66, 0.36)
const ROPE := Color(0.93, 0.78, 0.45)
const WRAP := Color(0.86, 0.24, 0.18)
const LEAF := Color(0.42, 0.78, 0.22)
const LEAF_DARK := Color(0.26, 0.58, 0.18)
const LEAF_LIGHT := Color(0.62, 0.86, 0.3)
const OLIVE := Color(0.62, 0.66, 0.2)
const EARTH := Color(0.78, 0.5, 0.26)
const EARTH_DARK := Color(0.5, 0.3, 0.16)
const EARTH_DEEP := Color(0.36, 0.21, 0.12)
const STONE := Color(0.6, 0.6, 0.62)
const STONE_LIGHT := Color(0.76, 0.75, 0.72)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(FRUIT_OUT)
	_snare()
	_pit()
	_fence()
	_cage()
	_tripline()
	_fruits()
	quit()


# ---------------------------------------------------------------- traps

func _snare() -> void:
	var stat := _tool()
	# A bent sapling pegged at the back, its tip holding the rope that leads to the loop.
	var anchor := Vector3(0.05, 0.0, 0.0)
	var pts: Array[Vector3] = [Vector3(0.85, 0, -0.85), Vector3(0.88, 0.34, -0.84), Vector3(0.74, 0.64, -0.68),
		Vector3(0.5, 0.78, -0.45), Vector3(0.24, 0.76, -0.2)]
	_chain(stat, pts, 0.075, 0.03, 6, WOOD)
	_lump(stat, Vector3(0.85, 0.04, -0.85), Vector3(0.3, 0.07, 0.3), EARTH_DARK, EARTH, 3)
	_prism(stat, Vector3(0.7, 0.0, -0.82), Vector3(0.7, 0.3, -0.82), 0.05, 0.04, 5, WOOD_DARK)  # peg
	_prism(stat, Vector3(0.62, 0.22, -0.82), Vector3(0.78, 0.26, -0.82), 0.02, 0.02, 4, ROPE)
	_prism(stat, pts[4], anchor + Vector3(0, 0.08, 0), 0.016, 0.014, 4, ROPE)  # leash
	_prism(stat, anchor, anchor + Vector3(0, 0.22, 0), 0.045, 0.035, 5, WOOD_DARK)  # anchor stake
	_prism(stat, anchor + Vector3(0, 0.05, 0), anchor + Vector3(0, 0.12, 0), 0.052, 0.052, 5, WRAP)
	for p in [Vector3(0.6, 0.76, -0.55), Vector3(0.35, 0.82, -0.3)]:
		_lump(stat, p, Vector3(0.12, 0.07, 0.1), LEAF_DARK, LEAF_LIGHT, 11)
	_stone(stat, Vector3(1.1, 0, -0.35), 0.11, 4)
	_stone(stat, Vector3(-0.2, 0, -0.55), 0.08, 5)
	_scatter_leaves(stat, Vector3(-0.4, 0.0, 0.42), 0.62, 7, 21)
	# The loop lies flat; its pivot is the knot at the leash, so it tightens towards the knot.
	var loop := _tool()
	var centre := Vector3(-0.45, 0.0, 0.42)
	var ring: Array[Vector3] = []
	for k in 11:
		var a := TAU * k / 11.0
		ring.append(centre + Vector3(cos(a), 0, sin(a)) * 0.62)
	for k in ring.size():
		_prism(loop, ring[k], ring[(k + 1) % ring.size()], 0.05, 0.05, 5, ROPE)
	_lump(loop, Vector3.ZERO + Vector3(0, 0.0, 0), Vector3(0.07, 0.06, 0.07), WRAP, WRAP, 9)
	var player := _player()
	var close := Animation.new()
	close.length = 1.35
	_scale_key(close, "TrapRoot/SnareLoop", [[0.0, Vector3.ONE], [0.3, Vector3.ONE], [1.0, Vector3(0.3, 1, 0.3)], [1.35, Vector3(0.24, 1, 0.24)]])
	_add(player, "Snare_Close", close)
	var reset := Animation.new()
	reset.length = 0.8
	_scale_key(reset, "TrapRoot/SnareLoop", [[0.0, Vector3(0.24, 1, 0.24)], [0.8, Vector3.ONE]])
	_add(player, "Snare_Reset", reset)
	_save_trap("snare", [["Static", stat, Vector3.ZERO], ["SnareLoop", loop, anchor + Vector3(0, 0.045, 0)]], player)


func _tripline() -> void:
	var t := _tool()
	for side in [-1.0, 1.0]:
		var x: float = 0.9 * side
		_prism(t, Vector3(x, 0, 0), Vector3(x, 0.55, 0), 0.06, 0.05, 5, WOOD)
		_prism(t, Vector3(x, 0.5, 0), Vector3(x, 0.58, 0), 0.05, 0.03, 5, WOOD_DARK)
		_prism(t, Vector3(x, 0.24, 0), Vector3(x, 0.38, 0), 0.075, 0.075, 5, WRAP)
		_stone(t, Vector3(x, 0, 0.14), 0.1, 6 if side < 0 else 7)
		_lump(t, Vector3(x + 0.1 * side, 0.06, -0.12), Vector3(0.09, 0.06, 0.09), LEAF_DARK, LEAF_LIGHT, 8)
	# The rope is cut at x = +-0.45 so it stretches there and nowhere else.
	var xs: Array[float] = [-0.9, -0.45, 0.45, 0.9]
	for n in 3:
		_prism(t, Vector3(xs[n], 0.31, 0), Vector3(xs[n + 1], 0.31, 0), 0.026, 0.026, 5, ROPE)
	_save_trap("tripwire", [["Static", t, Vector3.ZERO]], null)


func _fence() -> void:
	var t := _tool()
	# Four pointed posts, three rails and stakes leaning out of the front, all lashed with red wraps.
	for i in 5:
		var x := -2.0 + i
		_prism(t, Vector3(x, 0, 0.2), Vector3(x, 1.25, 0.2), 0.1, 0.085, 6, WOOD_DARK if i % 2 == 0 else WOOD)
		_prism(t, Vector3(x, 1.25, 0.2), Vector3(x, 1.5, 0.2), 0.085, 0.01, 6, WOOD_LIGHT)
	for y in [0.35, 0.7, 1.05]:
		_prism(t, Vector3(-2.05, y, 0.42), Vector3(2.05, y, 0.42), 0.07, 0.07, 6, WOOD)
		for i in 5:
			_prism(t, Vector3(-2.0 + i, y - 0.06, 0.42), Vector3(-2.0 + i, y + 0.06, 0.42), 0.095, 0.095, 6, WRAP)
	for i in 4:
		var x := -1.5 + i
		_prism(t, Vector3(x, 0.05, 0.42), Vector3(x + 0.1, 1.0, 0.95), 0.06, 0.04, 5, WOOD_LIGHT)
		_prism(t, Vector3(x + 0.1, 1.0, 0.95), Vector3(x + 0.12, 1.12, 1.05), 0.04, 0.008, 5, WOOD_DARK)
	_stone(t, Vector3(-1.5, 0, 0.0), 0.12, 12)
	_stone(t, Vector3(0.5, 0, -0.1), 0.1, 13)
	_stone(t, Vector3(1.7, 0, 0.05), 0.13, 14)
	_scatter_leaves(t, Vector3(0, 0, 0.1), 1.9, 5, 15)
	_save_trap("fence", [["Static", t, Vector3.ZERO]], null)


func _pit() -> void:
	var rim := _tool()
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	# A raised earth collar around the opening, with stones and tufts.
	_ring_slab(rim, 1.3, 1.95, 0.0, 0.16, 12, EARTH, EARTH_DARK)
	for k in 10:
		var a := TAU * (k + rng.randf() * 0.5) / 10.0
		var r := 1.5 + rng.randf() * 0.3
		_stone(rim, Vector3(cos(a), 0, sin(a)) * r + Vector3(0, 0.1, 0), 0.1 + rng.randf() * 0.08, 40 + k)
	_scatter_leaves(rim, Vector3.ZERO, 1.85, 8, 44)
	var walls := _tool()  # the funnel is dug into the ground: three earth layers going down
	var layers: Array = [[0.0, 1.35, EARTH_DARK], [-0.35, 1.25, EARTH_DEEP], [-0.7, 1.12, EARTH_DARK]]
	for n in layers.size():
		var top: Array = layers[n]
		var next_y := -1.0 if n == layers.size() - 1 else float(layers[n + 1][0])
		var next_r := 1.0 if n == layers.size() - 1 else float(layers[n + 1][1])
		_funnel(walls, float(top[0]), float(top[1]), next_y, next_r, 12, top[2], n)
	var floor_part := _tool()
	_disc(floor_part, Vector3(0, -1.0, 0), 1.0, 12, EARTH_DEEP, true)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		_lump(floor_part, Vector3(cos(a), -0.98, sin(a)) * 0.55, Vector3(0.12, 0.05, 0.1), EARTH_DARK, EARTH, 50 + k)
	var parts: Array = [["PitWalls", walls, Vector3.ZERO], ["PitFloor", floor_part, Vector3.ZERO], ["Static", rim, Vector3.ZERO]]
	var player := _player()
	var anim := Animation.new()
	anim.length = 1.05
	var sectors := 8
	for k in sectors:
		var theta := TAU * k / sectors
		var home := Vector3(cos(theta), 0.0, sin(theta)) * 0.8 + Vector3(0, 0.14, 0)
		var cover := _tool()
		_wedge(cover, theta, TAU / sectors * 0.5, home, k)
		var part_name := "PitCover_%02d" % k
		parts.append([part_name, cover, home])
		var tangent := Vector3(-sin(theta), 0, cos(theta))
		var tilt := Quaternion(tangent, deg_to_rad(55.0 if k % 2 == 0 else -70.0))
		var path := "TrapRoot/" + part_name
		var pos_track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(pos_track, path)
		var rot_track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track, path)
		for key in [[0.0, 0.0], [0.15, 0.0], [0.4, 0.15], [0.7, 0.55], [1.05, 1.0]]:
			var f: float = key[1]
			var drop := Vector3(-home.x * 0.45 * f, -1.0 * f * f, -home.z * 0.45 * f)
			anim.position_track_insert_key(pos_track, key[0], home + drop + (Vector3.UP * 0.04 if f == 0.0 and key[0] > 0.0 else Vector3.ZERO))
			anim.rotation_track_insert_key(rot_track, key[0], Quaternion.IDENTITY.slerp(tilt, minf(f * 1.4, 1.0)))
	_add(player, "Pit_Break", anim)
	_save_trap("pit", parts, player)


func _cage() -> void:
	var t := _tool()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Floor boards, wall logs, roof logs under a camouflage of leaves, a rail above the front for the gate.
	for i in 6:
		var x := -0.95 + i * 0.38
		_box(t, Vector3(x, 0.04, 0), Vector3(0.17, 0.035, 1.1), WOOD_LIGHT if i % 2 == 0 else WOOD)
	var corners: Array[Vector3] = [Vector3(-1.15, 0, -1.1), Vector3(1.15, 0, -1.1), Vector3(-1.15, 0, 1.1), Vector3(1.15, 0, 1.1)]
	for c in corners:
		var top := 2.5 if c.z > 0 else 1.85
		_prism(t, c, c + Vector3(0, top, 0), 0.11, 0.1, 6, WOOD_DARK)
		_prism(t, c + Vector3(0, top - 0.02, 0), c + Vector3(0, top + 0.1, 0), 0.1, 0.05, 6, WOOD_LIGHT)
	for n in 5:
		var y := 0.2 + n * 0.34
		var col := WOOD if n % 2 == 0 else WOOD_LIGHT
		_prism(t, Vector3(-1.15, y, -1.1), Vector3(-1.15, y, 1.1), 0.065, 0.065, 6, col)
		_prism(t, Vector3(1.15, y, -1.1), Vector3(1.15, y, 1.1), 0.065, 0.065, 6, col)
		_prism(t, Vector3(-1.15, y, -1.1), Vector3(1.15, y, -1.1), 0.065, 0.065, 6, col)
	for i in 5:
		var z := -0.9 + i * 0.45
		_prism(t, Vector3(-1.2, 1.78, z), Vector3(1.2, 1.78, z), 0.075, 0.075, 6, WOOD_DARK if i % 2 == 0 else WOOD)
	_prism(t, Vector3(-1.2, 2.45, 1.1), Vector3(1.2, 2.45, 1.1), 0.09, 0.09, 6, WOOD)  # gate rail
	for p in [Vector3(-1.15, 2.36, 1.1), Vector3(1.15, 2.36, 1.1), Vector3(0, 2.36, 1.1)]:
		_prism(t, p, p + Vector3(0, 0.2, 0), 0.105, 0.105, 6, WRAP)
	for k in 9:  # leaf camouflage on the roof and hanging at the sides
		var p := Vector3(rng.randf_range(-1.1, 1.1), 1.92 + rng.randf() * 0.12, rng.randf_range(-1.0, 1.0))
		_lump(t, p, Vector3(0.32, 0.12, 0.26), LEAF_DARK, LEAF_LIGHT if k % 2 == 0 else OLIVE, 60 + k)
	for k in 4:
		var side := -1.0 if k % 2 == 0 else 1.0
		_lump(t, Vector3(1.22 * side, 1.35 - k * 0.12, -0.7 + k * 0.4), Vector3(0.1, 0.22, 0.2), LEAF_DARK, LEAF, 80 + k)
	_stone(t, Vector3(-1.5, 0, 0.5), 0.12, 90)
	_stone(t, Vector3(1.55, 0, -0.4), 0.14, 91)
	_scatter_leaves(t, Vector3(0, 0, 1.6), 1.1, 5, 92)
	# The gate hangs up under the rail: sharpened stakes between two cross logs; it falls to the ground.
	var gate := _tool()
	for i in 8:
		var x := -0.98 + i * 0.28
		_prism(gate, Vector3(x, 1.3, 1.1), Vector3(x, 2.35, 1.1), 0.07, 0.07, 5, WOOD if i % 2 == 0 else WOOD_LIGHT)
		_prism(gate, Vector3(x, 1.3, 1.1), Vector3(x, 1.12, 1.1), 0.07, 0.01, 5, WOOD_DARK)
	for y in [1.5, 2.15]:
		_prism(gate, Vector3(-1.1, y, 1.2), Vector3(1.1, y, 1.2), 0.065, 0.065, 6, WOOD_DARK)
		for i in 2:
			_prism(gate, Vector3(-0.9 + i * 1.8, y - 0.06, 1.2), Vector3(-0.9 + i * 1.8, y + 0.06, 1.2), 0.09, 0.09, 6, WRAP)
	var plate := _tool()
	_box(plate, Vector3.ZERO, Vector3(0.37, 0.03, 0.32), WOOD_LIGHT)
	_box(plate, Vector3(0, 0.035, 0), Vector3(0.38, 0.012, 0.07), WRAP)
	var plate_home := Vector3(0, 0.1, -0.05)
	var player := _player()
	var close := Animation.new()
	close.length = 0.86
	var gate_track := close.add_track(Animation.TYPE_POSITION_3D)
	close.track_set_path(gate_track, "TrapRoot/CageGate")
	for key in [[0.0, 0.0], [0.2, -0.05], [0.4, -0.9], [0.52, -1.28], [0.64, -1.14], [0.86, -1.28]]:
		close.position_track_insert_key(gate_track, key[0], Vector3(0, key[1], 0))
	_plate_keys(close, plate_home, 0.2)
	_add(player, "Cage_Close", close)
	var reopen := Animation.new()
	reopen.length = 0.85
	var up_track := reopen.add_track(Animation.TYPE_POSITION_3D)
	reopen.track_set_path(up_track, "TrapRoot/CageGate")
	reopen.position_track_insert_key(up_track, 0.0, Vector3(0, -1.28, 0))
	reopen.position_track_insert_key(up_track, 0.85, Vector3.ZERO)
	_plate_keys(reopen, plate_home, 0.0)
	_add(player, "Cage_Open", reopen)
	_save_trap("cage", [["Static", t, Vector3.ZERO], ["CageGate", gate, Vector3.ZERO], ["TriggerPlate", plate, plate_home]], player)


func _plate_keys(anim: Animation, home: Vector3, pressed: float) -> void:
	var pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos, "TrapRoot/TriggerPlate")
	anim.position_track_insert_key(pos, 0.0, home)
	anim.position_track_insert_key(pos, anim.length * 0.3, home - Vector3(0, pressed * 0.2, 0))
	var rot := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(rot, "TrapRoot/TriggerPlate")
	anim.rotation_track_insert_key(rot, 0.0, Quaternion.IDENTITY)
	anim.rotation_track_insert_key(rot, anim.length * 0.3, Quaternion(Vector3.RIGHT, -pressed * 0.8))


# ---------------------------------------------------------------- fruit

## Fruit lie on the ground with the bottom at y = 0, about 0.3 m across (bait.gd scales them by 1.5).
func _fruits() -> void:
	var acorns := _tool()
	for k in 3:
		var at := Vector3([-0.1, 0.1, 0.0][k], 0.0, [0.04, 0.06, -0.12][k])
		var lie := k == 2
		var tilt := Basis(Vector3(0, 0, 1), deg_to_rad(80)) if lie else Basis()
		var up := Vector3(0, 1, 0) if not lie else Vector3(-1, 0, 0)
		var base_y := 0.06 if not lie else 0.055
		_lump(acorns, at + Vector3(0, base_y, 0), Vector3(0.05, 0.065, 0.05), Color(0.78, 0.5, 0.22), Color(0.92, 0.7, 0.34), 100 + k, tilt)
		_lump(acorns, at + Vector3(0, base_y, 0) + up * 0.05, Vector3(0.058, 0.032, 0.058), Color(0.4, 0.24, 0.12), Color(0.55, 0.34, 0.16), 110 + k, tilt)
		_prism(acorns, at + Vector3(0, base_y, 0) + up * 0.07, at + Vector3(0, base_y, 0) + up * 0.105, 0.012, 0.009, 4, WOOD_DARK)
	_leaf(acorns, Vector3(0.0, 0.01, 0.0), Vector3(0.14, 0.02, 0.16), 0.045, LEAF_DARK, Vector3.UP)
	_save_fruit("01_acorns", acorns)

	_save_fruit("02_red_berries", _berries([Color(0.78, 0.08, 0.12), Color(0.98, 0.3, 0.3)], 120))
	_save_fruit("03_blueberries", _berries([Color(0.22, 0.28, 0.72), Color(0.5, 0.58, 0.95)], 130))

	var apple := _tool()
	_lump(apple, Vector3(0, 0.125, 0), Vector3(0.145, 0.125, 0.145), Color(0.72, 0.06, 0.08), Color(1.0, 0.36, 0.28), 140)
	_prism(apple, Vector3(0, 0.22, 0), Vector3(0.01, 0.31, 0), 0.016, 0.012, 5, WOOD_DARK)
	_leaf(apple, Vector3(0.012, 0.28, 0), Vector3(0.14, 0.3, 0.02), 0.045, LEAF, Vector3.UP)
	_save_fruit("04_apple", apple)

	var pear := _tool()
	_lump(pear, Vector3(0, 0.12, 0), Vector3(0.125, 0.12, 0.125), Color(0.74, 0.72, 0.12), Color(0.95, 0.92, 0.35), 150)
	_lump(pear, Vector3(0, 0.27, 0), Vector3(0.075, 0.085, 0.075), Color(0.78, 0.78, 0.16), Color(0.98, 0.94, 0.4), 151)
	_prism(pear, Vector3(0, 0.34, 0), Vector3(0.02, 0.43, 0), 0.015, 0.011, 5, WOOD_DARK)
	_leaf(pear, Vector3(0.02, 0.41, 0), Vector3(0.15, 0.44, 0.03), 0.04, LEAF, Vector3.UP)
	_save_fruit("05_pear", pear)

	var bananas := _tool()
	for k in 3:
		var yaw := deg_to_rad([-26.0, 0.0, 26.0][k])
		var y := 0.048 if k != 1 else 0.115
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var perp := Vector3(-dir.z, 0, dir.x)
		var line: Array[Vector3] = []
		for s in 7:
			var f := s / 6.0
			line.append(dir * (0.04 + 0.36 * f) + perp * (0.07 * sin(PI * f)) * (1.0 if k != 1 else -1.0) + Vector3(0, y, 0))
		_chain(bananas, line, 0.048, 0.036, 5, Color(1.0, 0.85, 0.18), true)
		_prism(bananas, line[6], line[6] + dir * 0.03, 0.02, 0.012, 5, WOOD_DARK)
	_prism(bananas, Vector3(-0.05, 0.08, 0), Vector3(0.06, 0.08, 0), 0.04, 0.03, 5, Color(0.5, 0.42, 0.12))
	_lump(bananas, Vector3(-0.07, 0.08, 0), Vector3(0.04, 0.04, 0.04), WOOD_DARK, WOOD_DARK, 160)
	_save_fruit("06_bananas", bananas)

	var mandarin := _tool()
	_lump(mandarin, Vector3(0, 0.1, 0), Vector3(0.13, 0.1, 0.13), Color(0.95, 0.5, 0.05), Color(1.0, 0.72, 0.2), 170)
	_lump(mandarin, Vector3(0, 0.2, 0), Vector3(0.03, 0.015, 0.03), LEAF_DARK, LEAF, 171)
	_leaf(mandarin, Vector3(0, 0.205, 0), Vector3(0.13, 0.22, 0.04), 0.045, LEAF, Vector3.UP)
	_leaf(mandarin, Vector3(0, 0.205, 0), Vector3(-0.11, 0.22, -0.06), 0.04, LEAF_DARK, Vector3.UP)
	for k in 3:  # a couple of peeled segments next to it
		_lump(mandarin, Vector3(0.17 + k * 0.045, 0.03, 0.11 - k * 0.04), Vector3(0.025, 0.03, 0.04), Color(0.98, 0.6, 0.1), Color(1.0, 0.8, 0.3), 172 + k)
	_save_fruit("07_mandarin", mandarin)

	var mango := _tool()
	var tilt_m := Basis(Vector3(0, 0, 1), deg_to_rad(-22))
	_lump(mango, Vector3(0, 0.12, 0), Vector3(0.1, 0.14, 0.085), Color(0.95, 0.72, 0.1), Color(1.0, 0.38, 0.2), 180, tilt_m)
	_prism(mango, Vector3(0.045, 0.24, 0), Vector3(0.06, 0.29, 0), 0.015, 0.012, 5, WOOD_DARK)
	_leaf(mango, Vector3(0.06, 0.28, 0), Vector3(0.18, 0.32, 0.02), 0.04, LEAF_DARK, Vector3.UP)
	_save_fruit("08_mango", mango)

	var mixed := _tool()
	_leaf(mixed, Vector3(0, 0.0, 0), Vector3(0.28, 0.03, 0.05), 0.07, LEAF_DARK, Vector3.UP)
	_leaf(mixed, Vector3(0, 0.0, 0), Vector3(-0.25, 0.03, 0.12), 0.07, LEAF, Vector3.UP)
	_leaf(mixed, Vector3(0, 0.0, 0), Vector3(-0.05, 0.03, -0.27), 0.07, LEAF_DARK, Vector3.UP)
	var palette: Array = [[Color(0.78, 0.08, 0.12), Color(0.98, 0.3, 0.3)], [Color(0.22, 0.28, 0.72), Color(0.5, 0.58, 0.95)],
		[Color(0.5, 0.12, 0.5), Color(0.78, 0.4, 0.8)]]
	for k in 9:
		var ring_a := TAU * k / 9.0
		var ring_r := 0.09 if k < 6 else 0.0
		var cols: Array = palette[k % 3]
		var p := Vector3(cos(ring_a), 0, sin(ring_a)) * (0.1 if k < 6 else 0.0) + Vector3(0, 0.05 if k < 6 else 0.11, 0)
		if k >= 6:
			p += Vector3(cos(ring_a * 2.0), 0, sin(ring_a * 2.0)) * 0.04 * (k - 5)
		_lump(mixed, p, Vector3(0.05, 0.048, 0.05), cols[0], cols[1], 190 + k)
		if ring_r > 0.0 and k % 2 == 0:
			_prism(mixed, p + Vector3(0, 0.04, 0), p + Vector3(0.01, 0.075, 0), 0.007, 0.006, 4, WOOD_DARK)
	_save_fruit("09_mixed_berries", mixed)


## A bunch of berries hanging off a twig, with two leaves.
func _berries(cols: Array, seed_value: int) -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(-0.1, 0.03, 0.02), Vector3(0.14, 0.12, -0.02), 0.014, 0.01, 4, WOOD_DARK)
	var spots: Array[Vector3] = [Vector3(-0.07, 0.06, 0.07), Vector3(0.0, 0.05, 0.1), Vector3(0.07, 0.06, 0.07),
		Vector3(-0.1, 0.06, -0.01), Vector3(0.0, 0.1, 0.02), Vector3(0.09, 0.07, -0.02), Vector3(-0.03, 0.06, -0.08), Vector3(0.05, 0.06, -0.09)]
	for k in spots.size():
		_lump(t, spots[k], Vector3(0.05, 0.05, 0.05), cols[0], cols[1], seed_value + k)
		_prism(t, spots[k] + Vector3(0, 0.04, 0), spots[k] + Vector3(0, 0.07, 0), 0.006, 0.006, 3, WOOD_DARK)
	_leaf(t, Vector3(0.12, 0.11, 0.0), Vector3(0.24, 0.12, 0.1), 0.05, LEAF, Vector3.UP)
	_leaf(t, Vector3(0.12, 0.11, 0.0), Vector3(0.22, 0.13, -0.12), 0.045, LEAF_DARK, Vector3.UP)
	return t


# ---------------------------------------------------------------- shapes

func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


func _tri(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	t.set_color(colour)
	t.set_normal(normal)
	for p in [a, b, c]:
		t.add_vertex(p)


## A triangle wound so that it faces the side hint points to.
func _tri_out(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hint: Vector3, colour: Color) -> void:
	if (c - a).cross(b - a).dot(hint) >= 0.0:
		_tri(t, a, b, c, colour)
	else:
		_tri(t, a, c, b, colour)


func _quad_out(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3, colour: Color) -> void:
	_tri_out(t, a, b, c, hint, colour)
	_tri_out(t, a, c, d, hint, colour)


## A tapered prism from a to b (radii ra, rb), with caps; flat shaded (same as the weapons bake).
func _prism(t: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, colour: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for k in sides:
		var ang := TAU * k / sides
		var dir := side * cos(ang) + other * sin(ang)
		ring_a.append(a + dir * ra)
		ring_b.append(b + dir * rb)
	var dark := colour.darkened(0.06)
	for k in sides:
		var j := (k + 1) % sides
		var shade := colour if k % 2 == 0 else dark
		_tri(t, ring_a[k], ring_b[k], ring_b[j], shade)
		_tri(t, ring_a[k], ring_b[j], ring_a[j], shade)
	for k in range(1, sides - 1):
		_tri(t, ring_a[0], ring_a[k + 1], ring_a[k], dark)
		_tri(t, ring_b[0], ring_b[k], ring_b[k + 1], colour)


## A curved tube through points, radius from r0 to r1; flat is a banana-like squashed section.
func _chain(t: SurfaceTool, pts: Array[Vector3], r0: float, r1: float, sides: int, colour: Color, bulge := false) -> void:
	for n in pts.size() - 1:
		var f := float(n) / (pts.size() - 1)
		var ra := lerpf(r0, r1, f)
		var rb := lerpf(r0, r1, f + 1.0 / (pts.size() - 1))
		if bulge:
			ra *= 0.6 + 0.4 * sin(PI * clampf(f + 0.1, 0.0, 1.0))
			rb *= 0.6 + 0.4 * sin(PI * clampf(f + 1.0 / (pts.size() - 1) + 0.1, 0.0, 1.0))
		_prism(t, pts[n], pts[n + 1], ra, rb, sides, colour)


## An axis-aligned box.
func _box(t: SurfaceTool, c: Vector3, h: Vector3, colour: Color) -> void:
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = sgn
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var mid := c + n * h[axis]
			var du := u * h[(axis + 1) % 3]
			var dv := v * h[(axis + 2) % 3]
			var shade := colour.lightened(0.08) if n.y > 0.5 else (colour.darkened(0.08) if n.y < -0.5 else colour)
			_quad_out(t, mid - du - dv, mid + du - dv, mid + du + dv, mid - du + dv, n, shade)


## A flat disc (fan) at the centre, facing up or down.
func _disc(t: SurfaceTool, centre: Vector3, radius: float, sides: int, colour: Color, up: bool) -> void:
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		_tri_out(t, centre, centre + Vector3(cos(a0), 0, sin(a0)) * radius, centre + Vector3(cos(a1), 0, sin(a1)) * radius,
			Vector3.UP if up else Vector3.DOWN, colour if k % 2 == 0 else colour.darkened(0.06))


## A flat ring slab between two radii, from y0 to y1 (a collar of earth).
func _ring_slab(t: SurfaceTool, r_in: float, r_out: float, y0: float, y1: float, sides: int, top: Color, side: Color) -> void:
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var mid := (d0 + d1).normalized()
		_quad_out(t, d0 * r_in + Vector3(0, y1, 0), d0 * r_out + Vector3(0, y1 - 0.06, 0), d1 * r_out + Vector3(0, y1 - 0.06, 0),
			d1 * r_in + Vector3(0, y1, 0), Vector3.UP, top if k % 2 == 0 else top.darkened(0.06))
		_quad_out(t, d0 * r_out + Vector3(0, y1 - 0.06, 0), d0 * r_out + Vector3(0, y0, 0), d1 * r_out + Vector3(0, y0, 0),
			d1 * r_out + Vector3(0, y1 - 0.06, 0), mid, side)
		_quad_out(t, d0 * r_in + Vector3(0, y1, 0), d0 * r_in + Vector3(0, y0 - 0.4, 0), d1 * r_in + Vector3(0, y0 - 0.4, 0),
			d1 * r_in + Vector3(0, y1, 0), -mid, side)


## The wall of the shaft, facing inwards, from (y0, r0) down to (y1, r1); layer picks the stripe tint.
func _funnel(t: SurfaceTool, y0: float, r0: float, y1: float, r1: float, sides: int, colour: Color, layer: int) -> void:
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		_quad_out(t, d0 * r0 + Vector3(0, y0, 0), d1 * r0 + Vector3(0, y0, 0), d1 * r1 + Vector3(0, y1, 0), d0 * r1 + Vector3(0, y1, 0),
			-(d0 + d1), colour.lightened(0.05 * ((k + layer) % 2)))


## A pie-slice cover of leaves and twigs lying over the pit, its pivot at home (the mesh is built around it).
func _wedge(t: SurfaceTool, theta: float, half: float, home: Vector3, seed_value: int) -> void:
	var o := -home
	var l := Vector3(cos(theta - half), 0, sin(theta - half))
	var r := Vector3(cos(theta + half), 0, sin(theta + half))
	var apex := Vector3(0, 0.07, 0) + o
	var mid_l := l * 0.8 + Vector3(0, 0.05, 0) + o
	var mid_r := r * 0.8 + Vector3(0, 0.05, 0) + o
	var out_l := l * 1.52 + Vector3(0, 0.02, 0) + o
	var out_r := r * 1.52 + Vector3(0, 0.02, 0) + o
	var thick := Vector3(0, -0.07, 0)
	var green := LEAF if seed_value % 2 == 0 else OLIVE
	var green2 := LEAF_LIGHT if seed_value % 2 == 0 else LEAF
	_tri_out(t, apex, mid_l, mid_r, Vector3.UP, green)
	_quad_out(t, mid_l, out_l, out_r, mid_r, Vector3.UP, green2)
	_tri_out(t, apex + thick, mid_l + thick, mid_r + thick, Vector3.DOWN, EARTH_DARK)
	_quad_out(t, mid_l + thick, out_l + thick, out_r + thick, mid_r + thick, Vector3.DOWN, EARTH_DARK)
	_quad_out(t, out_l, out_l + thick, out_r + thick, out_r, l + r, WOOD_DARK)
	_quad_out(t, apex, apex + thick, out_l + thick, out_l, -(r - l) * 4.0 + Vector3(0, 0, 0), WOOD)
	_quad_out(t, apex, apex + thick, out_r + thick, out_r, (r - l) * 4.0, WOOD)
	# A twig across the leaves.
	var mid := (l + r).normalized()
	_prism(t, mid * 0.35 + Vector3(0, 0.1, 0) + o, mid * 1.45 + Vector3(0, 0.07, 0) + o, 0.03, 0.022, 5, WOOD_DARK)


## A chunky faceted lump (a jittered low-poly sphere), darker below; basis tilts it.
func _lump(t: SurfaceTool, centre: Vector3, r: Vector3, low: Color, high: Color, seed_value: int, basis := Basis()) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var moved := {}
	for v in verts:
		var key := v.snapped(Vector3.ONE * 0.001)
		if not moved.has(key):
			moved[key] = v * rng.randf_range(0.9, 1.08)
	for n in range(0, index.size(), 3):
		var p: Array[Vector3] = []
		for m in 3:
			var v: Vector3 = moved[verts[index[n + m]].snapped(Vector3.ONE * 0.001)]
			p.append(centre + basis * Vector3(v.x / 0.5 * r.x, v.y / 0.5 * r.y, v.z / 0.5 * r.z))
		if (p[0] - p[1]).length() < 0.0001 or (p[1] - p[2]).length() < 0.0001 or (p[0] - p[2]).length() < 0.0001:
			continue
		var up := (basis.inverse() * ((p[0] + p[1] + p[2]) / 3.0 - centre)).normalized().y
		_tri(t, p[0], p[2], p[1], low.lerp(high, clampf(up * 0.5 + 0.5, 0.0, 1.0)))


func _stone(t: SurfaceTool, at: Vector3, size: float, seed_value: int) -> void:
	_lump(t, at + Vector3(0, size * 0.6, 0), Vector3(size, size * 0.65, size * 0.9), STONE, STONE_LIGHT, seed_value)


## Flat double-sided leaf from base to tip, widest at a third.
func _leaf(t: SurfaceTool, base: Vector3, tip: Vector3, width: float, colour: Color, up: Vector3) -> void:
	var axis := (tip - base).normalized()
	var side := axis.cross(up).normalized()
	var mid := base.lerp(tip, 0.35) + up * 0.012
	_tri(t, base, mid + side * width, tip, colour)
	_tri(t, base, tip, mid - side * width, colour.lightened(0.06))
	_tri(t, base, tip, mid + side * width, colour.darkened(0.12))
	_tri(t, base, mid - side * width, tip, colour.darkened(0.12))


## Leaves and twigs dropped around a spot as camouflage.
func _scatter_leaves(t: SurfaceTool, centre: Vector3, radius: float, count: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for k in count:
		var a := rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * radius * rng.randf_range(0.5, 1.25) + Vector3(0, 0.03, 0)
		var b := rng.randf() * TAU
		_leaf(t, p, p + Vector3(cos(b), 0.02, sin(b)) * rng.randf_range(0.14, 0.24), 0.05, [LEAF, LEAF_DARK, OLIVE, LEAF_LIGHT][k % 4], Vector3.UP)


# ---------------------------------------------------------------- saving

func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return PeakSmooth.soften(mat)


func _mesh_of(t: SurfaceTool, path: String) -> ArrayMesh:
	t.index()
	var mesh := t.commit()
	mesh.surface_set_material(0, _material())
	mesh = PeakSmooth.smooth(mesh)
	ResourceSaver.save(mesh, path)
	mesh.take_over_path(path)
	return mesh


func _player() -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library("", AnimationLibrary.new())
	return player


func _add(player: AnimationPlayer, anim_name: String, anim: Animation) -> void:
	player.get_animation_library("").add_animation(anim_name, anim)


func _scale_key(anim: Animation, path: String, keys: Array) -> void:
	var track := anim.add_track(Animation.TYPE_SCALE_3D)
	anim.track_set_path(track, path)
	for key in keys:
		anim.scale_track_insert_key(track, key[0], key[1])


## parts: [name, SurfaceTool, node position]; the scene is root > TrapRoot > parts, plus the AnimationPlayer.
func _save_trap(trap_name: String, parts: Array, player: AnimationPlayer) -> void:
	var root := Node3D.new()
	root.name = "Peak" + trap_name.capitalize()
	var holder := Node3D.new()
	holder.name = "TrapRoot"
	root.add_child(holder)
	holder.owner = root
	var triangles := 0
	for part: Array in parts:
		var mesh := _mesh_of(part[1], OUT + "%s_%s.res" % [trap_name, str(part[0]).to_lower()])
		triangles += mesh.surface_get_array_index_len(0) / 3
		var node := MeshInstance3D.new()
		node.name = part[0]
		node.mesh = mesh
		node.position = part[2]
		holder.add_child(node)
		node.owner = root
	if player:
		root.add_child(player)
		player.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, OUT + trap_name + ".tscn")
	root.free()
	print("baked ", trap_name, ": ", triangles, " triangles")


func _save_fruit(fruit_name: String, t: SurfaceTool) -> void:
	var mesh := _mesh_of(t, FRUIT_OUT + fruit_name + ".res")
	var root := Node3D.new()
	root.name = "Peak" + fruit_name.substr(3).capitalize().replace(" ", "")
	var node := MeshInstance3D.new()
	node.name = "Model"
	node.mesh = mesh
	root.add_child(node)
	node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, FRUIT_OUT + fruit_name + ".tscn")
	root.free()
	print("baked ", fruit_name, ": ", mesh.surface_get_array_index_len(0) / 3, " triangles")
