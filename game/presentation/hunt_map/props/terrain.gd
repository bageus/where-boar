@tool
extends StaticBody3D

## Green Valley ground (D039): one smooth height map with hills, a mesa, a cliff over the river and hollows.
## The heights are baked by tools/bake_green_valley.py; the visible surface is drawn from the same data.
## It also dresses itself: grass and tall-grass patches, massive rocks on the cliffs, stumps, logs, more trees
## and sandy river banks.

const GRASS := Color(0.2, 0.44, 0.1)
const ROCK := Color(0.47, 0.46, 0.47)
const MUD := Color(0.5, 0.36, 0.2)
const SAND := Color(0.74, 0.64, 0.42)
const WET_SAND := Color(0.6, 0.52, 0.34)
## Water surface height and the z band the river (and the Water plane in hunt_map.tscn) covers.
const WATER_Y := -0.5
const RIVER_BAND := Vector2(-38.0, -2.0)
## Banks this low are sandy in places, fading into grass above it.
const SAND_TOP := 0.2
## Slopes steeper than this (normal.y below it, about 40 degrees) look like bare rock.
const ROCK_NORMAL_Y := 0.75
## Stylized grass (owner, 2026-11-02: like in PEAK): a clump of 13 bent blades (tools/bake_peak_rocks.gd,
## 39 triangles) with a swaying shader, in square chunks drawn only near the camera. The ground under it is
## painted in the grass's colours (assets/grass/ground_material.tres), so grass and ground read as one carpet.
const GRASS_CLUMP: Mesh = preload("res://assets/grass/peak_grass.res")
const GRASS_MATERIAL := preload("res://assets/grass/grass_material.tres")
const GROUND_MATERIAL := preload("res://assets/grass/ground_material.tres")
## 10 m chunks (owner, 2026-11-07: 8 FPS on the hunt): 20 m ones drew about a million grass triangles a frame,
## most of them out of range or behind the camera.
const GRASS_CHUNK := 10
## Short grass (owner, 2026-11-02: denser, very short, a little taller and shorter by turns): 2.7 times the
## clumps of before, each narrower and much lower; the height follows a noise field over the map
## (short_grass_scale). Clumps shrink into the ground towards GRASS_RANGE metres (peak_grass.gdshader
## fade_end), so the cut-off is soft and the range can be shorter than before (30 m) at about the same cost.
const GRASS_PER_METRE := 8
const GRASS_WIDTH := Vector2(0.18, 0.24)
const GRASS_HEIGHT := Vector2(0.06, 0.15)
const GRASS_RANGE := 24.0
## Every other short clump is drawn only this near (clumps sink from fade_end * 0.6 on): half density where they are mostly sunk.
const GRASS_THIN_FROM := GRASS_RANGE * 0.85
## Tall grass patches (owner, 2026-10-28): clumps about twice as tall, with some wheat; they hide the hunter
## from boars like a bush (cover layer, see boar_body.gd).
const TALL_PATCHES := 12
const COVER_LAYER := 1 << 4
const WHEAT := preload("res://assets/nature/meshes/Wheat.res")
## Layered, faceted cliff chunks (owner, 2026-11-02: rocks like in PEAK), baked by tools/bake_peak_rocks.gd.
const CLIFF_ROCKS: Array[Mesh] = [
	preload("res://assets/nature/meshes/peak/PeakCliff1.res"), preload("res://assets/nature/meshes/peak/PeakCliff2.res"),
	preload("res://assets/nature/meshes/peak/PeakCliff3.res"), preload("res://assets/nature/meshes/peak/PeakCliff4.res"),
	preload("res://assets/nature/meshes/peak/PeakCliff5.res"),
]
## One broad cliff wall per CLIFF_STEP x CLIFF_STEP metres of cliff, its face turned downhill so neighbours
## join into one face (owner, 2026-11-02: no chaotic pile of boulders); each is solid.
const CLIFF_STEP := 6
const Trunk = preload("res://game/presentation/hunt_map/props/trunk.gd")
const STUMP := preload("res://assets/nature/meshes/peak/PeakStump1.res")
## Fallen trees and logs (owner, 2026-10-28).
const LOGS: Array[Mesh] = [
	preload("res://assets/nature/meshes/peak/PeakLog1.res"), preload("res://assets/nature/meshes/peak/PeakLog2.res"),
	preload("res://assets/nature/meshes/peak/PeakLog3.res"), preload("res://assets/nature/meshes/peak/PeakLog4.res"),
]
const STUMPS := 30
const LOG_COUNT := 36
## Undergrowth (owner, 2026-11-02: like in PEAK; tools/bake_peak_trees.gd): decoration only, drawn within FERN_RANGE metres.
const FERNS: Array[Mesh] = [
	preload("res://assets/nature/meshes/peak/PeakShrub1.res"), preload("res://assets/nature/meshes/peak/PeakShrub2.res"),
	preload("res://assets/nature/meshes/peak/PeakShrub3.res"),
]
const FERN_COUNT := 260
const FERN_RANGE := 35.0
## Trees added on top of the authored ones (owner, 2026-10-28: more trees), PEAK-like (tools/bake_peak_trees.gd).
const TREES: Array[Mesh] = [
	preload("res://assets/nature/meshes/peak/PeakTree1.res"), preload("res://assets/nature/meshes/peak/PeakTree2.res"),
	preload("res://assets/nature/meshes/peak/PeakTree3.res"), preload("res://assets/nature/meshes/peak/PeakTree4.res"),
	preload("res://assets/nature/meshes/peak/PeakPine1.res"), preload("res://assets/nature/meshes/peak/PeakPine2.res"),
	preload("res://assets/nature/meshes/peak/PeakPine3.res"),
]
const EXTRA_TREES := 70
## Scattered things keep this far from props, zones, spawns and each other.
const CLEAR_RADIUS := 5.0

