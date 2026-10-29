extends Node3D

## Animation viewer from the start screen: pick a caveman, a boar or a bird and an animation; drag to orbit, wheel to zoom.

signal closed

const MODELS := {
	"Skinny": preload("res://assets/models/caveman_skinny.glb"),
	"Heavy": preload("res://assets/models/caveman_heavy.glb"),
}
const ANIMATIONS: Array[String] = ["idle", "walk", "run", "sneak", "ride", "attack", "strong_attack", "bow_shot"]
const BOAR_ANIMATIONS: Array[String] = ["idle", "walk", "run", "eat", "attack", "death", "net"]
## Roosters and turkeys (tools/build_birds.py).
const BIRDS := {
	"Fat rooster": preload("res://assets/models/rooster_fat.glb"),
	"Thin rooster": preload("res://assets/models/rooster_thin.glb"),
	"Fat turkey": preload("res://assets/models/turkey_fat.glb"),
	"Thin turkey": preload("res://assets/models/turkey_thin.glb"),
}
const BIRD_ANIMATIONS: Array[String] = ["idle", "walk", "run", "peck"]
const BoarModel = preload("res://game/features/boar/public/boar_model.tscn")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const Club = preload("res://assets/models/club.glb")
const Bow = preload("res://assets/models/bow.glb")
const Arrow = preload("res://assets/models/arrow.glb")
const LOOSE_TIME := 34.0 / 30.0  # bow_shot frame where the string is released (tools/rig_cavemen.py)
const GRIP := Vector3(0, 0.1, -0.04)  # inside the fist, in hand bone space

var character: Node3D
var player: AnimationPlayer
var animation := "idle"
## Animations of the shown model: ANIMATIONS for a caveman, BOAR_ANIMATIONS for a boar.
var animations: Array[String] = ANIMATIONS
var _skeleton: Skeleton3D
var _club: Node3D
var _bow: Node3D
var _arrow := Node3D.new()
var _yaw := 0.5
var _pitch := -0.15
var _distance := 3.2

@onready var _camera: Camera3D = %Camera
@onready var _boar: Node3D = %Boar


func _ready() -> void:
	%Back.pressed.connect(closed.emit)
	for model_name: String in MODELS:
		_add_button(%Models, model_name, show_model.bind(model_name))
	for boar_type in BoarTypes.ALL:
		_add_button(%Models, boar_type.display_name, show_boar.bind(boar_type.id))
	for bird_name: String in BIRDS:
		_add_button(%Models, bird_name, show_bird.bind(bird_name))
	_boar.show_type(BoarTypes.find("common_brown"))
	var arrow_model: Node3D = Arrow.instantiate()
	arrow_model.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)  # tip toward -Z
	_arrow.add_child(arrow_model)
	add_child(_arrow)
	show_model(MODELS.keys()[0])
	_place_camera()


func show_model(model_name: String) -> void:
	_clear()
	character = MODELS[model_name].instantiate()
	add_child(character)
	player = character.find_child("AnimationPlayer") as AnimationPlayer
	_skeleton = character.find_child("Skeleton3D") as Skeleton3D
	for anim in ANIMATIONS:
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR  # the viewer repeats every animation
	# Hand bones run wrist -> knuckles along +Y, the palm faces -Z and the fingers curl around X.
	_club = _attach(Club, "hand_r", Transform3D(Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)), GRIP + Vector3(-0.25, 0, 0)))
	_bow = _attach(Bow, "hand_l", Transform3D(Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)), GRIP))
	_list_animations(ANIMATIONS)


## Boars turned to face the camera; attack and death replay when they end instead of looping, because
## looping the shared animation resources would make dead boars in a hunt get up again.
func show_boar(type_id: String) -> void:
	_clear()
	character = BoarModel.instantiate()
	add_child(character)
	character.rotation.y = PI
	character.show_type(BoarTypes.find(type_id))
	player = character.player()
	player.animation_finished.connect(func(anim: StringName) -> void: player.play(anim))
	_list_animations(BOAR_ANIMATIONS)


func show_bird(bird_name: String) -> void:
	_clear()
	character = BIRDS[bird_name].instantiate()
	add_child(character)
	character.rotation.y = PI
	player = character.find_child("AnimationPlayer") as AnimationPlayer
	for anim in BIRD_ANIMATIONS:
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_list_animations(BIRD_ANIMATIONS)


func _clear() -> void:
	if character:
		remove_child(character)
		character.queue_free()
	character = null
	_club = null
	_bow = null
	_boar.visible = false


func _list_animations(names: Array[String]) -> void:
	animations = names
	for button in %Animations.get_children():
		button.free()
	for anim in names:
		_add_button(%Animations, anim.capitalize(), play.bind(anim))
	play(animation if animation in names else "idle")


func play(anim: String) -> void:
	animation = anim
	player.play(anim)
	if not _club:
		return
	# Cavemen always carry a weapon: the bow for shooting, the club otherwise.
	_club.visible = anim != "bow_shot"
	_bow.visible = anim == "bow_shot"
	_boar.visible = anim == "ride"
	var hips_height := _skeleton.get_bone_global_rest(_skeleton.find_bone("hips")).origin.y
	# On the saddle, as in mount.gd.
	character.position.y = _boar.top() * 0.85 + 0.12 - hips_height if anim == "ride" else 0.0


# The arrow lies from the drawing fist through the bow grip until the string is released.
func _process(_delta: float) -> void:
	_arrow.visible = animation == "bow_shot" and player.current_animation_position < LOOSE_TIME
	if not _arrow.visible:
		return
	var nock := _bone_position("fingers_r")
	var aim := (_bone_position("fingers_l") - nock).normalized()
	_arrow.look_at_from_position(nock + aim * 0.4, nock + aim, Vector3.UP)


func _bone_position(bone: String) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(bone)).origin


func _attach(scene: PackedScene, bone: String, offset: Transform3D) -> Node3D:
	var socket := BoneAttachment3D.new()
	socket.bone_name = bone
	_skeleton.add_child(socket)
	var item: Node3D = scene.instantiate()
	item.transform = offset
	socket.add_child(item)
	return item


func _add_button(box: Container, text: String, pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(pressed)
	box.add_child(button)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch - event.relative.y * 0.01, -1.2, 0.3)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(1.5, _distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(10.0, _distance + 0.3)
	else:
		return
	_place_camera()


func _place_camera() -> void:
	var target := Vector3(0, 0.9, 0)
	_camera.position = target + Basis.from_euler(Vector3(_pitch, _yaw, 0)) * Vector3(0, 0, _distance)
	_camera.look_at(target)
