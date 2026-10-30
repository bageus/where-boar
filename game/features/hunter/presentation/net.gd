extends RigidBody3D

## Thrown net: captures the first boar or wild helper animal it touches (M004). A miss lies on the
## ground; a net on a caught boar is taken back by walking up to it (owner, 2026-10-27).

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Landing = preload("res://game/features/hunter/presentation/landing.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")

var pickup_kind := "net"

## The boar this net is stuck on, if any.
var holder: Node3D
var _landed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Model.open()


func _on_body_entered(body: Node) -> void:
	if _landed:
		return
	_landed = true
	Sfx.play(self, "net_fell", 0.0, 20.0)
	# Anything but a boar or helper animal (tree, rock): drop straight down, never freeze mid-air.
	if not body.has_method("net_hit") and not body.get_parent() is BoarBody:
		linear_velocity = Vector3.ZERO
		set_deferred("collision_mask", 1)
		return
	# Boars and wild roosters/turkeys both answer net_hit; the hunter does not know helper animals.
	if body.has_method("net_hit"):
		body.net_hit()
	Landing.land(self, body)
	var boar: Node = body if body is BoarBody else body.get_parent()
	if boar is BoarBody:
		$Model.wrap(boar.get_node("Model"))
