extends Node3D

## Things to gather, scattered over the map (issues #21, #26; owner 2026-11-22): grass tufts, daisies, berries,
## poisonous berries, mushrooms, feathers and sticks, plus hopping frogs and crawling grubs. Counts are random
## per map load. Still things are merged into one mesh per 40 m cell and material, drawn within RANGE metres;
## picking one up (find + remove) rebuilds that cell's mesh without it.

const Trunk = preload("res://game/presentation/hunt_map/props/trunk.gd")
const DIR := "res://assets/models/props/"
const CELL := 40.0
const RANGE := 60.0
## glb: [ground count, scale range]. Counts vary 0.6-1.4x per load; grass is by far the most common.
const GROUND := {
	"Grass_Tufts": [650, Vector2(0.5, 0.9)],
	"Daisies_6_Colors": [140, Vector2(0.5, 0.9)],
	"Berries_6_Colors": [90, Vector2(0.25, 0.4)],
	"Mushrooms": [80, Vector2(0.4, 0.8)],
	"Poisonous_Berries": [35, Vector2(0.35, 0.55)],
	"Feather": [70, Vector2(0.25, 0.55)],
}
## glb (or "frog", "grub") -> material id the find becomes in the pockets (shop_catalog.gd MATERIAL_NAMES).
const MATERIAL := {
	"Grass_Tufts": "grass", "Daisies_6_Colors": "daisy", "Berries_6_Colors": "berry", "Mushrooms": "mushroom",
	"Poisonous_Berries": "poison_berry", "Feather": "feather", "Sticks_3_Variants": "stick", "frog": "frog", "grub": "larva",
}
## Berries on a bush hang up to this high over the hunter's feet and can still be reached.
const REACH_UP := 2.5
const BERRIES_ON_SHRUBS := 70
const POISON_ON_SHRUBS := 15
const MUSHROOMS_ON_WOOD := 45
const STICKS := 140
const STICK_RING := Vector2(1.5, 5.0)
const FROGS := 12
const GRUBS := 18
const FROG_SCALE := 0.28
const GRUB_SCALE := 0.16
const FROG_ANIMS := ["Jump", "Jump_001", "Jump_002"]
const GRUB_ANIMS := ["Crawl", "Crawl_001"]
const Frog = preload("res://game/presentation/hunt_map/props/frog.gd")
const Grub = preload("res://game/presentation/hunt_map/props/grub.gd")

var _terrain: Node3D
var _rng := RandomNumberGenerator.new()
var _meshes := {}  # glb name -> Array[Mesh]
var _batches := {}  # [material group, cell] -> Array of [Mesh, Transform3D, material id]
var _nodes := {}  # same key -> its baked MeshInstance3D
var _critters: Array[Node3D] = []  # frogs and grubs, with meta "material"


## `hosts` holds [mesh, Transform3D] lists for "stumps", "logs", "trees" and "shrubs" the terrain placed;
## every count is times `amount`.
func populate(terrain: Node3D, hosts: Dictionary, amount := 1.0) -> void:
	_terrain = terrain
	_rng.randomize()
	for glb: String in GROUND:
		var range_: Vector2 = GROUND[glb][1]
		for _n in roundi(GROUND[glb][0] * _rng.randf_range(0.6, 1.4) * amount):
			var at: Variant = terrain.free_spot(_rng)
			if at != null:
				_still(glb, at, range_)
	for _n in roundi(BERRIES_ON_SHRUBS * _rng.randf_range(0.6, 1.4) * amount):
		_on_shrub("Berries_6_Colors", hosts.shrubs)
	for _n in roundi(POISON_ON_SHRUBS * _rng.randf_range(0.6, 1.4) * amount):
		_on_shrub("Poisonous_Berries", hosts.shrubs)
	var wood: Array = hosts.stumps + hosts.logs
	for _n in roundi(MUSHROOMS_ON_WOOD * _rng.randf_range(0.6, 1.4) * amount):
		_still("Mushrooms", _wood_top(wood), Vector2(0.3, 0.6))
	for _n in roundi(STICKS * _rng.randf_range(0.6, 1.4) * amount):
		var tree: Array = hosts.trees[_rng.randi() % hosts.trees.size()]
		var at: Vector3 = (tree[1] as Transform3D).origin + _ring(_rng.randf_range(STICK_RING.x, STICK_RING.y))
		if terrain.grassy_at(at.x, at.z):
			at.y = terrain.height_at(at.x, at.z)
			_still("Sticks_3_Variants", at, Vector2(0.4, 0.9))
	_bake()
	for _n in roundi(FROGS * amount):
		var at: Variant = terrain.free_spot(_rng)
		if at != null:
			_frog(at)
	for _n in roundi(GRUBS * amount):
		_grub(wood, hosts.trees)


