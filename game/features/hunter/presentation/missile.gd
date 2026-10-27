extends RigidBody3D

## Sling stone or arrow: hurts the first boar it touches, then disappears (D022).

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")

@export var damage := 1

var _landed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _landed:
		return
	_landed = true
	if body is BoarBody:
		body.spear_hit(damage)
	queue_free()
