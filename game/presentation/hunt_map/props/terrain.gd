@tool
extends StaticBody3D

## Green Valley ground (D039): one smooth height map with hills, a mesa, a cliff over the river and hollows.
## The heights are baked by tools/bake_green_valley.py; the visible surface is drawn from the same data.
## It also dresses itself: grass and tall-grass patches, massive rocks on the cliffs, stumps and logs.

const GRASS := Color(0.16, 0.4, 0.1)
const ROCK := Color(0.42, 0.42, 0.44)
const MUD := Color(0.5, 0.36, 0.2)
## Slopes steeper than this (normal.y below it, about 40 degrees) look like bare rock.
const ROCK_NORMAL_Y := 0.75
## Stylized grass (assets/grass, MIT, StayAtHomeDev): clumps on grass-coloured ground, in square chunks
## that disappear beyond GRASS_RANGE metres, so far grass costs nothing.
const GRASS_MESH := preload("res://assets/grass/grass.glb")
const GRASS_MATERIAL := preload("res://assets/grass/grass_material.tres")
const GRASS_CHUNK := 20
const GRASS_PER_METRE := 6
const GRASS_RANGE := 30.0
## Tall grass patches (owner, 2026-10-28): clumps about twice as tall, with some wheat.
const TALL_PATCHES := 12
const WHEAT := preload("res://assets/nature/meshes/Wheat.res")
## Owner's models baked by tools/bake_nature_meshes.gd.
const CLIFF_ROCKS: Array[Mesh] = [
	preload("res://assets/nature/meshes/BigRock1.res"), preload("res://assets/nature/meshes/BigRock2.res"),
	preload("res://assets/nature/meshes/BigRock3.res"), preload("res://assets/nature/meshes/BigRock4.res"),
	preload("res://assets/nature/meshes/BigRock5.res"),
]
## One massive rock per CLIFF_STEP x CLIFF_STEP metres of cliff.
const CLIFF_STEP := 5
const STUMP := preload("res://assets/nature/meshes/TreeStump_Moss.res")
const LOG := preload("res://assets/nature/meshes/WoodLog.res")
const STUMPS := 30
const LOGS := 24
## Stumps and logs keep this far from props, zones, spawns and the river.
const CLEAR_RADIUS := 5.0

@onready var _shape: HeightMapShape3D = $Collision.shape


func _ready() -> void:
	$Mesh.mesh = _build_mesh()
	_plant_grass()
	_place_cliff_rocks()
	_place_stumps_and_logs()


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
	for cj in range(0, d - 1, GRASS_CHUNK):
		for ci in range(0, w - 1, GRASS_CHUNK):
			# Visibility range counts from the node's origin, so each chunk sits at its centre.
			var centre := Vector3(ci + GRASS_CHUNK * 0.5 - (w - 1) * 0.5, 0.0, cj + GRASS_CHUNK * 0.5 - (d - 1) * 0.5)
			var spots: Array[Transform3D] = []
			var wheat: Array[Transform3D] = []
			for j in range(cj, mini(cj + GRASS_CHUNK, d - 1)):
				for i in range(ci, mini(ci + GRASS_CHUNK, w - 1)):
					if not _grassy(i, j):
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
			var size := rng.randf_range(5.0, 8.0) / maxf(box.size.x, box.size.z)
			var x := best.x - (w - 1) * 0.5
			var z := best.y - (d - 1) * 0.5
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
			spots[k].append(Transform3D(basis, Vector3(x, height_at(x, z) - box.size.y * size * 0.35, z)))
	for k in CLIFF_ROCKS.size():
		_add_multimesh(CLIFF_ROCKS[k], spots[k], Vector3.ZERO, null, 0.0)


## Stumps and fallen logs on open grass; each gets a collision shape on this body, so they block like the ground.
func _place_stumps_and_logs() -> void:
	var w := _shape.map_width
	var d := _shape.map_depth
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var taken: Array[Vector3] = []
	for node in get_parent().find_children("*", "Node3D", true, false):
		if node != self and not is_ancestor_of(node):
			taken.append((node as Node3D).global_position)
	for kind in [STUMP, LOG]:
		var spots: Array[Transform3D] = []
		var tries := 0
		while spots.size() < (STUMPS if kind == STUMP else LOGS) and tries < 2000:
			tries += 1
			var i := rng.randi_range(4, w - 5)
			var j := rng.randi_range(4, d - 5)
			var at := Vector3(i - (w - 1) * 0.5, 0.0, j - (d - 1) * 0.5)
			if not _grassy(i, j) or taken.any(func(p: Vector3) -> bool: return Vector2(p.x - at.x, p.z - at.z).length() < CLEAR_RADIUS):
				continue
			taken.append(at)
			var size := rng.randf_range(1.0, 1.4)
			at.y = height_at(at.x, at.z) - 0.1
			var spot := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at)
			spots.append(spot)
			var shape := CollisionShape3D.new()
			var box := (kind as Mesh).get_aabb()
			shape.shape = BoxShape3D.new()
			(shape.shape as BoxShape3D).size = box.size * Vector3(0.7, 1.0, 0.9)
			shape.transform = spot * Transform3D(Basis(), box.get_center())
			add_child(shape)
		_add_multimesh(kind, spots, Vector3.ZERO, null, 0.0)


## Open, gentle ground above the river: where grass, stumps and logs go.
func _grassy(i: int, j: int) -> bool:
	return _shape.map_data[j * _shape.map_width + i] >= -0.3 and _normal(i, j).y >= ROCK_NORMAL_Y


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
			colors.append(ROCK if normal.y < ROCK_NORMAL_Y else (MUD if h < -0.3 else GRASS))
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
