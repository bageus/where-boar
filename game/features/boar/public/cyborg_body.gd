extends CharacterBody3D

## Cyborg ("terminator") boar on a hunt map (owner, 2026-11-22): the owner's model with a turret on its back
## (energy cannon or machinegun), steered by the domain Cyborg. It hunts the hunter, never flees; bushes and
## tall grass hide the hunter, but seen going in, the cyborg walks in after him and searches.
## Spawned by the invasion (game/presentation/hunt_map/props/invasion_director.gd).

const Cyborg = preload("res://game/features/boar/domain/cyborg.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const Surroundings = preload("res://game/features/boar/presentation/boar_surroundings.gd")
const CyborgShot = preload("res://game/features/boar/presentation/cyborg_shot.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const Footsteps = preload("res://game/core/sfx/public/footsteps.gd")

const MODELS := {
	"cannon": preload("res://assets/models/boar_new/Cyborgs/Cyborg_Boar.glb"),
	"machinegun": preload("res://assets/models/boar_new/Cyborgs/Cyborg_Boar_Machinegun.glb"),
}
const FIRE_ANIMS := {"cannon": "Cannon_Fire", "machinegun": "Machinegun_Burst"}
const SHOT_SOUNDS := {"cannon": "turret_energy", "machinegun": "turret_machinegun"}
## The model is 4.5 m long, head along -X; this makes it ~2.5 m, a third bigger than a large boar (ASSUMPTION).
const MODEL_SCALE := 0.55
## Armour and health in weapon damage (a spear hits for 2, a knife for 1; boars have 2-8 health), ASSUMPTION.
const ARMOR := {"cannon": 6, "machinegun": 4}
const HEALTH := 6
## Walk and Run clips match these ground speeds, m/s (ASSUMPTION).
const WALK_ANIM_SPEED := 1.5
const RUN_ANIM_SPEED := 3.5
## Body turn rate, radians per second.
const TURN_RATE := 2.0
## Sight line from the turret to the hunter's chest, metres.
const EYE_RISE := 1.4
const HUNTER_RISE := 0.8
const COVER_LAYER := 1 << 4
## Patrol: walks to a point this far around the hunter, picking a new one every PATROL_SECONDS,
## so a lost cyborg drifts back toward the hunt (ASSUMPTION).
const PATROL_SPREAD := 15.0
const PATROL_SECONDS := 8.0
## Below this height it fell off the map: reported as gone (no loot) so the hunt can end.
const FALL_LIMIT := -30.0
const CORPSE_SECONDS := 4.0

## Fact: this cyborg's hunt ended; DEAD when killed, ESCAPED when it fell off the map. Same as boar_body.
signal outcome_reached(type_id: String, kind: int, wounded: bool)

## "cannon" (single energy shots) or "machinegun" (bursts); set before add_child.
@export var variant := "cannon"
## Injected by the scene that spawns the cyborg.
var hunter: Node3D
var cyborg: Cyborg

var _model: Node3D
var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _turret := -1
var _barrel := -1
var _turret_rest: Quaternion
var _turret_axis: Vector3
var _steps: Footsteps
var _patrol_target := Vector2.INF
var _patrol_left := 0.0
var _firing_left := 0.0
var _reported := false


func _ready() -> void:
	cyborg = Cyborg.new(Cyborg.Gun.CANNON if variant == "cannon" else Cyborg.Gun.MACHINEGUN, ARMOR[variant], HEALTH)
	_model = MODELS[variant].instantiate()
	_model.rotation.y = -PI / 2.0
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	_player = _model.find_child("AnimationPlayer", true, false)
	_skeleton = _model.find_child("Skeleton3D", true, false)
	_turret = _skeleton.find_bone("turret")
	_barrel = _skeleton.find_bone("barrel")
	_turret_rest = _skeleton.get_bone_rest(_turret).basis.get_rotation_quaternion()
	# Turret yaw turns about the model's up axis, expressed in the turret's parent bone space.
	_turret_axis = (_skeleton.get_bone_global_rest(_skeleton.get_bone_parent(_turret)).basis.inverse() * Vector3.UP).normalized()
	_free_turret()
	_player.play("Walk")
	_steps = Footsteps.new()
	_steps.ground = "cyborg_steps"
	_steps.stride = 1.6
	add_child(_steps)
	_show_bar()


## Clips key the turret in place; drop those keys so the turret aims by code (clips are shared by all cyborgs).
func _free_turret() -> void:
	for clip in _player.get_animation_list():
		var animation := _player.get_animation(clip)
		var track := animation.find_track(NodePath("Cyborg_Boar/Boar_Rig/Skeleton3D:turret"), Animation.TYPE_ROTATION_3D)
		if track != -1:
			animation.remove_track(track)
		if clip in ["Walk", "Run"]:
			animation.loop_mode = Animation.LOOP_LINEAR


func spear_hit(amount: int) -> void:
	if cyborg.is_dead():
		return
	cyborg.take_hit(amount, Vector2(hunter.global_position.x, hunter.global_position.z))
	Sfx.play(self, "bump", 0.0, 25.0)
	_show_bar()
	if cyborg.is_dead():
		_die()


## A net does not hold a cyborg.
func net_hit() -> void:
	pass


## Too heavy to be pushed by a club or a ram.
func knock(_impulse: Vector3, _damage: int = 0, _rammer: Resource = null) -> void:
	pass


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if global_position.y < FALL_LIMIT:
		_report(BoarOutcome.Kind.ESCAPED)
		queue_free()
		return
	if cyborg.is_dead() or hunter == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var pos := Vector2(global_position.x, global_position.z)
	var hunter_pos := Vector2(hunter.global_position.x, hunter.global_position.z)
	var was := cyborg.state
	var sees := pos.distance_to(hunter_pos) <= Cyborg.SIGHT_RANGE \
			and Surroundings.sight_clear(self, hunter, EYE_RISE, HUNTER_RISE, COVER_LAYER)
	var target := cyborg.think(delta, pos, hunter_pos, sees)
	if cyborg.state == Cyborg.State.CHASE and was != Cyborg.State.CHASE:
		Sfx.play(self, "turret_round", 0.0, 30.0)
	if cyborg.state == Cyborg.State.PATROL:
		target = _patrol(delta, pos, hunter_pos)
	var facing := Vector2(-global_basis.z.x, -global_basis.z.z).normalized()
	if cyborg.update_turret(delta, pos, facing, hunter_pos, randf()) > 0:
		_fire()
	_skeleton.set_bone_pose_rotation(_turret, Quaternion(_turret_axis, -cyborg.turret_yaw) * _turret_rest)
	_firing_left -= delta
	if _firing_left > 0.0:
		target = Vector2.INF
	# Standing in range it still turns its body toward the hunter, so he cannot hide behind its turret's arc.
	var face := hunter_pos if target == Vector2.INF and cyborg.state == Cyborg.State.CHASE else target
	_walk(delta, pos, target, face)


func _patrol(delta: float, pos: Vector2, hunter_pos: Vector2) -> Vector2:
	_patrol_left -= delta
	if _patrol_left <= 0.0 or pos.distance_to(_patrol_target) < 1.5:
		_patrol_left = PATROL_SECONDS
		_patrol_target = hunter_pos + Vector2.from_angle(randf() * TAU) * randf() * PATROL_SPREAD
	return _patrol_target


## Turns toward face and walks to target at the cyborg's speed; stands when target is INF.
func _walk(delta: float, pos: Vector2, target: Vector2, face: Vector2) -> void:
	if face != Vector2.INF and pos.distance_to(face) > 0.5:
		rotation.y = rotate_toward(rotation.y, atan2(-(face.x - pos.x), -(face.y - pos.y)), TURN_RATE * delta)
	var speed := 0.0
	if target != Vector2.INF and pos.distance_to(target) > 0.5:
		speed = cyborg.speed()
	var forward := -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
	_steps.active = speed > 0.0
	if _firing_left > 0.0:
		return
	var clip := "Run" if speed > Cyborg.PATROL_SPEED else "Walk"
	if _player.current_animation != clip:
		_player.play(clip, 0.2)
	_player.speed_scale = speed / (RUN_ANIM_SPEED if clip == "Run" else WALK_ANIM_SPEED)


## One round from the barrel at the hunter's chest, where he is now (no lead, so a moving hunter can dodge).
func _fire() -> void:
	var muzzle := _skeleton.global_transform * _skeleton.get_bone_global_pose(_barrel).origin
	var shot := CyborgShot.new()
	var aim := hunter.global_position + Vector3.UP * HUNTER_RISE - muzzle
	shot.direction = aim.normalized()
	shot.speed = cyborg.shot_speed()
	shot.damage = cyborg.shot_damage()
	shot.hunter = hunter
	shot.exclude = [get_rid()]
	if cyborg.gun == Cyborg.Gun.CANNON:
		shot.setup(0.25, 0.5, Color(0.4, 1.0, 0.9))
		shot.impulse = 5.0
	else:
		shot.setup(0.05, 0.5, Color(1.0, 0.85, 0.3))
		shot.impulse = 1.0
	get_parent().add_child(shot)
	shot.global_position = muzzle
	Sfx.play(self, SHOT_SOUNDS[variant], 0.0, 60.0)
	if _firing_left <= 0.0:
		# Plants its feet for the recoil clip (a burst plays it once), which also gives the hunter a moment.
		_player.play(FIRE_ANIMS[variant], 0.1)
		_player.speed_scale = 1.0
		_firing_left = _player.get_animation(FIRE_ANIMS[variant]).length


func _die() -> void:
	_steps.active = false
	_player.pause()
	Sfx.play(self, "boar_death", -6.0, 40.0)
	_report(BoarOutcome.Kind.DEAD)
	var fall := create_tween()
	fall.tween_property(_model, "rotation:x", PI / 2.0, 0.6)
	fall.tween_interval(CORPSE_SECONDS)
	fall.tween_callback(queue_free)


func _report(kind: int) -> void:
	if not _reported:
		_reported = true
		outcome_reached.emit("cyborg_" + variant, kind, cyborg.armor + cyborg.health < ARMOR[variant] + HEALTH)


## Armour shows blue over the green-to-red health.
func _show_bar() -> void:
	$HealthBar.visible = not cyborg.is_dead()
	var fill: MeshInstance3D = $HealthBar/Fill
	var armored := cyborg.armor > 0
	var ratio: float = float(cyborg.armor) / ARMOR[variant] if armored else float(cyborg.health) / HEALTH
	fill.scale.x = maxf(ratio, 0.001)
	(fill.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.6, 1.0) if armored \
			else Color.RED.lerp(Color.GREEN, ratio)
