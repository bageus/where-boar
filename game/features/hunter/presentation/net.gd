extends RigidBody3D

## Thrown net: captures the first boar it touches, otherwise lies on the ground (M004).

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")

var _landed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _landed:
		return
	_landed = true
	if body is BoarBody:
		body.net_hit()
		queue_free()
		return
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
