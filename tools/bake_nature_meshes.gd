extends SceneTree

## Bakes the owner's nature models (assets/nature/source: fbx, glb, obj) into plain meshes in
## assets/nature/meshes: one ArrayMesh per model, origin at the bottom centre, flat colours.
## The fbx textures are single colours, so each material takes its texture's colour.
## Run: godot --headless --path . -s res://tools/bake_nature_meshes.gd

const SOURCE := "res://assets/nature/source/"
const OUT := "res://assets/nature/meshes/"
## Material name fragment -> colour, for materials without a texture of the same name.
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
	for dir in ["rocks", "trees", "palms", "props"]:
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
	for pair in meshes:
		var mesh: Mesh = pair[0]
		for i in mesh.get_surface_count():
			tool.clear()
			tool.append_from(mesh, i, shift * pair[1])
			var arrays := tool.commit_to_arrays()
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, _material(mesh, i, arrays[Mesh.ARRAY_COLOR] != null))
	var name := path.get_file().get_basename()
	ResourceSaver.save(out, OUT + name + ".res", ResourceSaver.FLAG_COMPRESS)
	print("%s: %d surfaces, %d triangles, size %s" % [name, out.get_surface_count(), out.get_faces().size() / 3, out.get_aabb().size])


func _material(mesh: Mesh, surface: int, has_colors: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.95
	if has_colors:
		mat.vertex_color_use_as_albedo = true
		return mat
	# An obj without its .mtl keeps the material name only as the surface name.
	var source := mesh.surface_get_material(surface)
	var name := source.resource_name if source else (mesh as ArrayMesh).surface_get_name(surface)
	var texture := "res://assets/nature/source/trees/%s.png" % name
	if ResourceLoader.exists(texture):
		mat.albedo_color = (load(texture) as Texture2D).get_image().get_pixel(4, 4)
	else:
		for key in COLOURS:
			if name.contains(key):
				mat.albedo_color = COLOURS[key]
	mat.resource_name = name
	return mat
