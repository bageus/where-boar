extends Node3D

## A place in camp the hunter uses with E: start the hunt or open a shop.

@export var station_id := ""
@export var title := ""
@export var model: PackedScene = preload("res://assets/models/stall.glb")
## A building or pen the hunter cannot walk through: the collision is the model's own footprint.
@export var solid := false


func _ready() -> void:
	var node := model.instantiate()
	add_child(node)
	if solid:
		fit_collision($Body/Collision, node)
	$Label.text = "%s [E]" % title


## Sizes a box shape to the bounds of the model's meshes (in the model's own space).
static func fit_collision(collision: CollisionShape3D, model_root: Node3D) -> void:
	var box := AABB()
	for mesh: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		var local := mesh.transform * mesh.get_aabb()
		box = local if box.size == Vector3.ZERO else box.merge(local)
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	collision.position = box.get_center()