## Grid cells under stumps, logs and trees: no grass grows through them.
var _blocked := {}
var _taken: Array[Vector3] = []
## Ground mesh arrays, kept so leaf pits can cut holes into it.
var _arrays: Array
## Leaf pit openings: x, z, radius (the grass shader takes up to 8).
var _holes := PackedVector4Array()

@onready var _shape: HeightMapShape3D = $Collision.shape

static var _grass_noise: FastNoiseLite


## Short-grass clump scale at a map point: width jittered per clump, height from patches of very short,
## middling and slightly taller grass a few metres across, jittered too. Also used outside the walls.
static func short_grass_scale(x: float, z: float, rng: RandomNumberGenerator) -> Vector3:
	if _grass_noise == null:
		_grass_noise = FastNoiseLite.new()
		_grass_noise.seed = 21
		_grass_noise.frequency = 0.12
	var band := smoothstep(-0.45, 0.45, _grass_noise.get_noise_2d(x, z))
	var width := rng.randf_range(GRASS_WIDTH.x, GRASS_WIDTH.y)
	var height := lerpf(GRASS_HEIGHT.x, GRASS_HEIGHT.y, band) * rng.randf_range(0.8, 1.2)
	return Vector3(width, height, width)


func _ready() -> void:
	add_to_group("terrain")
	GRASS_MATERIAL.set_shader_parameter("hole_count", 0)
	GRASS_MATERIAL.set_shader_parameter("fade_end", GRASS_RANGE)
	$Mesh.mesh = _build_mesh()
	for node in get_parent().find_children("*", "Node3D", true, false):
		if node != self and not is_ancestor_of(node):
			_taken.append((node as Node3D).global_position)
	_scatter([STUMP], STUMPS, Vector2(1.0, 1.4), false, 13)
	_scatter(LOGS, LOG_COUNT, Vector2(1.0, 1.4), false, 14)
	_scatter(TREES, EXTRA_TREES, Vector2(6.0, 10.0), true, 15)
	_scatter(FERNS, FERN_COUNT, Vector2(1.0, 1.6), false, 16, false, 1.5)
	_plant_grass()
	_place_cliff_rocks()


