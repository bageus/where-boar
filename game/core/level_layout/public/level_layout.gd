extends RefCounted

## A level's planned layout (planning mode, issue #29), kept as JSON-ready data:
## {"moved": {node_path: transform}, "removed": [node_path], "added": [{name, parent, res, t, solid}]}.
## Paths are relative to the level root; a transform is 12 floats (basis columns, then origin).
## res is a PackedScene (instanced) or a Mesh (shown in a StaticBody3D; solid "box" or "trunk" gives it a collision).

const ADDED_META := "layout_added"
## Nature models planning mode can add on any level: file prefix -> [count, solid].
const NATURE := {
	"PeakTree": [4, "trunk"], "PeakPine": [3, "trunk"], "PeakDead": [2, "trunk"], "PeakPalm": [3, "trunk"],
	"PeakBush": [3, ""], "PeakShrub": [3, ""], "PeakRock": [8, "box"], "PeakCliff": [5, "box"],
	"PeakSpire": [3, "box"], "PeakStump": [1, "box"], "PeakLog": [4, "box"],
}
## Planning palette tab of each nature model (planner.gd TABS).
const NATURE_TAB := {
	"PeakTree": "trees", "PeakPine": "trees", "PeakDead": "trees", "PeakPalm": "trees", "PeakBush": "trees", "PeakShrub": "trees",
	"PeakRock": "stones", "PeakCliff": "stones", "PeakSpire": "stones", "PeakStump": "landscape", "PeakLog": "landscape",
}
const NATURE_DIR := "res://assets/nature/meshes/peak/"
## Original transform of an authored node, kept so only real moves are saved.
const START_META := "layout_start"


static func to_array(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
			t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


static func from_array(a: Array) -> Transform3D:
	return Transform3D(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]), Vector3(a[9], a[10], a[11]))


## Applies data to the level under root: call first thing in the level's _ready, before it reads its props.
static func apply(root: Node, data: Dictionary) -> void:
	for path: String in data.get("removed", []):
		var gone := root.get_node_or_null(path)
		if gone:
			gone.get_parent().remove_child(gone)
			gone.free()
	var moved: Dictionary = data.get("moved", {})
	for path: String in moved:
		var node := root.get_node_or_null(path) as Node3D
		if node:
			node.set_meta(START_META, node.transform)
			node.transform = from_array(moved[path])
	for entry: Dictionary in data.get("added", []):
		var parent := root.get_node_or_null(entry.get("parent", "."))
		var node := make(entry.get("res", ""), entry.get("solid", ""))
		if parent == null or node == null:
			continue
		node.name = entry.get("name", "Added")
		node.transform = from_array(entry["t"])
		parent.add_child(node)


## Palette entries {name, res, solid} for the shared nature models and tall-grass wheat.
static func nature_palette() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for prefix: String in NATURE:
		for n in NATURE[prefix][0]:
			entries.append({"name": "%s %d" % [prefix.trim_prefix("Peak"), n + 1], "res": "%s%s%d.res" % [NATURE_DIR, prefix, n + 1],
					"solid": NATURE[prefix][1], "tab": NATURE_TAB[prefix]})
	entries.append({"name": "Tall grass (wheat)", "res": "res://assets/nature/meshes/Wheat.res", "solid": "", "tab": "grass"})
	return entries


## A new object from a scene or mesh path, marked as added; null if the path does not load.
static func make(res: String, solid: String) -> Node3D:
	var loaded: Resource = load(res) if ResourceLoader.exists(res) else null
	var node: Node3D
	if loaded is PackedScene:
		node = (loaded as PackedScene).instantiate() as Node3D
	elif loaded is Mesh:
		node = StaticBody3D.new()
		var mesh := MeshInstance3D.new()
		mesh.mesh = loaded
		node.add_child(mesh)
		var box := (loaded as Mesh).get_aabb()
		var shape := CollisionShape3D.new()
		if solid == "box":
			shape.shape = BoxShape3D.new()
			(shape.shape as BoxShape3D).size = box.size * Vector3(0.7, 1.0, 0.7)
			shape.position = box.get_center()
		elif solid == "trunk":  # shortcut: a trunk in the model's middle; off-centre trunks (palms) need Trunk.base
			shape.shape = CylinderShape3D.new()
			(shape.shape as CylinderShape3D).radius = 0.4
			shape.position = Vector3(box.get_center().x, 1.0, box.get_center().z)
		if shape.shape:
			node.add_child(shape)
		else:
			shape.free()
	if node == null:
		return null
	node.set_meta(ADDED_META, {"res": res, "solid": solid})
	return node


## Layout data for the current state of editable nodes under root; removed lists the paths deleted so far.
static func capture(root: Node, editable: Array, removed: Array) -> Dictionary:
	var moved := {}
	var added := []
	for node: Node3D in editable:
		if not is_instance_valid(node) or not root.is_ancestor_of(node):
			continue
		if node.has_meta(ADDED_META):
			var info: Dictionary = node.get_meta(ADDED_META)
			added.append({"name": String(node.name), "parent": String(root.get_path_to(node.get_parent())),
					"res": info["res"], "solid": info["solid"], "t": to_array(node.transform)})
		elif node.has_meta(START_META) and not (node.get_meta(START_META) as Transform3D).is_equal_approx(node.transform):
			moved[String(root.get_path_to(node))] = to_array(node.transform)
	return {"moved": moved, "removed": removed.duplicate(), "added": added}