func _still(glb: String, at: Vector3, scale_range: Vector2, tilt := 0.0) -> void:
	var meshes := _load_meshes(glb)
	var tilt_basis := Basis.from_euler(Vector3(_rng.randf_range(-tilt, tilt), _rng.randf() * TAU, _rng.randf_range(-tilt, tilt)))
	var spot := Transform3D(tilt_basis.scaled(Vector3.ONE * _rng.randf_range(scale_range.x, scale_range.y)), at - Vector3.UP * 0.02)
	var key := ["poison" if glb == "Poisonous_Berries" else "atlas", Vector2i(floori(at.x / CELL), floori(at.z / CELL))]
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append([meshes[_rng.randi() % meshes.size()], spot, MATERIAL[glb]])


## Berries hang on the outside of a bush, in its upper two thirds.
func _on_shrub(glb: String, shrubs: Array) -> void:
	var shrub: Array = shrubs[_rng.randi() % shrubs.size()]
	var box := (shrub[0] as Mesh).get_aabb()
	var angle := _rng.randf() * TAU
	var local := box.get_center() + Vector3(cos(angle) * box.size.x * 0.4, _rng.randf_range(0.3, 0.8) * box.size.y - box.size.y * 0.5, sin(angle) * box.size.z * 0.4)
	_still(glb, (shrub[1] as Transform3D) * local, Vector2(0.25, 0.4))


## A random point on the top of a stump or log.
func _wood_top(wood: Array) -> Vector3:
	var host: Array = wood[_rng.randi() % wood.size()]
	var box := (host[0] as Mesh).get_aabb()
	var along := 0 if box.size.x > box.size.z else 2  # a log lies along its longer horizontal side
	var local := box.get_center()
	local[along] += _rng.randf_range(-0.35, 0.35) * box.size[along]
	local.y = box.end.y * 0.95
	return (host[1] as Transform3D) * local


func _load_meshes(glb: String) -> Array:
	if not _meshes.has(glb):
		var scene: Node = load(DIR + glb + ".glb").instantiate()
		_meshes[glb] = scene.find_children("*", "MeshInstance3D", true, false).map(func(m: Node) -> Mesh: return (m as MeshInstance3D).mesh)
		scene.free()
	return _meshes[glb]


## The find nearest to `near` (global) within `reach` metres across, or {} when there is none:
## {"material", "node"} for a frog or grub, {"material", "key", "index"} for a still thing.
func find(near: Vector3, reach: float) -> Dictionary:
	var at := to_local(near)
	var best := {}
	var best_d := reach
	for critter in _critters:
		var d := _flat_distance(critter.position, at)
		if d < best_d:
			best_d = d
			best = {"material": critter.get_meta("material"), "node": critter}
	var cell := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	for key: Array in _batches:
		if absi(key[1].x - cell.x) > 1 or absi(key[1].y - cell.y) > 1:
			continue
		var items: Array = _batches[key]
		for i in items.size():
			var d := _flat_distance((items[i][1] as Transform3D).origin, at)
			if d < best_d:
				best_d = d
				best = {"material": items[i][2], "key": key, "index": i}
	return best