## Ground height at a map point, metres; edges clamp to the last sample.
func height_at(x: float, z: float) -> float:
	var w := _shape.map_width
	var d := _shape.map_depth
	var fx := clampf(x + (w - 1) * 0.5, 0.0, w - 1.001)
	var fz := clampf(z + (d - 1) * 0.5, 0.0, d - 1.001)
	var i := int(fx)
	var j := int(fz)
	var data := _shape.map_data
	var top := lerpf(data[j * w + i], data[j * w + i + 1], fx - i)
	var bottom := lerpf(data[(j + 1) * w + i], data[(j + 1) * w + i + 1], fx - i)
	return lerpf(top, bottom, fz - j)


## Lowest ground height within radius of a map point (centre plus a ring): a tree or stump sunk to it stands
## out of the ground on a slope instead of floating over the downhill side.
func lowest_under(x: float, z: float, radius: float) -> float:
	var low := height_at(x, z)
	for n in 16:
		var a := TAU * n / 16.0
		low = minf(low, height_at(x + cos(a) * radius * 1.3, z + sin(a) * radius * 1.3))
	return low


func _plant_grass() -> void:
	var clump := GRASS_CLUMP
	var w := _shape.map_width
	var d := _shape.map_depth
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var patches: Array[Vector3] = []  # x, z, radius
	while patches.size() < TALL_PATCHES:
		var i := rng.randi_range(10, w - 11)
		var j := rng.randi_range(10, d - 11)
		if _grassy(i, j):
			patches.append(Vector3(i - (w - 1) * 0.5, j - (d - 1) * 0.5, rng.randf_range(4.0, 8.0)))
	var cover := StaticBody3D.new()
	cover.collision_layer = COVER_LAYER
	cover.collision_mask = 0
	cover.add_to_group("tall_grass")  # fleeing boars hide in these patches (boar_surroundings.gd)
	add_child(cover)
	for p in patches:
		var shape := CollisionShape3D.new()
		shape.shape = CylinderShape3D.new()
		(shape.shape as CylinderShape3D).radius = p.z
		(shape.shape as CylinderShape3D).height = 1.6
		shape.position = Vector3(p.x, height_at(p.x, p.y) + 0.8, p.y)
		cover.add_child(shape)
	for cj in range(0, d - 1, GRASS_CHUNK):
		for ci in range(0, w - 1, GRASS_CHUNK):
			# Visibility range counts from the node's origin, so each chunk sits at its centre.
			var centre := Vector3(ci + GRASS_CHUNK * 0.5 - (w - 1) * 0.5, 0.0, cj + GRASS_CHUNK * 0.5 - (d - 1) * 0.5)
			var spots: Array[Transform3D] = []
			var near: Array[Transform3D] = []
			var wheat: Array[Transform3D] = []
			for j in range(cj, mini(cj + GRASS_CHUNK, d - 1)):
				for i in range(ci, mini(ci + GRASS_CHUNK, w - 1)):
					if not _grassy(i, j) or _blocked.has(Vector2i(i, j)):
						continue
					var cell := Vector2(i - (w - 1) * 0.5, j - (d - 1) * 0.5)
					var tall := patches.any(func(p: Vector3) -> bool: return cell.distance_to(Vector2(p.x, p.y)) < p.z)
					for k in GRASS_PER_METRE:
						var x := i + rng.randf() - (w - 1) * 0.5
						var z := j + rng.randf() - (d - 1) * 0.5
						if tall and k % 3 != 0:
							continue  # tall clumps are big enough at the old density
						var tall_size := rng.randf_range(0.65, 0.8)
						var size := Vector3(tall_size * 1.41, tall_size, tall_size * 1.41) if tall else short_grass_scale(x, z, rng)
						var spot := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(size),
								Vector3(x, height_at(x, z) - 0.03, z) - centre)
						(near if k % 2 == 1 and not tall else spots).append(spot)
						if tall and k == 0 and rng.randf() < 0.5:
							wheat.append(spot.scaled_local(Vector3.ONE * 1.4 / size.y))
			# A chunk counts its range from its centre; its corners stand up to 0.71 chunk further out.
			_add_multimesh(clump, spots, centre, GRASS_MATERIAL, GRASS_RANGE + GRASS_CHUNK * 0.71)
			_add_multimesh(clump, near, centre, GRASS_MATERIAL, GRASS_THIN_FROM + GRASS_CHUNK * 0.71)
			_add_multimesh(WHEAT, wheat, centre, null, GRASS_RANGE + GRASS_CHUNK * 0.71)


