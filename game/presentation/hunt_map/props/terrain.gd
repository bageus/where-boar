@tool
extends StaticBody3D

## Green Valley ground (D039): one smooth height map with hills, a mesa, a cliff over the river and hollows.
## The heights are baked by tools/bake_green_valley.py; the visible surface is drawn from the same data.

const GRASS := Color(0.16, 0.4, 0.1)
const ROCK := Color(0.58, 0.52, 0.42)
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

@onready var _shape: HeightMapShape3D = $Collision.shape


func _ready() -> void:
	$Mesh.mesh = _build_mesh()
	_plant_grass()


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
	var data := _shape.map_data
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for cj in range(0, d - 1, GRASS_CHUNK):
		for ci in range(0, w - 1, GRASS_CHUNK):
			# Visibility range counts from the node's origin, so each chunk sits at its centre.
			var centre := Vector3(ci + GRASS_CHUNK * 0.5 - (w - 1) * 0.5, 0.0, cj + GRASS_CHUNK * 0.5 - (d - 1) * 0.5)
			var spots: Array[Transform3D] = []
			for j in range(cj, mini(cj + GRASS_CHUNK, d - 1)):
				for i in range(ci, mini(ci + GRASS_CHUNK, w - 1)):
					var h := data[j * w + i]
					var rise := maxf(absf(data[j * w + i + 1] - h), absf(data[(j + 1) * w + i] - h))
					if h < -0.3 or Vector3(rise, 1.0, 0.0).normalized().y < ROCK_NORMAL_Y:
						continue
					for k in GRASS_PER_METRE:
						var x := i + rng.randf() - (w - 1) * 0.5
						var z := j + rng.randf() - (d - 1) * 0.5
						var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.35, 0.45))
						spots.append(Transform3D(basis, Vector3(x, height_at(x, z) - 0.05, z) - centre))
			if spots.is_empty():
				continue
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = clump
			multimesh.instance_count = spots.size()
			for n in spots.size():
				multimesh.set_instance_transform(n, spots[n])
			var chunk := MultiMeshInstance3D.new()
			chunk.multimesh = multimesh
			chunk.position = centre
			chunk.material_override = GRASS_MATERIAL
			chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			chunk.visibility_range_end = GRASS_RANGE
			chunk.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(chunk)


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
			var dx := data[j * w + mini(i + 1, w - 1)] - data[j * w + maxi(i - 1, 0)]
			var dz := data[mini(j + 1, d - 1) * w + i] - data[maxi(j - 1, 0) * w + i]
			var normal := Vector3(-dx, 2.0, -dz).normalized()
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
