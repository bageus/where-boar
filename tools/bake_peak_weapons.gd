extends SceneTree

## Bakes the sling stone in the style of the game PEAK (owner, 2026-11-02), to match the rocks and trees
## (bake_peak_rocks.gd, bake_peak_trees.gd): a faceted lump, flat shaded, bright vertex colours, saved as a mesh
## and a small scene (root Node3D + MeshInstance3D "Model") used by stone.tscn, the stone pile and the slingshot.
## The weapons themselves are the owner's models in assets/models/weapon_new/ since 2026-11-23.
## Run: godot --headless --path . -s res://tools/bake_peak_weapons.gd

const PeakSmooth := preload("res://tools/peak_smooth.gd")
const OUT := "res://assets/models/peak_weapons/"
const STONE := Color(0.6, 0.6, 0.62)
const STONE_LIGHT := Color(0.74, 0.73, 0.72)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_save(_stone(), "stone")
	quit()


## A faceted pebble, bottom at the origin, about the size of the old stone.glb (0.23 x 0.18 x 0.22).
func _stone() -> SurfaceTool:
	var t := _tool()
	_lump(t, Vector3(0, 0.09, 0), Vector3(0.115, 0.09, 0.11), STONE, STONE_LIGHT, 3)
	return t


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


## A chunky faceted lump (club head, pouch, pebble): an octahedron-based sphere, jittered, darker below.
func _lump(t: SurfaceTool, centre: Vector3, r: Vector3, low: Color, high: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Jitter each distinct position once so shared corners stay shared.
	var moved := {}
	for v in verts:
		var key := v.snapped(Vector3.ONE * 0.001)
		if not moved.has(key):
			moved[key] = v * rng.randf_range(0.85, 1.1)
	for n in range(0, index.size(), 3):
		var p: Array[Vector3] = []
		for m in 3:
			var v: Vector3 = moved[verts[index[n + m]].snapped(Vector3.ONE * 0.001)]
			p.append(centre + Vector3(v.x / 0.5 * r.x, v.y / 0.5 * r.y, v.z / 0.5 * r.z))
		var up := ((p[0] + p[1] + p[2]) / 3.0 - centre).normalized().y
		var colour := low.lerp(high, clampf(up * 0.5 + 0.5, 0.0, 1.0))
		if (p[0] - p[1]).length() < 0.0001 or (p[1] - p[2]).length() < 0.0001 or (p[0] - p[2]).length() < 0.0001:
			continue
		_tri(t, p[0], p[2], p[1], colour)


func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return PeakSmooth.soften(mat)


func _save(t: SurfaceTool, weapon: String) -> void:
	t.index()
	var mesh := t.commit()
	mesh.surface_set_material(0, _material())
	mesh = PeakSmooth.smooth(mesh)
	var mesh_path := OUT + weapon + ".res"
	ResourceSaver.save(mesh, mesh_path)
	mesh.take_over_path(mesh_path)
	var root := Node3D.new()
	root.name = weapon.capitalize()
	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = mesh
	root.add_child(model)
	model.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, OUT + weapon + ".tscn")
	root.free()
	print("baked ", weapon, ": ", mesh.surface_get_array_index_len(0) / 3, " triangles")
