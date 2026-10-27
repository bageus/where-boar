extends Area3D

## River water: passable, but slows the hunter and animals wading through it (section 11).


func _ready() -> void:
	body_entered.connect(func(body: Node3D) -> void: _wade(body, true))
	body_exited.connect(func(body: Node3D) -> void: _wade(body, false))


func _wade(body: Node3D, entered: bool) -> void:
	if body.has_method("wade"):
		body.wade(entered)
