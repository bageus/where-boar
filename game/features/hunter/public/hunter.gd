extends CharacterBody3D

## First-person hunter: movement, stamina, spear and net (M001, M003, M004).

const Stamina = preload("res://game/features/hunter/domain/stamina.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")
const Health = preload("res://game/features/hunter/domain/health.gd")
const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Spear = preload("res://game/features/hunter/presentation/spear.gd")
const SpearScene = preload("res://game/features/hunter/presentation/spear.tscn")
const NetScene = preload("res://game/features/hunter/presentation/net.tscn")

# ASSUMPTION numbers (D013), tuned in phase 2.
const WALK_SPEED := 4.0
const SPRINT_SPEED := 7.0
const CROUCH_SPEED := 2.0
const JUMP_SPEED := 4.5
const LUNGE_SPEED := 10.0
const THROW_SPEED := 18.0
const STAB_DAMAGE := 1
const PICKUP_RADIUS := 2.5
const MOUSE_SENSITIVITY := 0.002
const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.0
const STUN_SECONDS := 1.0

enum Weapon { SPEAR, NET }

## Fact: the hunter pressed interact (E); the map decides what it means, e.g. return to camp.
signal interacted
## Fact: health reached zero; the hunt ends and the hunter goes back to camp with the loot.
signal downed

var stamina := Stamina.new()
var health := Health.new()
var loadout := Loadout.new()
var weapon := Weapon.SPEAR
## Spears and nets this hunter threw that are still in the world.
var _thrown: Array[RigidBody3D] = []
var _stun := 0.0

@onready var _camera: Camera3D = $Camera
@onready var _reach: RayCast3D = $Camera/Reach
@onready var _stamina_bar: ProgressBar = $Hud/Stamina
@onready var _health_bar: ProgressBar = $Hud/Health
@onready var _slot_spear: Label = $Hud/Hotbar/Spear
@onready var _slot_net: Label = $Hud/Hotbar/Net


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_reach.add_exception(self)
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
	elif event.is_action_pressed("weapon_1"):
		weapon = Weapon.SPEAR
	elif event.is_action_pressed("weapon_2"):
		weapon = Weapon.NET
	elif event.is_action_pressed("interact"):
		_pick_up()
		interacted.emit()
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


func _throw(scene: PackedScene) -> void:
	var item: RigidBody3D = scene.instantiate()
	item.top_level = true
	add_child(item)
	item.global_transform = _camera.global_transform.translated_local(Vector3(0.0, 0.0, -0.8))
	item.linear_velocity = -_camera.global_basis.z * THROW_SPEED
	item.add_collision_exception_with(self)
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
	_slot_spear.text = "[1] Spear (%s)" % ("in hand" if loadout.spear_in_hand else "thrown")
	_slot_net.text = "[2] Net x%d" % loadout.nets
	_slot_spear.modulate = Color.YELLOW if weapon == Weapon.SPEAR else Color.WHITE
	_slot_net.modulate = Color.YELLOW if weapon == Weapon.NET else Color.WHITE
