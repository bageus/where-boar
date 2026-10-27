extends CharacterBody3D

## Boar agent on a hunt map: holds the domain Boar and steers by its state (M002).

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarSenses = preload("res://game/features/boar/domain/boar_senses.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarType = preload("res://game/features/boar/public/boar_type.gd")

# ASSUMPTION numbers (D013); per-type speeds and senses live in BoarType.
const WANDER_SPEED := 1.5
const ESCAPE_RADIUS := 3.0
const WANDER_TURN_SECONDS := 2.0
const PANIC_TURN_SECONDS := 0.6
const PANIC_TURN_MAX := PI / 3.0
const CORPSE_SECONDS := 3.0
# Ram (M005): exaggerated knockback by speed, ASSUMPTION numbers (D013).
const RAM_MIN_SPEED := 6.0
const RAM_IMPULSE := 14.0
const RAM_COOLDOWN := 1.0
const KNOCK_DECAY := 6.0
# Charge after an attack (D018), ASSUMPTION numbers (D013).
const PANIC_SECONDS := 2.5
const CHARGE_SECONDS := 4.0
## How long a shout steers a boar before it flees normally again.
const SHOUT_SECONDS := 2.0
## Hunter health lost per point of boar damage (hunter health 100, boar damage 1–2).
const HP_PER_DAMAGE := 20

## Fact: the boar's hunt ended (DEAD, CAPTURED or ESCAPED); kind is a BoarOutcome.Kind.
signal outcome_reached(type_id: String, kind: int)

@export var boar_type: BoarType = preload("res://game/features/boar/content/boar_common_brown.tres")

## Injected by the scene that spawns the boar.
var hunter: Node3D
var escape_zones: Array[Vector2] = []
## Bait nodes on the map (shared array owned by the map); each has attract_radius.
var baits: Array[Node3D] = []

var boar: Boar
var _heading := Vector2.ZERO
## Wander angle or panic deflection, re-rolled when _turn_left runs out.
var _turn := 0.0
var _turn_left := 0.0
var _knock := Vector3.ZERO
var _ram_cooldown := 0.0
## Last wall (XZ normal) the boar slid on, used to steer out of corners.
var _wall := Vector2.ZERO
var _reported := false
## Seconds in the current domain state.
var _state_time := 0.0
var _charge_rolled := false
var _shout_heading := Vector2.ZERO
var _shout_left := 0.0

@onready var _label: Label3D = $Label
@onready var _health_fill: MeshInstance3D = $HealthBar/Fill


func _ready() -> void:
	boar = Boar.new(boar_type.id, boar_type.max_health)
	var hide := StandardMaterial3D.new()
	hide.albedo_color = boar_type.color
	$Body.material_override = hide
	$Snout.material_override = hide
	_show_state()


func spear_hit(amount: int) -> void:
	boar.take_hit(amount)
	_turn_left = 0.0
	_state_time = 0.0
	_charge_rolled = false
	_after_change()


## A hunter shouted at shout_pos (M014): a free boar runs off at an angle, never panics.
func hear_shout(shout_pos: Vector3) -> void:
	if boar.state not in [Boar.State.WANDER, Boar.State.FLEE]:
		return
	var pos := Vector2(global_position.x, global_position.z)
	var side := 1 if randf() < 0.5 else -1
	_shout_heading = BoarSenses.shout_heading(boar, pos, Vector2(shout_pos.x, shout_pos.z), side)
	_shout_left = SHOUT_SECONDS
	_show_state()


func net_hit() -> void:
	boar.net_capture()
	_after_change()


## Knocked by a ram or another boar: pushed along `impulse` for a moment.
func knock(impulse: Vector3, _damage: int = 0) -> void:
	_knock = impulse * boar_type.knock_scale


func _after_change() -> void:
	_show_state()
	_report_outcome()
	if boar.state == Boar.State.DEAD:
		rotation.z = PI / 2.0
		get_tree().create_timer(CORPSE_SECONDS).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not boar.is_free():
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_knock(delta)
		move_and_slide()
		return
	var pos := Vector2(global_position.x, global_position.z)
	var hunter_pos := Vector2(hunter.global_position.x, hunter.global_position.z)
	var before := boar.state
	BoarSenses.perceive(boar, pos, hunter_pos, boar_type.perception_radius)
	for zone in escape_zones:
		BoarSenses.enter_zone(boar, pos, zone, ESCAPE_RADIUS)
	if boar.state == Boar.State.ESCAPED:
		_report_outcome()
		queue_free()
		return
	_state_time += delta
	_maybe_charge()
	if boar.state != before:
		_state_time = 0.0
		_show_state()
	_steer(delta, pos, hunter_pos)
	_apply_knock(delta)
	move_and_slide()
	_ram(delta)


## A panicking boar rolls once whether to charge; a charge that hits nothing gives up.
func _maybe_charge() -> void:
	if boar.state == Boar.State.PANIC and _state_time >= PANIC_SECONDS and not _charge_rolled:
		_charge_rolled = true
		if randf() < boar_type.aggression:
			boar.charge()
	elif boar.state == Boar.State.CHARGE and _state_time >= CHARGE_SECONDS:
		boar.end_charge()


func _steer(delta: float, pos: Vector2, hunter_pos: Vector2) -> void:
	_turn_left -= delta
	_shout_left -= delta
	var speed := WANDER_SPEED
	match boar.state:
		Boar.State.WANDER:
			var spots := _bait_spots()
			var bait := BoarSenses.bait_target(pos, spots)
			if bait != -1:
				# Walk up to the bait, then stand and eat.
				var to_bait := Vector2(spots[bait].x, spots[bait].y) - pos
				_heading = to_bait.normalized() if to_bait.length() > BoarSenses.EAT_DISTANCE else Vector2.ZERO
			else:
				if _turn_left <= 0.0:
					_turn = randf() * TAU
					_turn_left = WANDER_TURN_SECONDS
				_heading = Vector2.from_angle(_turn)
		Boar.State.FLEE:
			_heading = _shout_heading if _shout_left > 0.0 else BoarSenses.flee_heading(pos, hunter_pos, escape_zones)
			speed = boar_type.flee_speed
		Boar.State.CHARGE:
			_heading = (hunter_pos - pos).normalized()
			speed = boar_type.flee_speed
		_:
			if _turn_left <= 0.0:
				_turn = randf_range(-PANIC_TURN_MAX, PANIC_TURN_MAX)
				_turn_left = PANIC_TURN_SECONDS
			_heading = BoarSenses.flee_heading(pos, hunter_pos, escape_zones).rotated(_turn)
			speed = boar_type.panic_speed
	if _wall != Vector2.ZERO and _heading.dot(_wall) < 0.0 and boar.state != Boar.State.WANDER:
		var zone := BoarSenses.nearest_zone(pos, escape_zones)
		var toward := escape_zones[zone] - pos if zone != -1 else pos - hunter_pos
		_heading = BoarSenses.slide_heading(_wall, toward)
	velocity.x = _heading.x * speed
	velocity.z = _heading.y * speed
	if _heading != Vector2.ZERO:
		rotation.y = atan2(-_heading.x, -_heading.y)


func _bait_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for bait in baits:
		if is_instance_valid(bait):
			spots.append(Vector3(bait.global_position.x, bait.global_position.z, bait.attract_radius))
	return spots


func _apply_knock(delta: float) -> void:
	velocity.x += _knock.x
	velocity.z += _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * RAM_IMPULSE * delta)