## Broad cliff walls half sunk into every steep stretch, so cliffs read as one rocky face.
func _place_cliff_rocks() -> void:
	var w := _shape.map_width
	var d := _shape.map_depth
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var spots: Array = CLIFF_ROCKS.map(func(_m: Mesh) -> Array[Transform3D]: return [] as Array[Transform3D])
	var hulls: Array = CLIFF_ROCKS.map(func(m: Mesh) -> Shape3D: return m.create_convex_shape(true, true))
	for cj in range(1, d - 2, CLIFF_STEP):
		for ci in range(1, w - 2, CLIFF_STEP):
			var best := Vector2i(-1, -1)
			var best_y := ROCK_NORMAL_Y
			for j in range(cj, mini(cj + CLIFF_STEP, d - 1)):
				for i in range(ci, mini(ci + CLIFF_STEP, w - 1)):
					var ny := _normal(i, j).y
					if ny < best_y:
						best_y = ny
						best = Vector2i(i, j)
			if best.x < 0:
				continue
			var k := rng.randi() % CLIFF_ROCKS.size()
			var box := CLIFF_ROCKS[k].get_aabb()
			var size := rng.randf_range(11.0, 15.0) / box.size.x
			var x := best.x - (w - 1) * 0.5
			var z := best.y - (d - 1) * 0.5
			var down := _normal(best.x, best.y)  # the wall's face (+z) looks down the slope
			var basis := Basis(Vector3.UP, atan2(down.x, down.z) + rng.randf_range(-0.2, 0.2)).scaled(Vector3.ONE * size)
			var spot := Transform3D(basis, Vector3(x, height_at(x, z) - box.size.y * size * 0.45, z))
			spots[k].append(spot)
			var shape := CollisionShape3D.new()
			shape.shape = hulls[k]
			shape.transform = spot
			add_child(shape)
	for k in CLIFF_ROCKS.size():
		_add_multimesh(CLIFF_ROCKS[k], spots[k], Vector3.ZERO, null, 0.0)


