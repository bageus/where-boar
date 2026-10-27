extends Node

## The hunter's saddled boar on a hunt (D021): brings it along, mounts and dismounts, and rams with the angry mount.
## Child of the hunter; reads and steers its parent.

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const MountScene = preload("res://game/features/hunter/presentation/mount.tscn")

const MOUNT_REACH := 2.5
# The angry mount's ram, ASSUMPTION numbers (D013).
const RAM_IMPULSE := 12.0
const RAM_DAMAGE := 1
const RAM_COOLDOWN := 1.0

## The saddled boar brought on this hunt, if any.
var mount: StaticBody3D
var _ram_cooldown := 0.0

@onready var _hunter: CharacterBody3D = get_parent()


## Puts the first saddled boar beside the hunter.
func bring_mount(type_id: String) -> void:
	mount = MountScene.instantiate()
	mount.boar_type = BoarTypes.find(type_id)
	mount.top_level = true
	add_child(mount)
	mount.global_position = _hunter.global_position + _hunter.global_basis.x * 1.5


## Mounts the saddled boar when it is in reach, or gets off it.
func toggle() -> void:
	var ride = _hunter.ride
	if ride.is_riding():
		ride.dismount()
		mount.global_position = _hunter.global_position + _hunter.global_basis.x * 1.5
		mount.set_ridden(false)
	elif mount and mount.global_position.distance_to(_hunter.global_position) <= MOUNT_REACH:
		ride.mount(mount.boar_type)
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
			other.spear_hit(RAM_DAMAGE)
			_ram_cooldown = RAM_COOLDOWN
			return
