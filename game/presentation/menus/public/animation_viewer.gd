extends Node3D

## Animation viewer from the start screen: pick a caveman, a boar or a bird and an animation; drag to orbit, wheel to zoom.
## Cavemen hold a weapon of choice (owner, 2026-11-23); an attack clip switches to a weapon it is made for.

signal closed

const MODELS := {
	"Bearded": preload("res://assets/models/hunter/prehistoric_hunter.glb"),
	"Plump": preload("res://assets/models/hunter/plump_hunter.glb"),
	"Lanky": preload("res://assets/models/peak_cavemen/lanky.glb"),
}
const ANIMATIONS: Array[String] = ["idle", "walk", "run", "sneak", "ride", "attack", "strong_attack", "club_swing",
		"club_heavy", "thrust", "spear_heavy", "bow_shot"]
const BOAR_ANIMATIONS: Array[String] = ["idle", "walk", "run", "eat", "attack", "death", "net"]
## Roosters and turkeys (tools/rig_birds.py).
const BIRDS := {
	"Rooster": preload("res://game/features/companions/public/rooster_model.tscn"),
	"Turkey": preload("res://game/features/companions/public/turkey_model.tscn"),
}
const BIRD_ANIMATIONS: Array[String] = ["idle", "walk", "run", "peck"]
## The owner's rigged hunters (no clips of their own) and their names for the cavemen's bones.
const HunterRig = preload("res://game/features/hunter/public/hunter_rig.gd")
const HUNTER_BONES := {"hips": "pelvis", "hand_r": "hand.R", "hand_l": "hand.L", "fingers_r": "hand.R", "fingers_l": "hand.L"}
const BoarModel = preload("res://game/features/boar/public/boar_model.tscn")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const Arrow = preload("res://assets/models/weapon_new/arrow.tscn")
const LOOSE_TIME := 34.0 / 30.0  # bow_shot frame where the string is released (tools/rig_cavemen.py)
## The weapon models (bow and slingshot without their first-person strings): scene, hand, and where the fist closes on it in the model's frame
## (HunterRig.hold: the model's +Y leaves the fist on the thumb side, its -X toward the fingers), its turn.
const WEAPONS := {
	"Club": ["res://assets/models/weapon_new/club.tscn", "hand_r", Vector3(0, -0.06, 0), Basis.IDENTITY],
	"Spear": ["res://assets/models/weapon_new/spear.tscn", "hand_r", Vector3.ZERO, Basis.IDENTITY],
	"Knife": ["res://assets/models/weapon_new/knife.tscn", "hand_r", Vector3(0, -0.04, 0), Basis.IDENTITY],
	"Bow": ["res://assets/models/weapon_new/Bow_No_String.glb", "hand_l", Vector3.ZERO,
			Basis(Vector3(-0.7, 0, 0), Vector3(0, 0.7, 0), Vector3(0, 0, -0.7))],  # grip bulge toward the target
	"Sling": ["res://assets/models/weapon_new/Slingshot_No_Bands.glb", "hand_l", Vector3(0, -0.08, 0),
			Basis(Vector3(0, 0, -0.6), Vector3(0, 0.6, 0), Vector3(0.6, 0, 0))],  # shots fly toward the fingers
	"Net": ["res://assets/models/net_bundle.glb", "hand_r", Vector3.ZERO, Basis.IDENTITY * 1.5],
}
## The weapons each attack clip is made for; any other clip keeps the weapon in hand.
const CLIP_WEAPONS := {
	"attack": ["Spear", "Net"], "strong_attack": ["Club"], "club_swing": ["Club"], "club_heavy": ["Club"],
	"thrust": ["Spear", "Knife"], "spear_heavy": ["Spear"], "bow_shot": ["Bow"],
}

var character: Node3D
var player: AnimationPlayer
var animation := "idle"
## Animations of the shown model: ANIMATIONS for a caveman, BOAR_ANIMATIONS for a boar.
var animations: Array[String] = ANIMATIONS
var weapon := "Club"
var _skeleton: Skeleton3D
var _held: Node3D
var _arrow: Node3D
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
	for weapon_name: String in WEAPONS:
		_add_button(%Weapons, weapon_name, show_weapon.bind(weapon_name))
	_boar.show_type(BoarTypes.find("common_brown"))
	_arrow = Node3D.new()
	var arrow_model: Node3D = Arrow.instantiate()
	arrow_model.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO)  # tip toward -Z
	_arrow.add_child(arrow_model)
	add_child(_arrow)
	show_model(MODELS.keys()[0])
	_place_camera()


func show_model(model_name: String) -> void:
	_clear()
	var scene: PackedScene = MODELS[model_name]
	character = HunterRig.instance(scene) if scene.resource_path.begins_with("res://assets/models/hunter/") else scene.instantiate()
	add_child(character)
	player = character.find_child("AnimationPlayer") as AnimationPlayer
	_skeleton = character.find_child("Skeleton3D") as Skeleton3D
	var names := ANIMATIONS.filter(player.has_animation)  # the lanky caveman has only the older clips
	for anim: String in names:
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR  # the viewer repeats every animation
	show_weapon(weapon)
	_list_animations(names)


## Puts this weapon in the caveman's hand, in place of the one held.
func show_weapon(weapon_name: String) -> void:
	weapon = weapon_name
	if _skeleton == null:
		return
	if _held:
		_held.get_parent().queue_free()
	var spec: Array = WEAPONS[weapon_name]
	_held = load(spec[0]).instantiate()
	HunterRig.hold(_skeleton, _bone(spec[1]), _held, spec[2], spec[3])


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
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR  # the glb's clips do not loop by themselves
	_list_animations(BIRD_ANIMATIONS)


func _clear() -> void:
	if character:
		remove_child(character)
		character.queue_free()
	character = null
	_skeleton = null
	_held = null
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
	if not _skeleton:
		return
	if CLIP_WEAPONS.has(anim) and weapon not in CLIP_WEAPONS[anim]:
		show_weapon(CLIP_WEAPONS[anim][0])
	_boar.visible = anim == "ride"
	character.position.y = 0.0
	if anim == "ride":
		# Align the posed hips, not the unscaled rest rig or the model origin.
		player.advance(0.0)
		var hips := _skeleton.get_bone_global_pose(_skeleton.find_bone(_bone("hips"))).origin
		var hips_height := character.to_local(_skeleton.to_global(hips)).y * character.scale.y
		character.position.y = _boar.top() * 0.85 + 0.12 - hips_height


# The arrow lies from the drawing fist through the bow grip until the string is released.
func _process(_delta: float) -> void:
	_arrow.visible = animation == "bow_shot" and weapon == "Bow" and player.current_animation_position < LOOSE_TIME
	if not _arrow.visible:
		return
	var nock := _palm("hand_r")
	var aim := (_palm("hand_l") - nock).normalized()
	_arrow.look_at_from_position(nock + aim * 0.4, nock + aim, Vector3.UP)


## Where a hand's fist is now (HunterRig.PALM).
func _palm(bone: String) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(_bone(bone))) * HunterRig.PALM


## A caveman bone's name in the shown skeleton.
func _bone(bone: String) -> String:
	return bone if _skeleton.find_bone(bone) >= 0 else HUNTER_BONES.get(bone, bone)


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
