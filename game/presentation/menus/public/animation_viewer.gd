extends Node3D

## Animation viewer from the start screen: pick a caveman and an animation; drag to orbit, wheel to zoom.

signal closed

const MODELS := {
	"Skinny": preload("res://assets/models/caveman_skinny.glb"),
	"Heavy": preload("res://assets/models/caveman_heavy.glb"),
}
const ANIMATIONS: Array[String] = ["idle", "walk", "run", "sneak", "ride", "attack", "strong_attack", "bow_shot"]
const BoarModel = preload("res://game/features/boar/public/boar_model.tscn")
const Club = preload("res://assets/models/club.glb")
const Bow = preload("res://assets/models/bow.glb")
const SADDLE_HEIGHT := 1.02  # top of the saddle in mount.tscn

var character: Node3D
var player: AnimationPlayer
var animation := "idle"
var _skeleton: Skeleton3D
var _club: Node3D
var _bow: Node3D
var _yaw := 0.5
var _pitch := -0.15
var _distance := 3.2

@onready var _camera: Camera3D = %Camera
@onready var _boar: Node3D = %Boar


func _ready() -> void:
	%Back.pressed.connect(closed.emit)
	for model_name: String in MODELS:
		_add_button(%Models, model_name, show_model.bind(model_name))
	for anim in ANIMATIONS:
		_add_button(%Animations, anim.capitalize(), play.bind(anim))
	_boar.paint(Color(0.45, 0.3, 0.2))
	show_model(MODELS.keys()[0])
	_place_camera()


func show_model(model_name: String) -> void:
	if character:
		character.queue_free()
	character = MODELS[model_name].instantiate()
	add_child(character)
	player = character.find_child("AnimationPlayer") as AnimationPlayer
	_skeleton = character.find_child("Skeleton3D") as Skeleton3D
	for anim in ANIMATIONS:
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR  # the viewer repeats every animation
	_club = _attach(Club, "hand_r", Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(0.05, 0.02, 0)))
	_bow = _attach(Bow, "hand_l", Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)), Vector3(0.05, 0, 0)))
	play(animation)


func play(anim: String) -> void:
	animation = anim
	player.play(anim)
	_club.visible = anim in ["attack", "strong_attack"]
	_bow.visible = anim == "bow_shot"
	_boar.visible = anim == "ride"
	var hips_height := _skeleton.get_bone_global_rest(_skeleton.find_bone("hips")).origin.y
	character.position.y = SADDLE_HEIGHT + 0.05 - hips_height if anim == "ride" else 0.0


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
