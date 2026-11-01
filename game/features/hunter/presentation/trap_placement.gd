extends RefCounted

## Trap placement mode (owner, 2026-11-01): T shows a see-through copy of the trap ahead of the hunter,
## green where it can go and red where it overlaps a tree, stump, rock or any other solid object;
## Q and R turn it, the left mouse button puts it down (as a ghost to be built), T again cancels.

const STEP := deg_to_rad(15.0)
## How far ahead of the hunter the preview floats, metres.
const DISTANCE := 3.0
const OK_COLOR := Color(0.2, 1.0, 0.25, 0.45)
const BAD_COLOR := Color(1.0, 0.2, 0.15, 0.45)
const PREVIEW_TRANSPARENCY := 0.5
## Solid objects (terrain props) live on physics layer 1 together with the ground.
const SOLID_MASK := 1

## item_id -> footprint: shape, its offset from the trap origin, and how far from the origin the
## builder may stand (metres, to the nearest edge) - the helper builds from any side, not from the middle.
const FOOTPRINTS := {
	"item_pit": {"shape": "cylinder", "size": Vector3(1.35, 1.0, 0.0), "offset": Vector3(0, 0.6, 0), "reach": 1.35},
	"item_snare": {"shape": "cylinder", "size": Vector3(0.7, 1.0, 0.0), "offset": Vector3(0, 0.6, 0), "reach": 0.7},
	"item_tripwire": {"shape": "box", "size": Vector3(3.0, 0.6, 0.3), "offset": Vector3(0, 0.5, 0), "reach": 1.5},
	"item_cage": {"shape": "box", "size": Vector3(2.4, 1.2, 2.3), "offset": Vector3(0, 0.8, 0.03), "reach": 1.4},
	"item_fence": {"shape": "box", "size": Vector3(4.0, 1.2, 0.4), "offset": Vector3(0, 0.8, 0), "reach": 2.0},
}

## The left mouse button was pressed on a free spot.
signal confirmed(where: Transform3D)

var item_id := ""
var valid := false
var turn := 0.0
var _preview: Node3D
var _overlay := StandardMaterial3D.new()
var _shape: Shape3D
var _offset: Vector3


## How far from the origin of a trap its builders may stand and still reach it.
static func reach(id: String) -> float:
	return FOOTPRINTS[id]["reach"]


## A real trap of the given type at where (on the ground), a child of the hunter.
static func spawn(hunter: Node3D, scene: PackedScene, id: String, where: Transform3D) -> Node3D:
	var trap: Node3D = scene.instantiate()
	trap.top_level = true
	trap.add_to_group(hunter.PLACED_TRAPS_GROUP)
	trap.set_meta("item_id", id)
	trap.transform = Transform3D(where.basis, hunter.ground_at(where.origin))  # before add_child, so _ready sees it
	hunter.add_child(trap)
	# The trap models are painted with vertex colours, which the glTF import leaves unused.
	for mesh: MeshInstance3D in trap.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			(mesh.mesh.surface_get_material(i) as BaseMaterial3D).vertex_color_use_as_albedo = true
	return trap


func begin(hunter: Node3D, scene: PackedScene, id: String) -> void:
	item_id = id
	turn = 0.0
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview = scene.instantiate()
	_preview.top_level = true
	for body: CollisionObject3D in _preview.find_children("*", "CollisionObject3D", true, false) + [_preview]:
		body.collision_layer = 0
		body.collision_mask = 0
	for label: Label3D in _preview.find_children("*", "Label3D", true, false):
		label.visible = false
	for mesh: GeometryInstance3D in _preview.find_children("*", "GeometryInstance3D", true, false):
		mesh.transparency = PREVIEW_TRANSPARENCY
		mesh.material_overlay = _overlay
	hunter.add_child(_preview)
	var footprint: Dictionary = FOOTPRINTS[id]
	var size: Vector3 = footprint["size"]
	if footprint["shape"] == "cylinder":
		_shape = CylinderShape3D.new()
		_shape.radius = size.x
		_shape.height = size.y
	else:
		_shape = BoxShape3D.new()
		_shape.size = size
	_offset = footprint["offset"]


## Q and R turn the preview, the left mouse button confirms it; true when the event was used up here
## (so the click does not also swing a weapon).
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("drink", true):
		turn -= STEP
	elif event.is_action_pressed("shout", true):
		turn += STEP
	elif event.is_action_pressed("attack"):
		if valid:
			confirmed.emit(_preview.global_transform)
	else:
		return event.is_action("attack")
	return true


## Where the trap would go, facing the hunter's way turned by Q and R.
func transform_for(hunter: Node3D) -> Transform3D:
	var basis := Basis(Vector3.UP, turn) * hunter.global_basis
	return Transform3D(basis, hunter.ground_at(hunter.global_position - hunter.global_basis.z * DISTANCE))


## Moves the preview with the hunter and colours it by whether the spot is free.
func update(hunter: Node3D) -> void:
	_preview.global_transform = transform_for(hunter)
	valid = _is_free(hunter, _preview.global_transform)
	_overlay.albedo_color = OK_COLOR if valid else BAD_COLOR


func end() -> void:
	_preview.queue_free()
	_preview = null


## False when the footprint touches a tree, stump, rock or anything else that cannot be walked through.
func _is_free(hunter: Node3D, at: Transform3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = at * Transform3D(Basis.IDENTITY, _offset)
	query.collision_mask = SOLID_MASK
	query.exclude = [hunter.get_rid()]
	for hit: Dictionary in hunter.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := hit["collider"] as CollisionObject3D
		if body == null or body is CharacterBody3D:
			continue
		var owner_node := body.shape_owner_get_owner(body.shape_find_owner(hit["shape"])) as CollisionShape3D
		if owner_node and owner_node.shape is HeightMapShape3D:  # the ground itself
			continue
		return false
	return true
