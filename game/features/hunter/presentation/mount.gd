extends StaticBody3D

## A saddled boar waiting for its rider on the hunt map (D021).

const BoarType = preload("res://game/features/boar/public/boar_type.gd")

var boar_type: BoarType


func _ready() -> void:
	var hide := StandardMaterial3D.new()
	hide.albedo_color = boar_type.color
	$Body.material_override = hide
	$Label.text = "%s — ride [E]" % boar_type.display_name


## Hidden and without collision while ridden.
func set_ridden(ridden: bool) -> void:
	visible = not ridden
	$Collision.disabled = ridden
