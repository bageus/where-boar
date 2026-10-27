extends Node3D

## Grey-box hunt map: spawns boars at random markers, counts their outcomes and ends the hunt (M007).

const BoarScene = preload("res://game/features/boar/public/boar_body.tscn")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")

## Fact: the hunter returned to camp, was downed, or no free boars are left.
signal hunt_ended(hunt: Hunt)

## ASSUMPTION: boars per prototype hunt.
const BOAR_COUNT := 6
const RETURN_RADIUS := 3.0

var hunt: Hunt

@onready var _hunter: CharacterBody3D = $Hunter
@onready var _goal: Label = $Hud/Goal


func _ready() -> void:
	var zones: Array[Vector2] = []
	for zone: Node3D in $EscapeZones.get_children():
		zones.append(Vector2(zone.position.x, zone.position.z))
	var spawns := $BoarSpawns.get_children()
	spawns.shuffle()
	hunt = Hunt.new(mini(BOAR_COUNT, spawns.size()))
	for i in hunt.total:
		var boar := BoarScene.instantiate()
		boar.boar_type = BoarTypes.pick(randf())
		boar.hunter = _hunter
		boar.escape_zones = zones
		boar.position = spawns[i].position
		boar.outcome_reached.connect(_on_outcome)
		$Boars.add_child(boar)
	_hunter.interacted.connect(_on_interacted)
	_hunter.downed.connect(_on_downed)
	var minimap := $Hud/Minimap
	minimap.hunter = _hunter
	minimap.escape_zones = zones
	minimap.return_point = Vector2($ReturnPoint.position.x, $ReturnPoint.position.z)
	_show_goal()


func _on_outcome(type_id: String, kind: int) -> void:
	if hunt.is_over():
		return
	hunt.record(type_id, kind)
	_show_goal()
	if hunt.is_over():
		hunt_ended.emit(hunt)


func _on_interacted() -> void:
	if hunt.is_over() or _hunter.global_position.distance_to($ReturnPoint.global_position) > RETURN_RADIUS:
		return
	hunt.returned = true
	hunt_ended.emit(hunt)


## Zero health: back to camp with what was caught, no defeat screen (section 10).
func _on_downed() -> void:
	if hunt.is_over():
		return
	hunt.returned = true
	hunt_ended.emit(hunt)


func _show_goal() -> void:
	_goal.text = "Boars left: %d   Killed: %d   Caught: %d   Escaped: %d" % [
		hunt.remaining(),
		hunt.count_all(BoarOutcome.Kind.DEAD),
		hunt.count_all(BoarOutcome.Kind.CAPTURED),
		hunt.count_all(BoarOutcome.Kind.ESCAPED),
	]
