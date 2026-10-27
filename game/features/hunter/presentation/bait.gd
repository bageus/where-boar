extends Node3D

## Bait on the ground (M011): calm boars within attract_radius come to eat it until it is gone.

## item_id -> [pull radius m, seconds it lasts, colour]; ASSUMPTION numbers (D013).
const KINDS := {
	"item_acorns": [12.0, 20.0, Color(0.55, 0.35, 0.15)],
	"item_carrot": [18.0, 25.0, Color(1.0, 0.5, 0.1)],
	"item_apple": [18.0, 35.0, Color(0.85, 0.1, 0.1)],
}

@export var item_id := "item_acorns"

var attract_radius := 12.0


func _ready() -> void:
	var kind: Array = KINDS[item_id]
	attract_radius = kind[0]
	var paint := StandardMaterial3D.new()
	paint.albedo_color = kind[2]
	$Mesh.material_override = paint
	get_tree().create_timer(kind[1]).timeout.connect(queue_free)
