extends SceneTree

## Merges every mesh of a camp building into one mesh with one surface per material, so a building
## costs a few draw calls instead of hundreds. Writes assets/models/merged/<name>.scn (same
## geometry, materials and textures as the source glb). Run after the source glb changes:
##   godot --headless --path . -s res://tools/merge_camp_models.gd

const MODELS := ["weapon_stall", "hunter_stall", "cage_rack", "campfire", "tavern", "aframe_hide_tent",
		"large_hide_tent", "round_hide_tent", "boar_pen", "tribal_well", "direction_sign"]
const OUT := "res://assets/models/merged/"
## Greenery baked into the owner's models is left out (owner, 2026-10-30), and so is the sand blob under
## the tavern, pens and cages: its top lies exactly on the camp ground and z-fights with it.
const SKIPPED_MATERIALS := "Leaf green"
const SKIPPED_NODES := "Sandy island"


func _init() -> void:
	for name: String in MODELS:
		_merge(name)
	quit()


func _merge(name: String) -> void:
	var root: Node = (load("res://assets/models/%s.glb" % name) as PackedScene).instantiate()
	var tools := {}  # material -> SurfaceTool
	var before := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.get_active_material(0).resource_name.begins_with(SKIPPED_MATERIALS) or mi.name.begins_with(SKIPPED_NODES):
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for i in mi.mesh.get_surface_count():
			before += 1
			var mat := mi.get_active_material(i)
			if not tools.has(mat):
				tools[mat] = SurfaceTool.new()
			(tools[mat] as SurfaceTool).append_from(mi.mesh, i, xf)
	var mesh := ArrayMesh.new()
	for mat in tools:
		(tools[mat] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var out := Node3D.new()
	out.name = name.to_pascal_case()
	var node := MeshInstance3D.new()
	node.name = "Mesh"
	node.mesh = mesh
	out.add_child(node)
	node.owner = out
	var scene := PackedScene.new()
	scene.pack(out)
	ResourceSaver.save(scene, OUT + name + ".scn", ResourceSaver.FLAG_COMPRESS)
	print("%s: %d surfaces -> %d, %d triangles" % [name, before, mesh.get_surface_count(), mesh.get_faces().size() / 3])
	root.free()
	out.free()
