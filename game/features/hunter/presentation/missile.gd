extends RigidBody3D

## Sling stone or arrow: hurts the first boar it touches (D022), then an arrow sticks in it, a stone bounces off, or it lies where it
## landed, to be taken back (owner, 2026-10-27).

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Landing = preload("res://game/features/hunter/presentation/landing.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")

@export var damage := 1
## "arrow" or "stone"; "" would make the missile vanish on contact.
@export var pickup_kind := ""

## The boar this arrow is stuck in, if any.
var holder: Node3D

var _landed := false
var _hurt := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _landed:
		return
	var hits := body is BoarBody or body.has_method("spear_hit")
	if hits and _hurt:
		return
	# Heard where it lands, only by whoever is near (owner, 2026-10-29).
	Sfx.play(self, "rock_fell" if pickup_kind == "stone" else "arrow_fell", 0.0, 20.0)
	if hits:
		_hurt = true
		body.spear_hit(damage)
		if pickup_kind == "stone":  # bounces off and drops to the ground (owner, 2026-10-28)
			linear_velocity = Vector3(-linear_velocity.x, 3.0, -linear_velocity.z) * 0.3
			return
	_landed = true
	if pickup_kind == "":
		queue_free()
	else:
		Landing.land(self, body)
