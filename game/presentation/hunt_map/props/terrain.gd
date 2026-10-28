@tool
extends StaticBody3D

## Green Valley ground (D039): one smooth height map with hills, a mesa, a cliff over the river and hollows.
## The heights are baked by tools/bake_green_valley.py; the visible surface is drawn from the same data.

const GRASS := Color(0.28, 0.58, 0.2)
const ROCK := Color(0.58, 0.52, 0.42)
const MUD := Color(0.5, 0.36, 0.2)
## Slopes steeper than this (normal.y below it, about 40 degrees) look like bare rock.
const ROCK_NORMAL_Y := 0.75

@onready var _shape: HeightMapShape3D = $Collision.shape


func _ready() -> void:
	$Mesh.mesh = _build_mesh()


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
