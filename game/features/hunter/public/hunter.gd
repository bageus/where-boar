extends CharacterBody3D

## First-person hunter: movement, stamina, health and weapons (M001, M003, M004, D022).

const Stamina = preload("res://game/features/hunter/domain/stamina.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")
const Health = preload("res://game/features/hunter/domain/health.gd")
const Synth = preload("res://game/core/synth/public/synth.gd")
const Ride = preload("res://game/features/hunter/domain/ride.gd")
const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const SpearScene = preload("res://game/features/hunter/presentation/spear.tscn")
const NetScene = preload("res://game/features/hunter/presentation/net.tscn")
const StoneScene = preload("res://game/features/hunter/presentation/stone.tscn")
const ArrowScene = preload("res://game/features/hunter/presentation/arrow.tscn")
const Landing = preload("res://game/features/hunter/presentation/landing.gd")
const BaitScene = preload("res://game/features/hunter/presentation/bait.tscn")
const TRAP_SCENES := {
	"item_pit": preload("res://game/features/hunter/presentation/traps/pit.tscn"),
	"item_snare": preload("res://game/features/hunter/presentation/traps/snare.tscn"),
	"item_tripwire": preload("res://game/features/hunter/presentation/traps/tripwire.tscn"),
	"item_cage": preload("res://game/features/hunter/presentation/traps/cage.tscn"),
	"item_fence": preload("res://game/features/hunter/presentation/traps/fence.tscn"),
}

# ASSUMPTION numbers (D013), tuned in phase 2.
const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const JUMP_SPEED := 4.5
const LUNGE_SPEED := 10.0
const THROW_SPEED := 18.0
## Holding the aim charges the throw over AIM_CHARGE_SECONDS; power scales the spear's speed and range.
const AIM_CHARGE_SECONDS := 1.0
const WEAK_THROW_SCALE := 0.5
const STRONG_THROW_SCALE := 1.4
# Melee: knife < spear stab < club in damage, club < spear in reach, knife shortest (owner, 2026-10-27).
const KNIFE_DAMAGE := 1
const KNIFE_REACH := 1.2
const STAB_DAMAGE := 2
const CLUB_DAMAGE := 3
const CLUB_KNOCK := 6.0
## The club hits harder than the spear but reaches less far (owner, 2026-10-27).
const CLUB_REACH := 1.8
## Holding LMB charges these weapons (owner, 2026-10-27); a full charge doubles knife, club and bow damage
## and sends nets and sling stones CHARGED_RANGE_SCALE times faster (so further).
const CHARGED_WEAPONS := [
	Loadout.Weapon.NET, Loadout.Weapon.CLUB, Loadout.Weapon.SLING, Loadout.Weapon.BOW, Loadout.Weapon.KNIFE,
]
const CHARGED_DAMAGE_SCALE := 2.0
const CHARGED_RANGE_SCALE := 1.6
const SLING_SPEED := 24.0
const ARROW_SPEED := 32.0
const PICKUP_RADIUS := 2.5
const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const STUN_SECONDS := 1.0
## Camera roll when knocked down (M005), kept small against motion sickness.
const KNOCK_ROLL := 0.6
const SADDLE_EYE_RISE := 0.6
## ASSUMPTION (D013): one shout every 2 s.
const SHOUT_COOLDOWN := 2.0
## Speed share left while wading through a river (ASSUMPTION).
const WADE_SPEED_SCALE := 0.5
## Field of view share while aiming the spear, so aim mode is visible (M003).
const AIM_ZOOM := 0.75
## Stamina one sip of water gives back (M012, ASSUMPTION).
const WATER_STAMINA := 40.0

const Weapon = Loadout.Weapon

## Fact: the hunter pressed interact (E); the map decides what it means, e.g. return to camp.
signal interacted
## Fact: health reached zero; the hunt ends and the hunter goes back to camp with the loot.
signal downed
## Fact: the hunter shouted (M014); the map scares boars in earshot.
signal shouted(at: Vector3)
## Fact: bait was put on the ground (M011); the map shows it to boars.
signal bait_placed(bait: Node3D)

