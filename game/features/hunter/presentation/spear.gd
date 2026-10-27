extends RigidBody3D

## Thrown spear: damages the first boar it touches and sticks in it, or stays where it landed (M003).

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Landing = preload("res://game/features/hunter/presentation/landing.gd")

var pickup_kind := "spear"

## ASSUMPTION (D013): a thrown spear hits harder than a stab.
const DAMAGE := 2

## The boar this spear is stuck in, if any.
var holder: Node3D
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
	Landing.land(self, body)
