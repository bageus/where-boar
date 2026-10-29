extends Node3D

## The hunter's body, seen only through its shadow (owner, 2026-10-29: the hunter cast no shadow on
## the buildings): a caveman that never renders but casts a shadow, playing idle, walk, run, sneak or
## ride to match its parent hunter. Child of the hunter; reads its parent.

const Caveman = preload("res://assets/models/caveman_skinny.glb")
const Backpack = preload("res://assets/models/primitive_backpack_optimized.glb")
## Where the backpack sits on the caveman, in the model's space (it faces +z, the back is -z).
const BACKPACK_PLACE := Transform3D(Basis.IDENTITY * 0.6, Vector3(0.0, 0.9, -0.26))
const RUN_SPEED := 5.0  # between the hunter's walk and sprint speeds
const MOVING_SPEED := 0.3

var _player: AnimationPlayer
var _body: Node3D

@onready var _hunter: CharacterBody3D = get_parent()


func _ready() -> void:
	_body = Caveman.instantiate()
	_body.rotation.y = PI  # the model faces +z, the hunter looks along -z
	add_child(_body)
	_shadow_only(_body)
	_player = _body.find_child("AnimationPlayer") as AnimationPlayer
	_player.animation_finished.connect(func(anim: StringName) -> void: _player.play(anim))


func _process(_delta: float) -> void:
	var speed := Vector2(_hunter.velocity.x, _hunter.velocity.z).length()
	var anim := "idle"
	if _hunter.ride.is_riding():
		anim = "ride"
	elif speed > MOVING_SPEED:
		anim = "sneak" if _hunter.crouching else ("run" if speed > RUN_SPEED else "walk")
	if _player.current_animation != anim:
		_player.play(anim, 0.2)


## On the hunt the hunter always carries the backpack (owner, 2026-10-29): it rides on the chest bone.
func wear_backpack() -> void:
	var skeleton: Skeleton3D = _body.find_child("Skeleton3D") as Skeleton3D
	var mount := BoneAttachment3D.new()
	mount.bone_name = "chest"
	skeleton.add_child(mount)
	var pack: Node3D = Backpack.instantiate()
	pack.transform = skeleton.get_bone_global_rest(skeleton.find_bone("chest")).affine_inverse() * BACKPACK_PLACE
	mount.add_child(pack)
	_shadow_only(pack)


func _shadow_only(model: Node3D) -> void:
	for mesh: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
