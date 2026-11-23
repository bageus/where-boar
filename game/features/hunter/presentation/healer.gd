extends "res://game/features/hunter/presentation/trap_setter.gd"

## The hired healer (issue #12, owner's comment): trails the hunter at a distance and heals him while
## he stands next to him.

const Plump = preload("res://assets/models/peak_cavemen/plump.glb")

## ASSUMPTION (D013).
const TRAIL_DISTANCE := 6.0
const HEAL_RADIUS := 2.5
const HEAL_PER_SECOND := 10.0

var _heal := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if hunter.global_position.distance_to(global_position) > HEAL_RADIUS or hunter.health.value >= hunter.health.MAX:
		return
	_heal += HEAL_PER_SECOND * delta
	if _heal >= 1.0:
		hunter.health.heal(int(_heal))
		_heal -= int(_heal)
		hunter.get_node("Hud").show_health(hunter.health.value)


func _body() -> PackedScene:
	return Plump


func _target() -> Node3D:
	return null


func _stop_at(_site: Node3D, _distance: float) -> float:
	return TRAIL_DISTANCE
