extends Node3D

## Camp dressing (owner, 2026-10-28): grass along the fence, small rocks and a ring of trees beyond it.

const TREES_MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/OakTree1.res"), preload("res://assets/nature/meshes/OakTree2.res"),
	preload("res://assets/nature/meshes/OakTree3.res"), preload("res://assets/nature/meshes/SpruceTree1.res"),
	preload("res://assets/nature/meshes/SpruceTree2.res"), preload("res://assets/nature/meshes/SpruceTree3.res"),
]
const ROCK_MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/Rock1.res"), preload("res://assets/nature/meshes/Rock2.res"),
	preload("res://assets/nature/meshes/Rock3.res"), preload("res://assets/nature/meshes/Rock4.res"),
	preload("res://assets/nature/meshes/Rock5.res"),
]
const GRASS_MESH := preload("res://assets/grass/grass.glb")
const GRASS_MATERIAL := preload("res://assets/grass/grass_material.tres")
const HALF := 20.0  # the fence
const OUTSIDE := 60.0
const TREE_COUNT := 70
const ROCKS_INSIDE := 14
const ROCKS_OUTSIDE := 30
const GRASS_INSIDE := 2200
const GRASS_OUTSIDE := 6000


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_lawn()
	for n in TREE_COUNT:
		_prop(rng, TREES_MESHES, _ring(rng, HALF + 3.0, OUTSIDE - 5.0), Vector2(7, 11), true)
	for n in ROCKS_OUTSIDE:
		_prop(rng, ROCK_MESHES, _ring(rng, HALF + 1.5, OUTSIDE - 5.0), Vector2(0.6, 1.4), false)
	for n in ROCKS_INSIDE:
		_prop(rng, ROCK_MESHES, _ring(rng, HALF - 3.5, HALF - 1.0), Vector2(0.5, 1.0), false)
	_grass(rng, GRASS_INSIDE, HALF - 3.5, HALF - 0.6)
	_grass(rng, GRASS_OUTSIDE, HALF + 0.6, OUTSIDE)


## A point in the square band between two half-widths (the camp is a square).
func _ring(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	while true:
		var p := Vector3(rng.randf_range(-outer, outer), 0.0, rng.randf_range(-outer, outer))
		if maxf(absf(p.x), absf(p.z)) > inner:
			return p
	return Vector3.ZERO


## shortcut: scenery has no collision (trees stand beyond the fence); add hulls if rocks must block.
func _prop(rng: RandomNumberGenerator, pool: Array[Mesh], at: Vector3, size: Vector2, by_height: bool) -> void:
	var mesh: Mesh = pool[rng.randi() % pool.size()]
	var box := mesh.get_aabb()
	var k := rng.randf_range(size.x, size.y) / (box.size.y if by_height else maxf(box.size.x, box.size.z))
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = Vector3.ONE * k
	node.rotation.y = rng.randf() * TAU
	node.position = at + Vector3(0.0, -box.position.y * k - 0.1 * k, 0.0)
	add_child(node)


## Green ground beyond the dirt square.
func _lawn() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * OUTSIDE * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.4, 0.1)
	mesh.material = material
	var lawn := MeshInstance3D.new()
	lawn.mesh = mesh
	lawn.position.y = -0.03
	add_child(lawn)


func _grass(rng: RandomNumberGenerator, count: int, inner: float, outer: float) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = (GRASS_MESH.instantiate().get_child(0) as MeshInstance3D).mesh
	multimesh.instance_count = count
	for n in count:
		var size := rng.randf_range(0.4, 0.9)
		multimesh.set_instance_transform(n, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), _ring(rng, inner, outer)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = GRASS_MATERIAL
	add_child(node)
