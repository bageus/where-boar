@tool
extends StaticBody3D

## Green Valley ground (D039): one smooth height map with hills, a mesa, a cliff over the river and hollows.
## The heights are baked by tools/bake_green_valley.py; the visible surface is drawn from the same data.
## It also dresses itself: grass and tall-grass patches, massive rocks on the cliffs, stumps, logs, more trees
## and sandy river banks.

const GRASS := Color(0.16, 0.4, 0.1)
const ROCK := Color(0.42, 0.42, 0.44)
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
## Stylized grass (assets/grass, MIT, StayAtHomeDev): clumps on grass-coloured ground, in square chunks
## that disappear beyond GRASS_RANGE metres, so far grass costs nothing.
const GRASS_MESH := preload("res://assets/grass/grass.glb")
const GRASS_MATERIAL := preload("res://assets/grass/grass_material.tres")
const GRASS_CHUNK := 20
const GRASS_PER_METRE := 6
const GRASS_RANGE := 30.0
## Tall grass patches (owner, 2026-10-28): clumps about twice as tall, with some wheat; they hide the hunter
## from boars like a bush (cover layer, see boar_body.gd).
const TALL_PATCHES := 12
const COVER_LAYER := 1 << 4
const WHEAT := preload("res://assets/nature/meshes/Wheat.res")
## Owner's models baked by tools/bake_nature_meshes.gd.
const CLIFF_ROCKS: Array[Mesh] = [
	preload("res://assets/nature/meshes/BigRock1.res"), preload("res://assets/nature/meshes/BigRock2.res"),
	preload("res://assets/nature/meshes/BigRock3.res"), preload("res://assets/nature/meshes/BigRock4.res"),
	preload("res://assets/nature/meshes/BigRock5.res"),
]
## One massive rock per CLIFF_STEP x CLIFF_STEP metres of cliff; each is solid.
const CLIFF_STEP := 3
const STUMP := preload("res://assets/nature/meshes/TreeStump_Moss.res")
## Fallen trees and logs (owner, 2026-10-28).
const LOGS: Array[Mesh] = [
	preload("res://assets/nature/meshes/WoodLog.res"), preload("res://assets/nature/meshes/Log_1.res"),
	preload("res://assets/nature/meshes/Log_2.res"), preload("res://assets/nature/meshes/Log_3.res"),
]
const STUMPS := 30
const LOG_COUNT := 36
## Ferns: decoration only, a few thousand triangles each, so drawn within FERN_RANGE metres.
const FERNS: Array[Mesh] = [
	preload("res://assets/nature/meshes/05_spreading_fern.res"), preload("res://assets/nature/meshes/06_upright_fern.res"),
	preload("res://assets/nature/meshes/07_small_fern.res"), preload("res://assets/nature/meshes/08_dense_fern.res"),
]
const FERN_COUNT := 260
const FERN_RANGE := 35.0
## Trees added on top of the authored ones (owner, 2026-10-28: more trees).
const TREES: Array[Mesh] = [
	preload("res://assets/nature/meshes/OakTree1.res"), preload("res://assets/nature/meshes/OakTree2.res"),
	preload("res://assets/nature/meshes/OakTree3.res"), preload("res://assets/nature/meshes/SpruceTree1.res"),
	preload("res://assets/nature/meshes/SpruceTree2.res"), preload("res://assets/nature/meshes/SpruceTree3.res"),
	preload("res://assets/nature/meshes/Tree_1.res"), preload("res://assets/nature/meshes/Tree_2.res"),
	preload("res://assets/nature/meshes/Tree_3.res"),
]
const EXTRA_TREES := 70
## Scattered things keep this far from props, zones, spawns and each other.
const CLEAR_RADIUS := 5.0

## Grid cells under stumps, logs and trees: no grass grows through them.
var _blocked := {}
var _taken: Array[Vector3] = []

@onready var _shape: HeightMapShape3D = $Collision.shape


func _ready() -> void:
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


func _plant_grass() -> void:
	var clump: Mesh = (GRASS_MESH.instantiate().get_child(0) as MeshInstance3D).mesh
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
						var size := rng.randf_range(0.65, 0.8) if tall else rng.randf_range(0.35, 0.45)
						var spot := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size),
								Vector3(x, height_at(x, z) - 0.05, z) - centre)
						spots.append(spot)
						if tall and k == 0 and rng.randf() < 0.5:
							wheat.append(spot.scaled_local(Vector3.ONE * 1.4 / size))
			_add_multimesh(clump, spots, centre, GRASS_MATERIAL, GRASS_RANGE)
			_add_multimesh(WHEAT, wheat, centre, null, GRASS_RANGE)


## Massive rocks half sunk into every steep stretch, so cliffs read as a rocky bluff.
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
			var size := rng.randf_range(6.0, 9.0) / maxf(box.size.x, box.size.z)
			var x := best.x - (w - 1) * 0.5
			var z := best.y - (d - 1) * 0.5
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
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
		at.y = height_at(at.x, at.z) - 0.1
		var spot := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at)
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
			(shape.shape as CylinderShape3D).radius = 0.35
			shape.position = at + Vector3.UP
		else:
			shape.shape = BoxShape3D.new()
			(shape.shape as BoxShape3D).size = box.size * size * Vector3(0.7, 1.0, 0.9)
			shape.transform = Transform3D(spot.basis.orthonormalized(), spot * box.get_center())
		add_child(shape)
	for k in meshes.size():
		_add_multimesh(meshes[k], spots[k], Vector3.ZERO, null, 0.0 if solid else FERN_RANGE)


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
func _add_multimesh(mesh: Mesh, spots: Array[Transform3D], centre: Vector3, material: Material, draw_range: float) -> void:
	if spots.is_empty():
		return
	var multimesh := MultiMesh.new()
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
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	return mesh