## Takes a find returned by find() off the map.
func remove(found: Dictionary) -> void:
	if found.has("node"):
		_critters.erase(found["node"])
		found["node"].queue_free()
		return
	_batches[found["key"]].remove_at(found["index"])
	_bake_cell(found["key"])


func _flat_distance(p: Vector3, at: Vector3) -> float:
	return INF if p.y - at.y > REACH_UP or at.y - p.y > 1.0 else Vector2(p.x - at.x, p.z - at.z).length()


func _bake() -> void:
	for key: Array in _batches:
		_bake_cell(key)


func _bake_cell(key: Array) -> void:
	if _nodes.has(key):
		_nodes[key].queue_free()
		_nodes.erase(key)
	if _batches[key].is_empty():
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item: Array in _batches[key]:
		tool.append_from(item[0], 0, item[1])
	tool.set_material((_batches[key][0][0] as Mesh).surface_get_material(0))
	var node := MeshInstance3D.new()
	node.mesh = tool.commit()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = RANGE
	add_child(node)
	_nodes[key] = node


## A rigged model with only variant `n` of its rigs left, its animation `anim` ready on the returned player.
func _variant(glb: String, n: int, anim_names: Array, scale_: float) -> Array:
	var model: Node3D = load(DIR + glb + ".glb").instantiate()
	var rigs := model.get_children().filter(func(c: Node) -> bool: return c.name.ends_with("rig"))
	for i in rigs.size():
		if i != n:
			rigs[i].free()
	(rigs[n] as Node3D).position = Vector3.ZERO
	model.scale = Vector3.ONE * scale_
	model.rotation.y = PI  # the models face +Z; frog.gd and grub.gd walk along -Z
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = RANGE * 0.6
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [model, model.get_node("AnimationPlayer"), anim_names[n]]


func _frog(at: Vector3) -> void:
	var v := _variant("Frogs_3_Colors_Rigged", _rng.randi() % 3, FROG_ANIMS, FROG_SCALE)
	var frog := Frog.new()
	frog.terrain = _terrain
	frog.anim = v[1]
	frog.anim_name = v[2]
	frog.add_child(v[0])
	frog.set_meta("material", MATERIAL["frog"])
	_critters.append(frog)
	add_child(frog)
	frog.position = at
	frog.rotation.y = _rng.randf() * TAU


## A grub on a stump or log top (any heading), or low on a tree trunk (heading up).
func _grub(wood: Array, trees: Array) -> void:
	var v := _variant("Larvae_2_Variants_Rigged", _rng.randi() % 2, GRUB_ANIMS, GRUB_SCALE)
	(v[1] as AnimationPlayer).get_animation(v[2]).loop_mode = Animation.LOOP_LINEAR
	var grub := Grub.new()
	grub.anim = v[1]
	grub.anim_name = v[2]
	grub.add_child(v[0])
	grub.set_meta("material", MATERIAL["grub"])
	_critters.append(grub)
	add_child(grub)
	if _rng.randf() < 0.5:
		grub.position = _wood_top(wood)
		grub.rotation.y = _rng.randf() * TAU
	else:
		var tree: Array = trees[_rng.randi() % trees.size()]
		var spot: Transform3D = tree[1]
		var base := _trunk_base(tree[0])
		var out := _ring(1.0)
		var size := spot.basis.get_scale().x
		var foot := spot * Vector3(base.x, 0.0, base.z)
		grub.position = foot + out * base.y * size * 0.9 + Vector3.UP * _rng.randf_range(0.4, 1.4)
		grub.basis = Basis.looking_at(Vector3.UP, out)
	grub.home = grub.position


func _ring(radius: float) -> Vector3:
	var a := _rng.randf() * TAU
	return Vector3(cos(a), 0.0, sin(a)) * radius


func _trunk_base(mesh: Mesh) -> Vector3:
	if not _meshes.has(mesh):
		_meshes[mesh] = Trunk.base(mesh)
	return _meshes[mesh]
