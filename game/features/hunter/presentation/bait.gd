extends Node3D

## Bait on the ground (M011): calm boars within attract_radius come to eat it until it is gone.

## item_id -> [pull radius m, seconds it lasts]; ASSUMPTION numbers (D013), better fruit pulls from further.
const KINDS := {
	"item_acorns": [12.0, 20.0],
	"item_red_berries": [14.0, 22.0],
	"item_blueberries": [14.0, 22.0],
	"item_apple": [18.0, 35.0],
	"item_pear": [18.0, 35.0],
	"item_bananas": [20.0, 35.0],
	"item_mandarin": [20.0, 30.0],
	"item_mango": [22.0, 35.0],
	"item_mixed_berries": [24.0, 40.0],
}
const MODELS_DIR := "res://assets/models/fruit/"
const MODELS := {
	"item_acorns": "01_acorns", "item_red_berries": "02_red_berries", "item_blueberries": "03_blueberries",
	"item_apple": "04_apple", "item_pear": "05_pear", "item_bananas": "06_bananas",
	"item_mandarin": "07_mandarin", "item_mango": "08_mango", "item_mixed_berries": "09_mixed_berries",
}

@export var item_id := "item_acorns"

var attract_radius := 12.0


func _ready() -> void:
	var kind: Array = KINDS[item_id]
	attract_radius = kind[0]
	var model: Node3D = load(MODELS_DIR + MODELS[item_id] + ".glb").instantiate()
	model.scale = Vector3.ONE * 1.5
	add_child(model)
	get_tree().create_timer(kind[1]).timeout.connect(queue_free)
