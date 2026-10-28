extends StaticBody3D

## A saddled boar waiting for its rider on the hunt map (D021).

const BoarType = preload("res://game/features/boar/public/boar_type.gd")

var boar_type: BoarType


func _ready() -> void:
	$Model.show_type(boar_type)
	$Saddle.position.y = $Model.top() * 0.85  # on the back, below ears and bristles
	$Label.text = "%s — ride [E]" % boar_type.display_name


## Hidden and without collision while ridden.
func set_ridden(ridden: bool) -> void:
	visible = not ridden
	$Collision.disabled = ridden
