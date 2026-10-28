extends SceneTree

## Bakes the owner's nature models (assets/nature/source: fbx, glb, obj) into plain meshes in
## assets/nature/meshes: one ArrayMesh per model, origin at the bottom centre, flat colours.
## Trees, logs, stumps and ferns share one bark and leaf palette, so every tree looks like one set.
## Run: godot --headless --path . -s res://tools/bake_nature_meshes.gd

const SOURCE := "res://assets/nature/source/"
const OUT := "res://assets/nature/meshes/"
const BARK := Color(0.42, 0.28, 0.16)
const LEAF := Color(0.36, 0.6, 0.2)
const NEEDLE := Color(0.2, 0.42, 0.2)
## Material name fragment -> colour for the rest.
const COLOURS := {
	"Rock": Color(0.44, 0.44, 0.44),
	"Wood": Color(0.45, 0.3, 0.17),
	"Moss": Color(0.3, 0.5, 0.18),
	"Yellow": Color(0.85, 0.7, 0.3),
	"Green": Color(0.4, 0.6, 0.2),
	"Mushroom_Top": Color(0.8, 0.2, 0.15),
	"Mushroom_Bottom": Color(0.95, 0.9, 0.8),
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for dir in ["rocks", "trees", "palms", "props", "ferns"]:
		for file in DirAccess.get_files_at(SOURCE + dir):
			if file.get_extension() in ["fbx", "glb", "obj"]:
				_bake(SOURCE + dir + "/" + file)
	quit()


func _bake(path: String) -> void:
	var tool := SurfaceTool.new()
	var meshes: Array = []
	var res := load(path)
	if res is Mesh:
		meshes.append([res, Transform3D.IDENTITY])
	else:
		var root: Node3D = res.instantiate()
		for node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != root:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			meshes.append([mi.mesh, xf])
		root.free()
	var out := ArrayMesh.new()
	var bounds := AABB()
	var first := true
	for pair in meshes:
		var box: AABB = pair[1] * (pair[0] as Mesh).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	# Bottom centre to the origin.
	var shift := Transform3D(Basis(), -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z))
	# Surfaces of the same colour merge into one, so a model costs one draw call per colour.
	var groups := {}
	for pair in meshes:
		var mesh: Mesh = pair[0]
		for i in mesh.get_surface_count():
			var key = "vc" if mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR else _colour(mesh, i)
			if not groups.has(key):
				groups[key] = SurfaceTool.new()
			(groups[key] as SurfaceTool).append_from(mesh, i, shift * pair[1])
	for key in groups:
		var arrays := (groups[key] as SurfaceTool).commit_to_arrays()
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.95
		if key is String:
			mat.vertex_color_use_as_albedo = true
			arrays[Mesh.ARRAY_COLOR] = _unify(arrays[Mesh.ARRAY_COLOR])
		else:
			mat.albedo_color = key
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mat)
	var name := path.get_file().get_basename()
	ResourceSaver.save(out, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	print("%s: %d surfaces, %d triangles, size %s" % [name, out.get_surface_count(), out.get_faces().size() / 3, out.get_aabb().size])


## One palette for every tree, log, stump and fern (owner, 2026-10-28: one style); other parts by material name.
func _colour(mesh: Mesh, surface: int) -> Color:
	# An obj without its .mtl keeps the material name only as the surface name.
	var source := mesh.surface_get_material(surface)
	var name := source.resource_name if source else (mesh as ArrayMesh).surface_get_name(surface)
	if name.contains("Spruce") and name.contains("Leaf"):
		return NEEDLE
	if name.contains("Leaf") or name.begins_with("Green"):
		return LEAF
	if name.contains("Trunk") or name.contains("Wood") or name.begins_with("Brown"):
		return BARK
	for key in COLOURS:
		if name.contains(key):
			return COLOURS[key]
	return Color.WHITE


## Vertex-coloured models (palms, ferns): greens become LEAF and browns BARK, keeping their light and shade.
func _unify(colors: PackedColorArray) -> PackedColorArray:
	for n in colors.size():
		var c := colors[n]
		var green := c.g > c.r * 1.1
		colors[n] = (LEAF if green else BARK) * clampf(c.get_luminance() / (0.4 if green else 0.3), 0.75, 1.2)
		colors[n].a = 1.0
	return colors