var stamina := Stamina.new()
var ride := Ride.new()
var health := Health.new()
var loadout := Loadout.new()
var weapon: Loadout.Weapon = Weapon.SPEAR
## Spears and nets this hunter threw that are still in the world.
var _thrown: Array[RigidBody3D] = []
var _stun := 0.0
var _steer_in_air := false
var _shout_cooldown := 0.0
## River segments the hunter is standing in; rivers call wade().
var _wading := 0
var _base_fov := 80.0
## Attack power 0..1: charged while aiming the spear (RMB) or holding LMB with a charged weapon.
var _aim_power := 0.0
var _holding_attack := false
## From the settings screen (section 16).
var mouse_sensitivity := 0.002
## Off reduces camera motion (knockback roll) for players who get motion sick.
var camera_motion := true
## Caps Lock toggles sneaking (owner's choice, 2026-10-27).
# shortcut: our own toggle, not the OS lock state (Godot does not expose it), so the
# keyboard light can disagree if Caps Lock was on before the hunt; fine until playtest says otherwise.
var crouching := false

@onready var _camera: Camera3D = $Camera
@onready var _reach: RayCast3D = $Camera/Reach
@onready var _hud: CanvasLayer = $Hud


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_reach.add_exception(self)
	_base_fov = _camera.fov
	$Thud.stream = Synth.thud()
	$Voice.stream = Synth.shout()
	_update_hud()


## Applies player settings: {"fov", "mouse_sensitivity", "camera_motion"} (section 16).
func apply_settings(settings: Dictionary) -> void:
	_base_fov = settings["fov"]
	_camera.fov = _base_fov
	mouse_sensitivity = settings["mouse_sensitivity"]
	camera_motion = settings["camera_motion"]


## Gives the hunter the weapons bought in camp (item_id -> count).
func equip(items: Dictionary) -> void:
	loadout.equip(items)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_camera.rotation.x = clampf(_camera.rotation.x - event.relative.y * mouse_sensitivity, -1.5, 1.5)
	elif event.is_action_pressed("attack"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if weapon in CHARGED_WEAPONS and ride.allows(weapon, false):
				_holding_attack = true
			else:
				_attack()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_released("attack") and _holding_attack:
		_holding_attack = false
		_attack()
	elif event.is_action_pressed("interact"):
		_pick_up()
		$Rider.toggle()
		interacted.emit()
	elif event.is_action_pressed("crouch"):
		crouching = not crouching
	elif event.is_action_pressed("shout"):
		shout()
	elif event.is_action_pressed("bait"):
		_place_bait()
	elif event.is_action_pressed("drink"):
		if loadout.drink():
			stamina.drink(WATER_STAMINA)
	elif event.is_action_pressed("trap_next"):
		loadout.cycle_trap()
	elif event.is_action_pressed("trap_place"):
		place_trap()
	else:
		for i in Loadout.Weapon.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)) and loadout.has(i):
				weapon = i
	_update_hud()


## Rammed by a boar (M005): thrown back, hurt by a charge, and out of control for a moment.
func knock(impulse: Vector3, damage: int = 0) -> void:
	$Thud.play()
	if not ride.shrugs_off_knock():
		velocity = impulse
		_stun = STUN_SECONDS
	if camera_motion and _stun > 0.0:
		var roll := create_tween()
		roll.tween_property(_camera, "rotation:z", KNOCK_ROLL * (1 if randf() < 0.5 else -1), 0.15)
		roll.tween_property(_camera, "rotation:z", 0.0, STUN_SECONDS - 0.15)
	if health.is_down():
		return
	health.take(damage)
	_hud.show_health(health.value)
	if health.is_down():
		downed.emit()


## A river calls this when the hunter steps in (true) or out (false).
func wade(entered: bool) -> void:
	_wading += 1 if entered else -1


## The saddled boar brought on this hunt, or null.
func mount_node() -> Node3D:
	return $Rider.mount


## Called when a hunt starts: camp meals are eaten and raise max stamina for the hunt (M012),
## and the first saddled boar waits beside the hunter.
func start_hunt() -> void:
	if not loadout.saddled.is_empty():
		$Rider.bring_mount(loadout.saddled[0])
	stamina.eat(loadout.eat_meals())
	_hud.show_stamina(stamina.value, stamina.max_value)


## Scares boars in earshot sideways (M014); limited by a short cooldown.
func shout() -> void:
	if _shout_cooldown > 0.0:
		return
	_shout_cooldown = SHOUT_COOLDOWN
	$Voice.play()
	shouted.emit(global_position)


