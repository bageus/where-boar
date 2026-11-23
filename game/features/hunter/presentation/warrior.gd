extends "res://game/features/hunter/presentation/trap_setter.gd"

## The hired warrior (issue #12): follows the hunter and joins in on boars that are already running or
## charging near him, striking them with his club. He leaves calm boars alone so he does not spoil a stalk.

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const Bearded = preload("res://assets/models/peak_cavemen/bearded.glb")

## Boars this close to the hunter are his fight; ASSUMPTION (D013), like the numbers below.
const ENGAGE_RADIUS := 15.0
const STRIKE_REACH := 1.8
const STRIKE_SECONDS := 1.5
const DAMAGE := 1

var _cooldown := 0.0


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	super(delta)


func _body() -> PackedScene:
	return Bearded


func _target() -> Node3D:
	var best: Node3D = null
	for boar: Node3D in BoarBody.near(get_world_3d(), hunter.global_position, ENGAGE_RADIUS):
		if boar.state_name() in ["FLEE", "PANIC", "CHARGE"] and (best == null \
				or boar.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = boar
	return best


func _stop_at(site: Node3D, _distance: float) -> float:
	return STRIKE_REACH * 0.8 if site else FOLLOW_DISTANCE


func _work(site: Node3D, _delta: float) -> String:
	if _cooldown <= 0.0:
		_cooldown = STRIKE_SECONDS
		Sfx.play(site, "club_hit", 0.0, 20.0)
		site.spear_hit(DAMAGE)
	return "attack"
