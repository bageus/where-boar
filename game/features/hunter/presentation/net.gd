extends RigidBody3D

## Thrown net: captures the first boar or wild helper animal it touches (M004). A miss lies on the
## ground; a net on a caught boar is taken back by walking up to it (owner, 2026-10-27).

const Landing = preload("res://game/features/hunter/presentation/landing.gd")

var pickup_kind := "net"

## The boar this net is stuck on, if any.
var holder: Node3D
var _landed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _landed:
		return
	_landed = true
	# Boars and wild roosters/turkeys both answer net_hit; the hunter does not know helper animals.
	if body.has_method("net_hit"):
		body.net_hit()
	Landing.land(self, body)