## Puts count copies of meshes on open grass, clear of everything else by clear metres. A solid one gets a
## collision shape on this body: a box for stumps and logs, a trunk for trees (fit_height: size_range is the
## height, else a scale). The rest (ferns) are drawn only near the camera, like grass.
func _scatter(meshes: Array[Mesh], count: int, size_range: Vector2, fit_height: bool, rng_seed: int,
		solid := true, clear := CLEAR_RADIUS) -> void:
	var w := _shape.map_width
	var d := _shape.map_depth
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var spots: Array = meshes.map(func(_m: Mesh) -> Array[Transform3D]: return [] as Array[Transform3D])
	var batches: Array = meshes.map(func(_m: Mesh) -> MultiMesh: return MultiMesh.new())
	var placed := 0
	var tries := 0
	while placed < count and tries < 3000:
		tries += 1
		var i := rng.randi_range(4, w - 5)
		var j := rng.randi_range(4, d - 5)
		var at := Vector3(i - (w - 1) * 0.5, 0.0, j - (d - 1) * 0.5)
		if not _grassy(i, j) or _taken.any(func(p: Vector3) -> bool: return Vector2(p.x - at.x, p.z - at.z).length() < clear):
			continue
		_taken.append(at)
		placed += 1
		var k := rng.randi() % meshes.size()
		var box := meshes[k].get_aabb()
		var size := rng.randf_range(size_range.x, size_range.y) / (box.size.y if fit_height else 1.0)
		var foot := Vector3.ZERO  # the footprint centre (a tree: its trunk), model units
		var foot_r := maxf(box.size.x, box.size.z) * size * 0.35
		if fit_height:
			var trunk0 := Trunk.base(meshes[k])
			foot = Vector3(trunk0.x, 0.0, trunk0.z)
			foot_r = maxf(0.35, trunk0.y * size)
		var turn := Basis(Vector3.UP, rng.randf() * TAU)
		var foot_at := at + turn * foot * size
		# A model whose lowest vertex is above its origin (some oaks) is lowered by that much too.
		at.y = lowest_under(foot_at.x, foot_at.z, foot_r) - 0.15 - (box.position.y * size if fit_height else 0.0)
		var spot := Transform3D(turn.scaled(Vector3.ONE * size), at)
		spots[k].append(spot)
		# No grass inside the footprint (a tree: its trunk), turned with the model.
		var reach := ceili(maxf(box.size.x, box.size.z) * size * 0.5)
		var half := Vector2(box.size.x, box.size.z) * (0.08 if fit_height else 0.5)
		for dj in range(-reach, reach + 1):
			for di in range(-reach, reach + 1):
				var local := spot.affine_inverse() * Vector3(at.x + di, at.y, at.z + dj) - box.get_center()
				if absf(local.x) < half.x + 0.3 / size and absf(local.z) < half.y + 0.3 / size:
					_blocked[Vector2i(i + di, j + dj)] = true
		if not solid:
			continue
		var shape := CollisionShape3D.new()
		if fit_height:
			shape.shape = CylinderShape3D.new()
			var trunk := Trunk.base(meshes[k])
			(shape.shape as CylinderShape3D).radius = maxf(0.35, trunk.y * size)
			shape.position = spot * Vector3(trunk.x, 0.0, trunk.z) + Vector3.UP
		else:
			shape.shape = BoxShape3D.new()
			(shape.shape as BoxShape3D).size = box.size * size * Vector3(0.7, 1.0, 0.9)
			shape.transform = Transform3D(spot.basis.orthonormalized(), spot * box.get_center())
		shape.set_meta("shake", [batches[k], spots[k].size() - 1])  # a boar running into it shakes it (boar_bump.gd)
		add_child(shape)
	for k in meshes.size():
		_add_multimesh(meshes[k], spots[k], Vector3.ZERO, null, 0.0 if solid else FERN_RANGE, batches[k])


## True where grass grows at a map point; footsteps there rustle (core/sfx footsteps.gd).
func grassy_at(x: float, z: float) -> bool:
	var i := clampi(roundi(x + (_shape.map_width - 1) * 0.5), 1, _shape.map_width - 2)
	var j := clampi(roundi(z + (_shape.map_depth - 1) * 0.5), 1, _shape.map_depth - 2)
	return _grassy(i, j)


## Open, gentle, dry ground that is not sand: where grass, stumps, logs and trees go.
func _grassy(i: int, j: int) -> bool:
	return _shape.map_data[j * _shape.map_width + i] >= -0.3 and _normal(i, j).y >= ROCK_NORMAL_Y and not _sandy(i, j)


## Low river banks, in stretches along the river.
func _sandy(i: int, j: int) -> bool:
	return _sand(i, j) > 0.5


## How sandy a bank point is, 0..1: soft at the top of the bank and at the ends of each sandy stretch.
func _sand(i: int, j: int) -> float:
	var x := i - (_shape.map_width - 1) * 0.5
	var z := j - (_shape.map_depth - 1) * 0.5
	if z < RIVER_BAND.x or z > RIVER_BAND.y:
		return 0.0
	var h := _shape.map_data[j * _shape.map_width + i]
	return (1.0 - smoothstep(SAND_TOP - 0.4, SAND_TOP, h)) * smoothstep(-0.9, -0.3, sin(x * 0.21) + sin(x * 0.083 + 2.0))


