extends CharacterBody3D

## First-person hunter: movement, stamina, health and weapons (M001, M003, M004, D022).

const Stamina = preload("res://game/features/hunter/domain/stamina.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")
const Health = preload("res://game/features/hunter/domain/health.gd")
const Synth = preload("res://game/core/synth/public/synth.gd")
const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Spear = preload("res://game/features/hunter/presentation/spear.gd")
const SpearScene = preload("res://game/features/hunter/presentation/spear.tscn")
const NetScene = preload("res://game/features/hunter/presentation/net.tscn")
const StoneScene = preload("res://game/features/hunter/presentation/stone.tscn")
const ArrowScene = preload("res://game/features/hunter/presentation/arrow.tscn")
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
const STAB_DAMAGE := 1
const CLUB_DAMAGE := 2
const CLUB_KNOCK := 6.0
const SLING_SPEED := 24.0
const ARROW_SPEED := 32.0
const PICKUP_RADIUS := 2.5
const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const STUN_SECONDS := 1.0
## Camera roll when knocked down (M005), kept small against motion sickness.
const KNOCK_ROLL := 0.6
## ASSUMPTION (D013): one shout every 2 s.
const SHOUT_COOLDOWN := 2.0
## Stamina one sip of water gives back (M012, ASSUMPTION).
const WATER_STAMINA := 40.0

const Weapon = Loadout.Weapon
const WEAPON_NAMES := ["Spear", "Net", "Club", "Sling", "Bow"]

## Fact: the hunter pressed interact (E); the map decides what it means, e.g. return to camp.
signal interacted
## Fact: health reached zero; the hunt ends and the hunter goes back to camp with the loot.
signal downed
## Fact: the hunter shouted (M014); the map scares boars in earshot.
signal shouted(at: Vector3)
## Fact: bait was put on the ground (M011); the map shows it to boars.
signal bait_placed(bait: Node3D)

var stamina := Stamina.new()
var health := Health.new()
var loadout := Loadout.new()
var weapon: Loadout.Weapon = Weapon.SPEAR
## Spears and nets this hunter threw that are still in the world.
var _thrown: Array[RigidBody3D] = []
var _stun := 0.0
var _shout_cooldown := 0.0
## From the settings screen (section 16).
var mouse_sensitivity := 0.002
## Off reduces camera motion (knockback roll) for players who get motion sick.
var camera_motion := true

@onready var _camera: Camera3D = $Camera
@onready var _reach: RayCast3D = $Camera/Reach
@onready var _stamina_bar: ProgressBar = $Hud/Stamina
@onready var _health_bar: ProgressBar = $Hud/Health
@onready var _hotbar: HBoxContainer = $Hud/Hotbar
@onready var _bait_label: Label = $Hud/Bait


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_reach.add_exception(self)
	$Thud.stream = Synth.thud()
	for weapon_name in WEAPON_NAMES:
		var slot := Label.new()
		slot.add_theme_font_size_override("font_size", 22)
		_hotbar.add_child(slot)
	_update_hud()


## Applies player settings: {"fov", "mouse_sensitivity", "camera_motion"} (section 16).
func apply_settings(settings: Dictionary) -> void:
	_camera.fov = settings["fov"]
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
			_attack()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		_pick_up()
		interacted.emit()
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
		for i in WEAPON_NAMES.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)) and loadout.has(i):
				weapon = i
	_update_hud()


## Rammed by a boar (M005): thrown back, hurt by a charge, and out of control for a moment.
func knock(impulse: Vector3, damage: int = 0) -> void:
	velocity = impulse
	_stun = STUN_SECONDS
	$Thud.play()
	if camera_motion:
		var roll := create_tween()
		roll.tween_property(_camera, "rotation:z", KNOCK_ROLL * (1 if randf() < 0.5 else -1), 0.15)
		roll.tween_property(_camera, "rotation:z", 0.0, STUN_SECONDS - 0.15)
	if health.is_down():
		return
	health.take(damage)
	_health_bar.value = health.value
	if health.is_down():
		downed.emit()


## Called when a hunt starts: the best camp meal is eaten for extra stamina (M012).
func start_hunt() -> void:
	stamina.eat(loadout.eat_best_meal())
	_stamina_bar.max_value = stamina.max_value
	_stamina_bar.value = stamina.value


