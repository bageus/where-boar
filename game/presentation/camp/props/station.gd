extends Node3D

## A place in camp the hunter uses with E: start the hunt or open a shop.

@export var station_id := ""
@export var title := ""
@export var model: PackedScene = preload("res://assets/models/stall.glb")


func _ready() -> void:
	add_child(model.instantiate())
	$Label.text = "%s [E]" % title
