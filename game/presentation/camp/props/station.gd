extends Node3D

## A place in camp the hunter uses with E: start the hunt or open a shop.

@export var station_id := ""
@export var title := ""


func _ready() -> void:
	$Label.text = "%s [E]" % title
