extends RigidBody3D

## Thrown spear: damages the first boar it touches, then stays where it landed (M003).

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")

## ASSUMPTION (D013): a thrown spear hits harder than a stab.
const DAMAGE := 2

var _landed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _landed:
		return
	_landed = true
	# A boar or its larger hitbox (playtest 2026-10-27).
	if body is BoarBody or body.has_method("spear_hit"):
		body.spear_hit(DAMAGE)
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
