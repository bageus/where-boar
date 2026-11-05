extends Node

## The hunter's saddled boar on a hunt (D021): brings it along, mounts and dismounts, and rams with the angry mount.
## Child of the hunter; reads and steers its parent.

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const MountScene = preload("res://game/features/hunter/presentation/mount.tscn")

const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const Footsteps = preload("res://game/core/sfx/public/footsteps.gd")
const BoarBump = preload("res://game/features/boar/public/boar_bump.gd")

const MOUNT_REACH := 2.5
# The angry mount's ram, ASSUMPTION numbers (D013).
const VOICE_MIN_SECONDS := 5.0
const VOICE_MAX_SECONDS := 15.0
const RAM_IMPULSE := 12.0
const RAM_DAMAGE := 1
const RAM_COOLDOWN := 1.0

## The saddled boar brought on this hunt, if any.
var mount: StaticBody3D
var _ram_cooldown := 0.0
var _steps: Footsteps
var _voice_left := 0.0
## The saddle-and-gallop take playing over the hooves while the mount moves (owner, 2026-11-05).
var _ride_sound: AudioStreamPlayer3D

@onready var _hunter: CharacterBody3D = get_parent()


## Puts the first saddled boar beside the hunter.
func bring_mount(type_id: String) -> void:
	mount = MountScene.instantiate()
	mount.boar_type = BoarTypes.find(type_id)
	mount.top_level = true
	add_child(mount)
	mount.global_position = _hunter.ground_at(_hunter.global_position + _hunter.global_basis.x * 1.5)


func _ready() -> void:
	_steps = Footsteps.new()
	_steps.ground = "boar_step"
	_steps.stride = 2.5
	_steps.volume_db = -4.0
	_steps.max_distance = 30.0
	_steps.active = false
	_hunter.add_child.call_deferred(_steps)


## While riding: the mount's hooves, and now and then its voice when it stands idle.
func _physics_process(delta: float) -> void:
	var riding: bool = _hunter.ride.is_riding()
	_steps.active = riding and _hunter.is_on_floor()
	if not riding:
		return
	var moving: bool = Vector2(_hunter.velocity.x, _hunter.velocity.z).length() > 0.5
	if moving:
		_voice_left = randf_range(VOICE_MIN_SECONDS, VOICE_MAX_SECONDS)
		if not is_instance_valid(_ride_sound):
			_ride_sound = Sfx.play(_hunter, "riding", -4.0)
		return
	_voice_left -= delta
	if _voice_left <= 0.0:
		_voice_left = randf_range(VOICE_MIN_SECONDS, VOICE_MAX_SECONDS)
		Sfx.play(_hunter, "boar_voice", -4.0, 40.0)


## Mounts the saddled boar when it is in reach, or gets off it.
func toggle(unseated := false) -> void:
	var ride = _hunter.ride
	if ride.is_riding():
		ride.dismount()
		# Thrown off by a ram: the mount stays where it stood.
		var side := 0.0 if unseated else 1.5
		mount.global_position = _hunter.ground_at(_hunter.global_position + _hunter.global_basis.x * side)
		mount.set_ridden(false)
	elif mount and mount.global_position.distance_to(_hunter.global_position) <= MOUNT_REACH:
		ride.mount(mount.boar_type)
		_hunter.crouching = false
		mount.set_ridden(true)


## After the hunter moved: riding the angry mount into a boar rams it.
func ram(delta: float) -> void:
	_ram_cooldown -= delta
	if not _hunter.ride.rams() or _ram_cooldown > 0.0:
		return
	for i in _hunter.get_slide_collision_count():
		var other := _hunter.get_slide_collision(i).get_collider()
		if other is BoarBody:
			other.knock(-_hunter.global_basis.z * RAM_IMPULSE)
			BoarBump.thud(other, null)
			other.spear_hit(RAM_DAMAGE)
			_ram_cooldown = RAM_COOLDOWN
			return
