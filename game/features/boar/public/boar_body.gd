extends CharacterBody3D

## Boar agent on a hunt map: holds the domain Boar and steers by its state (M002).

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarSenses = preload("res://game/features/boar/domain/boar_senses.gd")

# ASSUMPTION numbers (D013), tuned in phase 2. Flee and panic outrun a sprinting hunter (7 m/s).
const WANDER_SPEED := 1.5
const FLEE_SPEED := 8.0
const PANIC_SPEED := 10.0
const PERCEPTION_RADIUS := 12.0
const ESCAPE_RADIUS := 3.0
const WANDER_TURN_SECONDS := 2.0
const PANIC_TURN_SECONDS := 0.6
const PANIC_TURN_MAX := PI / 3.0
const CORPSE_SECONDS := 3.0

@export var type_id := "runner"
@export var max_health := 3

## Injected by the scene that spawns the boar.
var hunter: Node3D
var escape_zones: Array[Vector2] = []

var boar: Boar
var _heading := Vector2.ZERO
## Wander angle or panic deflection, re-rolled when _turn_left runs out.
var _turn := 0.0
var _turn_left := 0.0

@onready var _label: Label3D = $Label


func _ready() -> void:
	boar = Boar.new(type_id, max_health)
	_show_state()


func spear_hit(damage: int) -> void:
	boar.take_hit(damage)
	_turn_left = 0.0
	_after_change()


func net_hit() -> void:
	boar.net_capture()
	_after_change()


func _after_change() -> void:
	_show_state()
	if boar.state == Boar.State.DEAD:
		rotation.z = PI / 2.0
		get_tree().create_timer(CORPSE_SECONDS).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not boar.is_free():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var pos := Vector2(global_position.x, global_position.z)
	var hunter_pos := Vector2(hunter.global_position.x, hunter.global_position.z)
	var before := boar.state
	BoarSenses.perceive(boar, pos, hunter_pos, PERCEPTION_RADIUS)
	for zone in escape_zones:
		BoarSenses.enter_zone(boar, pos, zone, ESCAPE_RADIUS)
	if boar.state == Boar.State.ESCAPED:
		queue_free()
		return
	if boar.state != before:
		_show_state()
	_steer(delta, pos, hunter_pos)
	move_and_slide()


func _steer(delta: float, pos: Vector2, hunter_pos: Vector2) -> void:
	_turn_left -= delta
	var speed := WANDER_SPEED
	match boar.state:
		Boar.State.WANDER:
			if _turn_left <= 0.0:
				_turn = randf() * TAU
				_turn_left = WANDER_TURN_SECONDS
			_heading = Vector2.from_angle(_turn)
		Boar.State.FLEE:
			_heading = BoarSenses.flee_heading(pos, hunter_pos, escape_zones)
			speed = FLEE_SPEED
		_:
			# PANIC; CHARGE has no rule yet and behaves the same.
			if _turn_left <= 0.0:
				_turn = randf_range(-PANIC_TURN_MAX, PANIC_TURN_MAX)
				_turn_left = PANIC_TURN_SECONDS
			_heading = BoarSenses.flee_heading(pos, hunter_pos, escape_zones).rotated(_turn)
			speed = PANIC_SPEED
	velocity.x = _heading.x * speed
	velocity.z = _heading.y * speed
	if _heading != Vector2.ZERO:
		rotation.y = atan2(-_heading.x, -_heading.y)


## Name of the current domain state, e.g. "FLEE".
func state_name() -> String:
	return Boar.State.keys()[boar.state]


func _show_state() -> void:
	_label.text = "%s %d/%d" % [state_name(), boar.health, max_health]