## Scares boars in earshot sideways (M014); limited by a short cooldown.
func shout() -> void:
	if _shout_cooldown > 0.0:
		return
	_shout_cooldown = SHOUT_COOLDOWN
	shouted.emit(global_position)


func _place_bait() -> void:
	var item_id := loadout.place_bait()
	if item_id == "":
		return
	var bait: Node3D = BaitScene.instantiate()
	bait.item_id = item_id
	bait.top_level = true
	add_child(bait)
	bait.global_position = global_position - global_basis.z * 1.0
	bait_placed.emit(bait)


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
	add_child(trap)
	trap.global_transform = where
	_update_hud()
	return true


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
	var crouching := Input.is_action_pressed("crouch")
	var sprinting := stamina.tick(delta, Input.is_action_pressed("sprint") and not crouching and input != Vector2.ZERO)
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	if is_on_floor():
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if Input.is_action_just_pressed("jump"):
			_jump_or_lunge(direction)
	else:
		velocity += get_gravity() * delta
	_camera.position.y = CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
	move_and_slide()
	_stamina_bar.value = stamina.value


## Space with a direction is a lunge (M001); without one, or without stamina, a plain jump.
func _jump_or_lunge(direction: Vector3) -> void:
	if direction != Vector3.ZERO and stamina.try_lunge():
		velocity.x = direction.x * LUNGE_SPEED
		velocity.z = direction.z * LUNGE_SPEED
		velocity.y = JUMP_SPEED * 0.5
	else:
		velocity.y = JUMP_SPEED


## LMB stabs with the spear, RMB+LMB throws it; with the net selected LMB throws a net (M003, M004).
func _attack() -> void:
	match weapon:
		Weapon.SPEAR:
			if Input.is_action_pressed("aim"):
				if loadout.throw_spear():
					_throw(SpearScene)
			elif loadout.spear_in_hand and _reach.get_collider() is BoarBody:
				_reach.get_collider().spear_hit(STAB_DAMAGE)
		Weapon.NET:
			if loadout.throw_net():
				_throw(NetScene)
		Weapon.CLUB:
			var target := _reach.get_collider()
			if target is BoarBody:
				target.spear_hit(CLUB_DAMAGE)
				target.knock(-_camera.global_basis.z * CLUB_KNOCK)
		Weapon.SLING:
			_throw(StoneScene, SLING_SPEED, false)
		Weapon.BOW:
			if loadout.shoot_arrow():
				_throw(ArrowScene, ARROW_SPEED, false)


## Launches an item from the eye; kept ones (spear, net) can be picked up again.
func _throw(scene: PackedScene, speed: float = THROW_SPEED, keep: bool = true) -> void:
	var item: RigidBody3D = scene.instantiate()
	item.top_level = true
	add_child(item)
	item.global_transform = _camera.global_transform.translated_local(Vector3(0.0, 0.0, -0.8))
	item.linear_velocity = -_camera.global_basis.z * speed
	item.add_collision_exception_with(self)
	if keep:
		_thrown.append(item)


func _pick_up() -> void:
	_thrown = _thrown.filter(func(item: RigidBody3D) -> bool: return is_instance_valid(item))
	for item in _thrown.duplicate():
		if item.global_position.distance_to(global_position) > PICKUP_RADIUS:
			continue
		if item is Spear:
			loadout.pick_spear()
		else:
			loadout.pick_net()
		_thrown.erase(item)
		item.queue_free()


func _update_hud() -> void:
	var extras := [
		" (in hand)" if loadout.spear_in_hand else " (thrown)",
		" x%d" % loadout.nets,
		"",
		"",
		" x%d" % loadout.arrows,
	]
	for i in WEAPON_NAMES.size():
		var slot: Label = _hotbar.get_child(i)
		slot.visible = loadout.has(i)
		slot.text = "[%d] %s%s" % [i + 1, WEAPON_NAMES[i], extras[i]]
		slot.modulate = Color.YELLOW if weapon == i else Color.WHITE
	var bait_counts := PackedStringArray()
	for item_id in Loadout.BAIT_IDS:
		bait_counts.append("%s %d" % [item_id.trim_prefix("item_"), loadout.baits.get(item_id, 0)])
	var trap_id := loadout.selected_trap()
	_bait_label.text = "[F] Bait: %s    [R] Shout    [G/T] Trap: %s x%d    [Q] Water x%d" % [
		", ".join(bait_counts), trap_id.trim_prefix("item_"), loadout.traps.get(trap_id, 0), loadout.water_sips]
