extends Node3D

## The hunter's body, seen only through its shadow (owner, 2026-10-29: the hunter cast no shadow on
## the buildings): a caveman that never renders but casts a shadow, playing idle, walk, run, sneak or
## ride to match its parent hunter. Child of the hunter; reads its parent. The first-person view
## shows only its right arm (hands.gd). Which caveman is the player's choice (hunter_looks.gd).

const Looks = preload("res://game/features/hunter/presentation/hunter_looks.gd")
const Backpack = preload("res://assets/models/peak_gear/backpack.tscn")
const RUN_SPEED := 5.0  # between the hunter's walk and sprint speeds
const MOVING_SPEED := 0.3

var _player: AnimationPlayer
var _body: Node3D
var _kind := ""
var _backpack := false

@onready var _hunter: CharacterBody3D = get_parent()


func _ready() -> void:
	if _body == null:
		set_kind(Looks.DEFAULT)


## Puts on the body of this kind of hunter (bearded, plump, lanky); the backpack moves over.
func set_kind(kind: String) -> void:
	kind = Looks.known(kind)
	if kind == _kind:
		return
	_kind = kind
	if _body:
		_body.queue_free()
	_body = Looks.body(kind).instantiate()
	_body.rotation.y = PI  # the model faces +z, the hunter looks along -z
	add_child(_body)
	_shadow_only(_body)
	_player = _body.find_child("AnimationPlayer") as AnimationPlayer
	_player.animation_finished.connect(func(anim: StringName) -> void: _player.play(anim))
	if _backpack:
		_put_on_backpack()


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
	_backpack = true
	_put_on_backpack()


func _put_on_backpack() -> void:
	var skeleton: Skeleton3D = _body.find_child("Skeleton3D") as Skeleton3D
	var mount := BoneAttachment3D.new()
	mount.bone_name = "chest"
	skeleton.add_child(mount)
	var pack: Node3D = Backpack.instantiate()
	pack.transform = skeleton.get_bone_global_rest(skeleton.find_bone("chest")).affine_inverse() * Looks.BACKPACK[_kind]
	mount.add_child(pack)
	_shadow_only(pack)


func _shadow_only(model: Node3D) -> void:
	for mesh: GeometryInstance3D in model.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
