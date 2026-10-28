extends Node3D

const Trunk = preload("res://game/presentation/hunt_map/props/trunk.gd")

## Shows one of several models (owner's nature pack, assets/nature/meshes), picked by the node's name
## so the map looks the same every run, with its own size and turn. A tree's collision moves to its trunk.

@export var meshes: Array[Mesh] = []
## Used instead when the node's name starts with "Jungle".
@export var jungle_meshes: Array[Mesh] = []
## Random target size in metres: height when fit_height, otherwise the larger footprint side.
@export var size_range := Vector2(1.0, 1.0)
@export var fit_height := true


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(name))
	var pool := jungle_meshes if String(name).begins_with("Jungle") and not jungle_meshes.is_empty() else meshes
	var mesh: Mesh = pool[rng.randi() % pool.size()]
	var box := mesh.get_aabb().size
	var size := rng.randf_range(size_range.x, size_range.y)
	$Mesh.mesh = mesh
	$Mesh.scale = Vector3.ONE * size / (box.y if fit_height else maxf(box.x, box.z))
	$Mesh.rotation.y = rng.randf() * TAU
	if has_node("Collision") and $Collision.shape is CylinderShape3D:  # a tree: its trunk
		var trunk := Trunk.base(mesh)
		var scale: float = $Mesh.scale.x
		$Collision.position += Basis(Vector3.UP, $Mesh.rotation.y) * Vector3(trunk.x, 0.0, trunk.z) * scale
		$Collision.shape = $Collision.shape.duplicate()  # the scene's shape is shared by every tree
		$Collision.shape.radius = maxf(0.35, trunk.y * scale)