func _place_bait() -> void:
	var item_id := loadout.place_bait()
	if item_id == "":
		return
	var bait: Node3D = BaitScene.instantiate()
	bait.item_id = item_id
	bait.top_level = true
	add_child(bait)
	bait.global_position = ground_at(global_position - global_basis.z * 1.0)
	bait_placed.emit(bait)


## Map props in this group are stone piles; meta "stones" says how many each gives.
const GROUND_STONES_GROUP := "stone_piles"
## Group of every trap the hunter or the trap setter put down; the minimap shows them.
const PLACED_TRAPS_GROUP := "placed_traps"


## Sets the selected trap on the ground 2 m ahead, facing the hunter's way (M015).
func place_trap() -> void:
	_set_trap(loadout.place_trap(), Transform3D(global_basis, global_position - global_basis.z * 2.0))


## The hired trap setter puts any trap from stock at where (M013); false when none is left.
func set_trap_for_hunter(where: Transform3D) -> bool:
	return _set_trap(loadout.place_any_trap(), where)


func _set_trap(item_id: String, where: Transform3D) -> bool:
	if item_id == "":
		return false
	var trap: Node3D = TRAP_SCENES[item_id].instantiate()
	trap.top_level = true
	trap.add_to_group(PLACED_TRAPS_GROUP)
	add_child(trap)
	trap.global_transform = Transform3D(where.basis, ground_at(where.origin))
	_update_hud()
	return true


## The ground under point on the hilly map (owner, 2026-10-27), searched from 2 m above it to 4 m below;
## point itself when nothing is there.
func ground_at(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 4.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if hit else point


func _physics_process(delta: float) -> void:
	_shout_cooldown -= delta
	if _stun > 0.0:
		_stun -= delta
		velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		move_and_slide()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# On a mount the boar runs and the rider rests (D021).
	var wants_sprint := Input.is_action_pressed("sprint") and not crouching and input != Vector2.ZERO and not ride.is_riding()
	var sprinting := stamina.tick(delta, wants_sprint)
	var speed := ride.speed(CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED))
	if _wading > 0:
		speed *= WADE_SPEED_SCALE
	var aiming := (weapon == Weapon.SPEAR and loadout.spear_in_hand and Input.is_action_pressed("aim")) \
			or (_holding_attack and weapon in CHARGED_WEAPONS)
	_aim_power = minf(1.0, _aim_power + delta / AIM_CHARGE_SECONDS) if aiming else 0.0
	var zoom := aiming and weapon != Weapon.CLUB
	_camera.fov = lerpf(_camera.fov, _base_fov * (AIM_ZOOM if zoom else 1.0), minf(1.0, 12.0 * delta))
	_hud.show_throw_power(aiming, _aim_power)
	var armed: bool = {Weapon.SPEAR: loadout.spear_in_hand, Weapon.NET: loadout.nets > 0,
			Weapon.SLING: loadout.stones > 0, Weapon.BOW: loadout.arrows > 0}.get(weapon, true)
	$Camera/Hands.pose(weapon, armed, aiming, _aim_power, delta)
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	if is_on_floor():
		_steer_in_air = false
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		# No jumps or lunges from the saddle, so riding never spends stamina (owner, 2026-10-27).
		if Input.is_action_just_pressed("jump") and not ride.is_riding():
			_jump_or_lunge(direction)
	else:
		velocity += get_gravity() * delta
		if _steer_in_air:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
	_camera.position.y = (CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT) + (SADDLE_EYE_RISE if ride.is_riding() else 0.0)
	move_and_slide()
	$Rider.ram(delta)
	_hud.show_stamina(stamina.value, stamina.max_value)


## Space with a direction is a lunge (M001); without one, without stamina or against a ledge, a plain jump
## that can be steered in the air, so the hunter climbs ledges up to about 1 m (owner, 2026-10-27).
func _jump_or_lunge(direction: Vector3) -> void:
	if direction != Vector3.ZERO and not is_on_wall() and stamina.try_lunge():
		velocity.x = direction.x * LUNGE_SPEED
		velocity.z = direction.z * LUNGE_SPEED
		velocity.y = JUMP_SPEED * 0.5
	else:
		velocity.y = JUMP_SPEED
		_steer_in_air = true


