extends CharacterBody3D

## Boar agent on a hunt map: holds the domain Boar and steers by its state (M002).

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarSenses = preload("res://game/features/boar/domain/boar_senses.gd")
const BoarAlert = preload("res://game/features/boar/domain/boar_alert.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarType = preload("res://game/features/boar/public/boar_type.gd")
const Surroundings = preload("res://game/features/boar/presentation/boar_surroundings.gd")
const StunStars = preload("res://game/features/boar/presentation/stun_stars.gd")

# ASSUMPTION numbers (D013); per-type speeds and senses live in BoarType.
const WANDER_SPEED := 1.5
const ESCAPE_RADIUS := 3.0
const WANDER_TURN_SECONDS := 2.0
const PANIC_TURN_SECONDS := 0.6
const PANIC_TURN_MAX := PI / 3.0
const CORPSE_SECONDS := 3.0
const LYING_LIFT := 0.45
# Ram (M005): exaggerated knockback by speed, ASSUMPTION numbers (D013).
const RAM_MIN_SPEED := 6.0
const RAM_IMPULSE := 14.0
const RAM_COOLDOWN := 1.0
const KNOCK_DECAY := 6.0
# Charge after an attack (D018), ASSUMPTION numbers (D013).
const PANIC_SECONDS := 2.5
const CHARGE_SECONDS := 4.0
## How long a shout or a fence steers a boar before it runs normally again.
const SHOUT_SECONDS := 2.0
const FENCE_TURN_SECONDS := 1.5
# Herds (M009), ASSUMPTION numbers (D013).
const HERD_ALARM_RADIUS := 8.0
const HERD_SPREAD := 6.0
## Split-off groups and loners rejoin mates within this reach once calm (playtest 2026-10-27).
const HERD_REJOIN_RADIUS := 30.0
# Ram dash (playtest 2026-10-27): close to the hunter a charging boar locks on and runs through him.
const RAM_DASH_DISTANCE := 4.0
const RAM_DASH_SECONDS := 1.0
const RAM_HIT_DISTANCE := 1.3
## How far a wall or fence turns a boar away from its normal, radians.
const WALL_TURN_SPREAD := PI / 4.0
## Physics layer 6: the boar's hitbox (weapons and the hunter's E look for it).
const HITBOX_LAYER := 1 << 5
## Physics layer 5: bushes and other cover that block a boar's sight but not movement.
const COVER_LAYER := 1 << 4
## Boar eye and hunter body heights for the line of sight, metres (ASSUMPTION).
const EYE_RISE := 0.5
const HUNTER_RISE := 0.8
## Speed share left while wading through a river (ASSUMPTION).
const WADE_SPEED_SCALE := 0.5
# Alert and flight (playtest 2026-10-27), ASSUMPTION numbers (D013).
## A flight lasts this long, then the boar calms down; twice as long after it saw a boar killed.
const FLIGHT_SECONDS := 10.0
const WITNESS_FLIGHT_SCALE := 2.0
## Chance an alarmed calm boar attacks instead of fleeing, times its type's aggression.
const ALERT_ATTACK_SHARE := 0.5
const ALERT_MARKS := ["", "?", "!", "!!"]
const ALERT_COLORS := [Color.WHITE, Color.YELLOW, Color.ORANGE, Color.RED]
## Hunter health lost per point of boar damage (hunter health 100, boar damage 1–2).
const HP_PER_DAMAGE := 20
## A free boar running this close to a snared one frees it (owner, 2026-10-30; distance ASSUMPTION).
const RESCUE_RADIUS := 2.0
const RESCUE_MIN_SPEED := 1.0
const PIT_FALL_SECONDS := 0.3

## Fact: the boar's hunt ended (DEAD, CAPTURED or ESCAPED); kind is a BoarOutcome.Kind.
## wounded: the boar was hurt before it was caught (pays less).
signal outcome_reached(type_id: String, kind: int, wounded: bool)
## Fact: a trap started (true) or stopped (false) holding the boar. Held boars count as caught at hunt end.
signal held_changed(held: bool)

@export var boar_type: BoarType = preload("res://game/features/boar/content/boar_common_brown.tres")

## Injected by the scene that spawns the boar.
var hunter: Node3D
var escape_zones: Array[Vector2] = []
## Bait nodes on the map (shared array owned by the map); each has attract_radius.
var baits: Array[Node3D] = []
## Herd mates including this boar (shared array); empty for a loner.
var herd: Array[Node3D] = []

var boar: Boar
var alert := BoarAlert.new()
var _heading := Vector2.ZERO
## Wander angle or panic deflection, re-rolled when _turn_left runs out.
var _turn := 0.0
var _turn_left := 0.0
var _knock := Vector3.ZERO
var _ram_cooldown := 0.0
## Flight deflection rolled when the boar gets scared, so a herd scatters.
var _scatter := 0.0
var _dash_heading := Vector2.ZERO
var _dash_left := 0.0
var _dash_hit := false
var _calm_left := 0.0
var _was_fleeing := false
## Set when the boar saw another boar killed; makes the current flight longer.
var _flight_scale := 1.0
var _reported := false
## River segments the boar is standing in; rivers call wade().
var _wading := 0
## Seconds in the current domain state.
var _state_time := 0.0
var _charge_rolled := false
var _forced_heading := Vector2.ZERO
var _forced_left := 0.0
var _stun_left := 0.0
var _stars: Node3D
## Held by a snare: another boar running past can free it.
var _snared := false
## Standing at a bait and eating it.
var _eating := false

@onready var _label: Label3D = $Label
@onready var _alert_mark: Label3D = $AlertMark
@onready var _health_fill: MeshInstance3D = $HealthBar/Fill


func _ready() -> void:
	boar = Boar.new(boar_type.id, boar_type.max_health)
	$Model.show_type(boar_type)
	_show_state()


func spear_hit(amount: int) -> void:
	var was_charging := boar.state == Boar.State.CHARGE
	boar.take_hit(amount)
	$Sounds.squeal()
	$Model.flash()
	if boar.state == Boar.State.CHARGE:
		# Mid-ram: the hit hurts but does not stop it.
		_after_change()
		return
	_calm_left = FLIGHT_SECONDS * _flight_scale
	alert.alarm()
	if was_charging and boar.state == Boar.State.FLEE:
		# Scared off: runs any way that leads away from the hunter.
		var away := Vector2(global_position.x - hunter.global_position.x, global_position.z - hunter.global_position.z).normalized()
		_forced_heading = away.rotated(randf_range(-PI / 2.0, PI / 2.0))
		_forced_left = SHOUT_SECONDS
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
	_forced_heading = BoarSenses.shout_heading(boar, pos, Vector2(shout_pos.x, shout_pos.z), side)
	_forced_left = SHOUT_SECONDS
	_show_state()


## A rooster crowed at pos (M016): a calm or fleeing boar runs straight away from it.
func driven_from(pos: Vector3) -> void:
	if boar.state not in [Boar.State.WANDER, Boar.State.FLEE]:
		return
	boar.flee()
	_forced_heading = Vector2(global_position.x - pos.x, global_position.z - pos.z).normalized()
	_forced_left = SHOUT_SECONDS
	_show_state()


func net_hit() -> void:
	var was_held := boar.state == Boar.State.TRAPPED
	var unaware := boar.state == Boar.State.WANDER
	boar.net_capture()
	if unaware and boar.state == Boar.State.CAPTURED:
		_warn_herd_of_capture()
	if was_held:
		held_changed.emit(false)
	_after_change()


## Pit with leaves: the boar drops to the bottom of the pit at center and stays until the hunt ends.
func fall_in_pit(center: Vector3, depth: float) -> void:
	if not boar.is_free():
		return
	_hold()
	global_position = Vector3(center.x, global_position.y, center.z)
	create_tween().tween_property($Model, "position:y", -depth, PIT_FALL_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Snare: holds the boar until another boar runs past it or the hunter takes it (owner, 2026-10-30).
func snare() -> void:
	if boar.is_free():
		_hold()
		_snared = true


## Tripwire: the boar falls and lies stunned for a while, stars circling over it (owner, 2026-10-30).
func trip(seconds: float) -> void:
	if boar.is_free():
		_stun_left = seconds
		_lie(true)
		$Sounds.trapped()
		_stars = StunStars.new()
		_stars.position.y = 1.0
		add_child(_stars)


## Boars whose hitbox is within radius of point.
static func near(world: World3D, point: Vector3, radius: float) -> Array[Node]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.transform = Transform3D(Basis(), point)
	query.collision_mask = HITBOX_LAYER  # hitboxes only; the terrain alone would fill the results
	var boars: Array[Node] = []
	for hit in world.direct_space_state.intersect_shape(query):
		boars.append(hit.collider.get_parent())
	return boars


## The hunter's E: a boar held by a snare or a pit, or lying stunned, is caught for good. False if it is neither.
func take_held() -> bool:
	if boar.state != Boar.State.TRAPPED and not (_stun_left > 0.0 and boar.is_free()):
		return false
	net_hit()
	return true


func _end_stun() -> void:
	_stun_left = 0.0
	_lie(false)
	if _stars:
		_stars.queue_free()
		_stars = null


## Lays only the model on its side, lifted by half its width so it rests on the ground; turning the physics
## body sank corpses into the terrain (playtest 2026-10-28).
func _lie(down: bool) -> void:
	$Model.rotation.z = PI / 2.0 if down else 0.0
	$Model.position.y = LYING_LIFT if down else 0.0


## The cage gate drops behind the boar: caught, it stands in the cage till the hunt ends.
func cage_capture() -> void:
	net_hit()
	$Model.stand()
	$Sounds.trapped()


func _hold() -> void:
	boar.trap()
	$Sounds.trapped()
	_show_state()
	held_changed.emit(true)


## A snared boar is freed by a free boar running close by (owner, 2026-10-30).
func _rescued() -> bool:
	for other in get_parent().get_children():
		if other != self and other.get_script() == get_script() and other.boar.is_free() \
				and Vector2(other.velocity.x, other.velocity.z).length() >= RESCUE_MIN_SPEED \
				and other.global_position.distance_to(global_position) <= RESCUE_RADIUS:
			return true
	return false


## Knocked by a ram or another boar: pushed along `impulse` for a moment.
func knock(impulse: Vector3, _damage: int = 0, _rammer: Resource = null) -> void:
	_knock = impulse * boar_type.knock_scale


func _after_change() -> void:
	if not boar.is_free() and _stun_left > 0.0:
		_end_stun()
	_show_state()
	_report_outcome()
	if boar.state == Boar.State.DEAD:
		$Model.die()
		get_tree().create_timer(CORPSE_SECONDS).timeout.connect(_remove_corpse)
		_warn_witnesses()
	elif boar.state == Boar.State.CAPTURED:
		$Model.net_fall()


## A corpse with spears, arrows or nets stuck in it stays until the hunt ends, so they can be taken back.
func _remove_corpse() -> void:
	if not get_children().any(func(child: Node) -> bool: return child is RigidBody3D):
		queue_free()


## Boars that see this one die run in panic twice as long (playtest 2026-10-27).
func _warn_witnesses() -> void:
	var pos := Vector2(global_position.x, global_position.z)
	for other in get_parent().get_children():
		if other == self or not other.has_method("saw_kill"):
			continue
		var other_pos := Vector2(other.global_position.x, other.global_position.z)
		var facing := Vector2(-other.global_basis.z.x, -other.global_basis.z.z)
		if other_pos.distance_to(pos) <= other.boar_type.perception_radius and BoarSenses.in_view(other_pos, facing, pos):
			other.saw_kill()


## Caught from ambush: nearby herd mates turn wary, or run if they already were (owner, 2026-10-27).
func _warn_herd_of_capture() -> void:
	for mate in herd:
		if mate != self and is_instance_valid(mate) and mate.global_position.distance_to(global_position) <= HERD_ALARM_RADIUS:
			mate.witness_capture()


func witness_capture() -> void:
	if boar.state != Boar.State.WANDER:
		return
	if alert.witness_capture():
		boar.flee()
	_show_alert()


func saw_kill() -> void:
	if not boar.is_free():
		return
	boar.flee()
	alert.alarm()
	_flight_scale = WITNESS_FLIGHT_SCALE
	_calm_left = FLIGHT_SECONDS * WITNESS_FLIGHT_SCALE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _snared and boar.state == Boar.State.TRAPPED and _rescued():
		_snared = false
		boar.break_free()
		_state_time = 0.0
		_show_state()
		held_changed.emit(false)
	if _stun_left > 0.0:
		_stun_left -= delta
		if _stun_left <= 0.0:
			_end_stun()
	if not boar.is_free() or _stun_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_knock(delta)
		move_and_slide()
		$Model.move(0.0)
		return
	var pos := Vector2(global_position.x, global_position.z)
	var hunter_pos := Vector2(hunter.global_position.x, hunter.global_position.z)
	var before := boar.state
	_perceive(delta, pos, hunter_pos)
	if boar.state == Boar.State.WANDER and not herd.is_empty():
		BoarSenses.hear_herd(boar, pos, Surroundings.herd_positions(self, true), HERD_ALARM_RADIUS)
	for zone in escape_zones:
		BoarSenses.enter_zone(boar, pos, zone, ESCAPE_RADIUS)
	if boar.state == Boar.State.ESCAPED:
		_report_outcome()
		queue_free()
		return
	_state_time += delta
	_maybe_charge()
	_track_flight(delta)
	if boar.state != before:
		_state_time = 0.0
		if before == Boar.State.WANDER:
			_scatter = BoarSenses.scatter_angle(randf(), randf())
			$Sounds.cry()
		_show_state()
	_steer(delta, pos, hunter_pos)
	_apply_knock(delta)
	move_and_slide()
	$Model.move(Vector2(velocity.x, velocity.z).length(), _eating)
	_ram(delta)


## A calm boar that keeps noticing the hunter grows alarmed in three stages, then flees or attacks;
## a sneaking hunter is only noticed in front of the boar and not behind cover (M002).
func _perceive(delta: float, pos: Vector2, hunter_pos: Vector2) -> void:
	if boar.state != Boar.State.WANDER:
		_show_alert()
		return
	var facing := Vector2(-global_basis.z.x, -global_basis.z.z)
	var sneaking: bool = hunter.get("crouching") == true
	var mounted: bool = hunter.get("ride") != null and hunter.ride.is_riding()
	var radius := boar_type.perception_radius * (BoarSenses.MOUNTED_RADIUS_SCALE if mounted else 1.0)
	var distance := pos.distance_to(hunter_pos)
	var clear := true
	if sneaking and distance <= radius and BoarSenses.in_view(pos, facing, hunter_pos):
		clear = _sight_clear()
	var noticed := BoarSenses.notices(pos, hunter_pos, radius, facing, sneaking, clear, hunter.global_position.y - global_position.y)
	alert.tick(delta, noticed, radius / maxf(distance, 0.1) * (BoarSenses.MOUNTED_ALARM_RATE_SCALE if mounted else 1.0))
	if alert.alarmed():
		if not mounted and randf() < boar_type.aggression * ALERT_ATTACK_SHARE:
			boar.attack()
			_charge_rolled = true
		else:
			boar.flee()
	_show_alert()


## Flights end after a while (playtest 2026-10-27): the boar calms down but stays wary.
func _track_flight(delta: float) -> void:
	var fleeing := boar.state in [Boar.State.FLEE, Boar.State.PANIC]
	if fleeing and not _was_fleeing:
		_calm_left = FLIGHT_SECONDS * _flight_scale
		alert.alarm()
	_was_fleeing = fleeing
	if not fleeing:
		return
	_calm_left -= delta
	if _calm_left <= 0.0:
		boar.calm()
		alert.settle()
		_flight_scale = 1.0
		_charge_rolled = false
		_was_fleeing = false


## Alert mark over the boar: ? heard something, ! wary, !! alarmed or running.
func _show_alert() -> void:
	var level := alert.level() if boar.state == Boar.State.WANDER else (BoarAlert.MAX_LEVEL if boar.is_free() else 0)
	if _alert_mark.text != ALERT_MARKS[level]:
		_alert_mark.text = ALERT_MARKS[level]
		_alert_mark.modulate = ALERT_COLORS[level]


func _sight_clear() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * EYE_RISE,
			hunter.global_position + Vector3.UP * HUNTER_RISE, collision_mask | COVER_LAYER, [get_rid(), hunter.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## A river calls this when the boar steps in (true) or out (false).
func wade(entered: bool) -> void:
	_wading += 1 if entered else -1


## A panicking boar rolls once whether to charge; a charge that hits nothing gives up.
func _maybe_charge() -> void:
	if boar.state == Boar.State.PANIC and _state_time >= PANIC_SECONDS and not _charge_rolled:
		_charge_rolled = true
		if randf() < boar_type.aggression:
			boar.charge()
	elif boar.state == Boar.State.CHARGE and _state_time >= CHARGE_SECONDS and not boar.ramming:
		boar.end_charge()


func _steer(delta: float, pos: Vector2, hunter_pos: Vector2) -> void:
	_turn_left -= delta
	_forced_left -= delta
	var speed := WANDER_SPEED
	_eating = false
	match boar.state:
		Boar.State.WANDER:
			var spots := Surroundings.bait_spots(baits)
			var bait := BoarSenses.bait_target(pos, spots)
			if bait != -1:
				# Walk up to the bait, then stand and eat.
				var to_bait := Vector2(spots[bait].x, spots[bait].y) - pos
				_eating = to_bait.length() <= BoarSenses.EAT_DISTANCE
				_heading = Vector2.ZERO if _eating else to_bait.normalized()
			else:
				if _turn_left <= 0.0:
					_turn = randf() * TAU
					_turn_left = WANDER_TURN_SECONDS
				_heading = Vector2.from_angle(_turn)
				var back := Surroundings.herd_cohesion(self, pos, HERD_SPREAD, HERD_REJOIN_RADIUS)
				if back != Vector2.ZERO:
					_heading = back
		Boar.State.FLEE:
			_heading = BoarSenses.flee_heading(pos, hunter_pos, escape_zones).rotated(_scatter)
			speed = boar_type.flee_speed
		Boar.State.CHARGE:
			_charge_heading(delta, pos, hunter_pos)
			speed = boar_type.flee_speed
		_:
			if _turn_left <= 0.0:
				_turn = randf_range(-PANIC_TURN_MAX, PANIC_TURN_MAX)
				_turn_left = PANIC_TURN_SECONDS
			_heading = BoarSenses.flee_heading(pos, hunter_pos, escape_zones).rotated(_turn + _scatter)
			speed = boar_type.panic_speed
	if _forced_left > 0.0 and boar.state != Boar.State.CHARGE:
		_heading = _forced_heading
	if _wading > 0:
		speed *= WADE_SPEED_SCALE
	velocity.x = _heading.x * speed
	velocity.z = _heading.y * speed
	if _heading != Vector2.ZERO:
		rotation.y = atan2(-_heading.x, -_heading.y)


## Runs at the hunter; once close it locks its line and dashes through him (playtest 2026-10-27).
func _charge_heading(delta: float, pos: Vector2, hunter_pos: Vector2) -> void:
	if not boar.ramming:
		_heading = (hunter_pos - pos).normalized()
		if pos.distance_to(hunter_pos) <= RAM_DASH_DISTANCE:
			boar.ramming = true
			$Model.attack()
			$Sounds.attack()
			_dash_heading = _heading
			_dash_left = RAM_DASH_SECONDS
			_dash_hit = false
			add_collision_exception_with(hunter)
		return
	_heading = _dash_heading
	if not _dash_hit and global_position.distance_to(hunter.global_position) <= RAM_HIT_DISTANCE:
		_dash_hit = true
		var push := Vector3(_dash_heading.x, 0.0, _dash_heading.y)
		hunter.knock(push * RAM_IMPULSE + Vector3.UP * 3.0, boar_type.damage * HP_PER_DAMAGE, boar_type)
	_dash_left -= delta
	if _dash_left <= 0.0:
		remove_collision_exception_with(hunter)
		boar.end_charge()
		_state_time = 0.0
		_show_state()


func _apply_knock(delta: float) -> void:
	velocity.x += _knock.x
	velocity.z += _knock.z
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * RAM_IMPULSE * delta)


## A fast boar that touches the hunter or another boar knocks it back (M005); walls and fences turn it round.
func _ram(delta: float) -> void:
	_ram_cooldown -= delta
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider()
		if other.has_method("knock") and _ram_cooldown <= 0.0 and Vector2(velocity.x, velocity.z).length() >= RAM_MIN_SPEED:
			var push := Vector3(velocity.x, 0.0, velocity.z).normalized()
			var charging := boar.state == Boar.State.CHARGE
			other.knock(push * RAM_IMPULSE + Vector3.UP * 3.0, boar_type.damage * HP_PER_DAMAGE if charging else 0, boar_type)
			_ram_cooldown = RAM_COOLDOWN
			if charging:
				boar.end_charge()
				_state_time = 0.0
				_show_state()
		elif absf(hit.get_normal().y) < 0.5 and not boar.ramming:
			# Fence (D024) or wall (playtest 2026-10-27): turn round and run off roughly along its normal.
			var normal := Vector2(hit.get_normal().x, hit.get_normal().z).normalized()
			if _forced_left <= 0.0 or _forced_heading.dot(normal) < 0.0:
				_forced_heading = normal.rotated(randf_range(-WALL_TURN_SPREAD, WALL_TURN_SPREAD))
				_forced_left = FENCE_TURN_SECONDS
				if boar.state == Boar.State.WANDER:
					_turn = _forced_heading.angle()


## Name of the current domain state, e.g. "FLEE".
func state_name() -> String:
	return Boar.State.keys()[boar.state]


## Final outcomes only; a trapped boar is counted by the map when the hunt ends.
func _report_outcome() -> void:
	var kind := boar.outcome_kind()
	if kind != BoarOutcome.Kind.NONE and not _reported and boar.state != Boar.State.TRAPPED:
		_reported = true
		outcome_reached.emit(boar_type.id, kind, boar.is_wounded())


func _show_state() -> void:
	_label.text = state_name()
	$Sounds.running = boar.state in [Boar.State.FLEE, Boar.State.PANIC, Boar.State.CHARGE]
	$Sounds.panicking = boar.state == Boar.State.PANIC
	# Health bar over the boar, green when full, red when nearly dead (section 16); shrinks to its centre.
	var ratio := float(boar.health) / boar_type.max_health
	_health_fill.scale.x = maxf(ratio, 0.001)
	(_health_fill.material_override as StandardMaterial3D).albedo_color = Color.RED.lerp(Color.GREEN, ratio)
