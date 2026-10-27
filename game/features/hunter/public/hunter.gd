extends CharacterBody3D

## First-person hunter: movement, stamina, health and weapons (M001, M003, M004, D022).

const Stamina = preload("res://game/features/hunter/domain/stamina.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")
const Health = preload("res://game/features/hunter/domain/health.gd")
const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Spear = preload("res://game/features/hunter/presentation/spear.gd")
const SpearScene = preload("res://game/features/hunter/presentation/spear.tscn")
const NetScene = preload("res://game/features/hunter/presentation/net.tscn")
const StoneScene = preload("res://game/features/hunter/presentation/stone.tscn")
const ArrowScene = preload("res://game/features/hunter/presentation/arrow.tscn")

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
const MOUSE_SENSITIVITY := 0.002
const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const STUN_SECONDS := 1.0

const Weapon = Loadout.Weapon
const WEAPON_NAMES := ["Spear", "Net", "Club", "Sling", "Bow"]

## Fact: the hunter pressed interact (E); the map decides what it means, e.g. return to camp.
signal interacted
## Fact: health reached zero; the hunt ends and the hunter goes back to camp with the loot.
signal downed

var stamina := Stamina.new()
var health := Health.new()
var loadout := Loadout.new()
var weapon: Loadout.Weapon = Weapon.SPEAR
## Spears and nets this hunter threw that are still in the world.
var _thrown: Array[RigidBody3D] = []
var _stun := 0.0

@onready var _camera: Camera3D = $Camera
@onready var _reach: RayCast3D = $Camera/Reach
@onready var _stamina_bar: ProgressBar = $Hud/Stamina
@onready var _health_bar: ProgressBar = $Hud/Health
@onready var _hotbar: HBoxContainer = $Hud/Hotbar


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_reach.add_exception(self)
	for weapon_name in WEAPON_NAMES:
		var slot := Label.new()
		slot.add_theme_font_size_override("font_size", 22)
		_hotbar.add_child(slot)
	_update_hud()


## Gives the hunter the weapons bought in camp (item_id -> count).
func equip(items: Dictionary) -> void:
	loadout.equip(items)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_camera.rotation.x = clampf(_camera.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.5, 1.5)
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("attack"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_attack()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact"):
		_pick_up()
		interacted.emit()
	else:
		for i in WEAPON_NAMES.size():
			if event.is_action_pressed("weapon_%d" % (i + 1)) and loadout.has(i):
				weapon = i
	_update_hud()


## Rammed by a boar (M005): thrown back, hurt by a charge, and out of control for a moment.
func knock(impulse: Vector3, damage: int = 0) -> void:
	velocity = impulse
	_stun = STUN_SECONDS
	if health.is_down():
		return
	health.take(damage)
	_health_bar.value = health.value
	if health.is_down():
		downed.emit()


func _physics_process(delta: float) -> void:
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