## LMB stabs with the spear, RMB+LMB throws it; club, net, sling and bow fire on LMB release,
## stronger the longer LMB was held (M003, M004).
func _attack() -> void:
	var power := _aim_power
	_aim_power = 0.0
	if not ride.allows(weapon, Input.is_action_pressed("aim")):
		return
	match weapon:
		Weapon.SPEAR:
			if Input.is_action_pressed("aim"):
				if loadout.throw_spear():
					_throw(SpearScene, THROW_SPEED * lerpf(WEAK_THROW_SCALE, STRONG_THROW_SCALE, power))
			elif loadout.spear_in_hand:
				$Camera/Hands.strike()
				if _hits_boar(_reach.get_collider()):
					_reach.get_collider().spear_hit(STAB_DAMAGE)
		Weapon.NET:
			if loadout.throw_net():
				$Camera/Hands.strike()
				_throw(NetScene, THROW_SPEED * lerpf(1.0, CHARGED_RANGE_SCALE, power))
		Weapon.KNIFE:
			$Camera/Hands.strike()
			if _in_reach(KNIFE_REACH):
				_reach.get_collider().spear_hit(roundi(KNIFE_DAMAGE * lerpf(1.0, CHARGED_DAMAGE_SCALE, power)))
		Weapon.CLUB:
			$Camera/Hands.strike()
			var target := _reach.get_collider()
			if _in_reach(CLUB_REACH):
				var scale := lerpf(1.0, CHARGED_DAMAGE_SCALE, power)
				target.spear_hit(roundi(CLUB_DAMAGE * scale))
				if target.has_method("knock"):
					target.knock(-_camera.global_basis.z * CLUB_KNOCK * scale)
		Weapon.SLING:
			if loadout.sling_stone():
				$Camera/Hands.strike()
				_throw(StoneScene, SLING_SPEED * lerpf(1.0, CHARGED_RANGE_SCALE, power))
		Weapon.BOW:
			if loadout.shoot_arrow():
				$Camera/Hands.strike()
				var arrow := _throw(ArrowScene, ARROW_SPEED)
				arrow.damage = roundi(arrow.damage * lerpf(1.0, CHARGED_DAMAGE_SCALE, power))


## True when the reach ray hits something that takes hits within reach metres of the eye.
func _in_reach(reach: float) -> bool:
	var target := _reach.get_collider()
	return _hits_boar(target) and _reach.get_collision_point().distance_to(_camera.global_position) <= reach


## A boar, its larger hitbox or a wild bird; the hunter's mount does not take hits.
func _hits_boar(target: Object) -> bool:
	return target is BoarBody or (target != null and target.has_method("spear_hit"))


## Launches an item from the eye; kept ones (spear, net, arrow) can be picked up again.
func _throw(scene: PackedScene, speed: float = THROW_SPEED, keep: bool = true) -> RigidBody3D:
	var item: RigidBody3D = scene.instantiate()
	item.top_level = true
	add_child(item)
	item.global_transform = _camera.global_transform.translated_local(Vector3(0.0, 0.0, -0.8))
	item.linear_velocity = -_camera.global_basis.z * speed
	item.add_collision_exception_with(self)
	if keep:
		_thrown.append(item)
	return item


func _pick_up() -> void:
	# Untyped: a typed lambda cannot take a freed item (one that left with an escaped boar).
	_thrown = _thrown.filter(func(item) -> bool: return is_instance_valid(item))
	for item in _thrown.duplicate():
		if item.global_position.distance_to(global_position) > PICKUP_RADIUS or not Landing.can_pick(item):
			continue
		match item.pickup_kind:
			"spear":
				loadout.pick_spear()
			"net":
				loadout.pick_net()
			"arrow":
				loadout.pick_arrow()
			"stone":
				loadout.pick_stones(1)
		_thrown.erase(item)
		item.queue_free()
	# Stone piles lying around the map (owner, 2026-10-27).
	for pile: Node3D in get_tree().get_nodes_in_group(GROUND_STONES_GROUP):
		if pile.global_position.distance_to(global_position) <= PICKUP_RADIUS:
			loadout.pick_stones(pile.get_meta("stones", 1))
			pile.queue_free()


func _update_hud() -> void:
	_hud.show_loadout(loadout, weapon)
