extends Node3D

## Grey-box hunt map: spawns boars at random markers and gives them the hunter and escape zones.

const BoarScene = preload("res://game/features/boar/public/boar_body.tscn")

## ASSUMPTION: boars per prototype hunt.
const BOAR_COUNT := 4


func _ready() -> void:
	var zones: Array[Vector2] = []
	for zone: Node3D in $EscapeZones.get_children():
		zones.append(Vector2(zone.position.x, zone.position.z))
	var spawns := $BoarSpawns.get_children()
	spawns.shuffle()
	for i in mini(BOAR_COUNT, spawns.size()):
		var boar := BoarScene.instantiate()
		boar.hunter = $Hunter
		boar.escape_zones = zones
		boar.position = spawns[i].position
		$Boars.add_child(boar)