func _normal(i: int, j: int) -> Vector3:
	var w := _shape.map_width
	var d := _shape.map_depth
	var data := _shape.map_data
	var dx := data[j * w + mini(i + 1, w - 1)] - data[j * w + maxi(i - 1, 0)]
	var dz := data[mini(j + 1, d - 1) * w + i] - data[maxi(j - 1, 0) * w + i]
	return Vector3(-dx, 2.0, -dz).normalized()


## One draw call for many copies; spots are relative to centre. draw_range 0 = always drawn.
func _add_multimesh(mesh: Mesh, spots: Array[Transform3D], centre: Vector3, material: Material, draw_range: float,
		multimesh := MultiMesh.new()) -> void:
	if spots.is_empty():
		return
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for n in spots.size():
		multimesh.set_instance_transform(n, spots[n])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.position = centre
	node.material_override = material
	if draw_range > 0.0:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = draw_range
	add_child(node)


func _exit_tree() -> void:
	GRASS_MATERIAL.set_shader_parameter("hole_count", 0)  # the camp shares the grass material
	GRASS_MATERIAL.set_shader_parameter("fade_end", 0.0)


## A leaf pit went in (owner, 2026-10-30): ground cells touching its opening and the grass over it go,
## so the pit shows below; its rim covers the jagged edge.
# shortcut: only the look changes; the collision height map still has no hole, so the hunter walks
# over the opening. Cut the height map too if playtest shows it.
func dig(center: Vector3, radius: float) -> void:
	var c := to_local(center)
	var w := _shape.map_width
	var d := _shape.map_depth
	var cut := radius + 0.71  # half a cell's diagonal
	var indices: PackedInt32Array = _arrays[Mesh.ARRAY_INDEX]
	var ci := int(c.x + (w - 1) * 0.5)
	var cj := int(c.z + (d - 1) * 0.5)
	var reach := int(cut) + 1
	for j in range(maxi(cj - reach, 0), mini(cj + reach + 1, d - 1)):
		for i in range(maxi(ci - reach, 0), mini(ci + reach + 1, w - 1)):
			if Vector2(i - (w - 1) * 0.5 + 0.5 - c.x, j - (d - 1) * 0.5 + 0.5 - c.z).length() <= cut:
				var q := (j * (w - 1) + i) * 6
				for k in 6:
					indices[q + k] = 0  # a degenerate triangle draws nothing
	_arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = $Mesh.mesh
	var material := mesh.surface_get_material(0)
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	mesh.surface_set_material(0, material)
	if _holes.size() < 8:
		_holes.append(Vector4(center.x, center.z, radius + 0.3, 0.0))
		GRASS_MATERIAL.set_shader_parameter("holes", _holes)
		GRASS_MATERIAL.set_shader_parameter("hole_count", _holes.size())


func _build_mesh() -> ArrayMesh:
	var w := _shape.map_width
	var d := _shape.map_depth
	var data := _shape.map_data
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for j in d:
		for i in w:
			var h := data[j * w + i]
			verts.append(Vector3(i - (w - 1) * 0.5, h, j - (d - 1) * 0.5))
			var normal := _normal(i, j)
			normals.append(normal)
			var underwater := h < WATER_Y and j - (d - 1) * 0.5 > RIVER_BAND.x and j - (d - 1) * 0.5 < RIVER_BAND.y
			var ground := MUD if h < -0.3 and not underwater else GRASS.lerp(SAND, _sand(i, j))
			colors.append(ROCK if normal.y < ROCK_NORMAL_Y else (WET_SAND.lerp(SAND, _sand(i, j)) if underwater else ground))
	for j in d - 1:
		for i in w - 1:
			var a := j * w + i
			indices.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_VERTEX] = verts
	_arrays[Mesh.ARRAY_NORMAL] = normals
	_arrays[Mesh.ARRAY_COLOR] = colors
	_arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	mesh.surface_set_material(0, GROUND_MATERIAL)
	return mesh
