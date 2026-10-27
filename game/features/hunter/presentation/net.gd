extends RigidBody3D

## Thrown net: captures the first boar or wild helper animal it touches and comes back to the hunter;
## a miss lies on the ground to be picked up (M004).

## Fact: the net caught an animal; the hunter takes it back (it never ends up lost).
signal caught

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
		caught.emit()
		queue_free()
		return
	set_deferred("freeze", true)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
