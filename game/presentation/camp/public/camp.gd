extends Node3D

## First-person camp hub (section 07, settlement): the hunter walks between stations and uses them with E.

## Fact: the hunter used a station, e.g. "start_hunt".
signal station_used(station_id: String)

const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")

const USE_RADIUS := 2.5

@onready var hunter: CharacterBody3D = $Hunter


func _ready() -> void:
	hunter.interacted.connect(_on_interacted)


## Shows the tribe's tusks and live catches in the camp HUD.
func show_progress(tusks: int, caught: Dictionary) -> void:
	var lines := PackedStringArray(["Tusks: %d" % tusks])
	for type_id in caught:
		var type := BoarTypes.find(type_id)
		lines.append("%s: %d in pens" % [type.display_name if type else type_id, caught[type_id]])
	$Hud/Progress.text = "\n".join(lines)


func _on_interacted() -> void:
	for station: Node3D in $Stations.get_children():
		if hunter.global_position.distance_to(station.global_position) <= USE_RADIUS:
			station_used.emit(station.station_id)
			return