## A fast boar that touches the hunter or another boar knocks it back (M005); also remembers walls.
func _ram(delta: float) -> void:
	_ram_cooldown -= delta
	_wall = Vector2.ZERO
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider()
		if other.has_method("knock") and _ram_cooldown <= 0.0 and Vector2(velocity.x, velocity.z).length() >= RAM_MIN_SPEED:
			var push := Vector3(velocity.x, 0.0, velocity.z).normalized()
			var charging := boar.state == Boar.State.CHARGE
			other.knock(push * RAM_IMPULSE + Vector3.UP * 3.0, boar_type.damage * HP_PER_DAMAGE if charging else 0)
			_ram_cooldown = RAM_COOLDOWN
			if charging:
				boar.end_charge()
				_state_time = 0.0
				_show_state()
		elif absf(hit.get_normal().y) < 0.5:
			_wall = Vector2(hit.get_normal().x, hit.get_normal().z).normalized()


## Name of the current domain state, e.g. "FLEE".
func state_name() -> String:
	return Boar.State.keys()[boar.state]


func _report_outcome() -> void:
	var kind := boar.outcome_kind()
	if kind != BoarOutcome.Kind.NONE and not _reported:
		_reported = true
		outcome_reached.emit(boar_type.id, kind)


func _show_state() -> void:
	_label.text = state_name()
	# Health bar over the boar, green when full, red when nearly dead (section 16); shrinks to its centre.
	var ratio := float(boar.health) / boar_type.max_health
	_health_fill.scale.x = maxf(ratio, 0.001)
	(_health_fill.material_override as StandardMaterial3D).albedo_color = Color.RED.lerp(Color.GREEN, ratio)
