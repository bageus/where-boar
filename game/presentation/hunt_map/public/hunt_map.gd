extends Node3D

## Grey-box hunt map: spawns boars at random markers, counts their outcomes and ends the hunt (M007).

const BoarScene = preload("res://game/features/boar/public/boar_body.tscn")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")

## Fact: the hunter returned to camp, was downed, or no free boars are left.
signal hunt_ended(hunt: Hunt)

## ASSUMPTION (D013, section 11 scaled to the grey map): one herd, three groups, two loners.
const GROUP_SIZES := [10, 3, 3, 3, 1, 1]
const RETURN_RADIUS := 3.0
## ASSUMPTION (D013): how far a shout carries, metres.
const SHOUT_RADIUS := 15.0

var hunt: Hunt
## Camp gear (item_id -> count), injected before the map enters the tree.
var items: Dictionary = {}
## Bait on the ground; the same array is shared with every boar.
var _baits: Array[Node3D] = []

@onready var _hunter: CharacterBody3D = $Hunter
@onready var _goal: Label = $Hud/Goal


func _ready() -> void:
	var zones: Array[Vector2] = []
	for zone: Node3D in $EscapeZones.get_children():
		zones.append(Vector2(zone.position.x, zone.position.z))
	var spawns := $BoarSpawns.get_children()
	spawns.shuffle()
	var groups := mini(GROUP_SIZES.size(), spawns.size())
	var total := 0
	for g in groups:
		total += GROUP_SIZES[g]
	hunt = Hunt.new(total)
	for g in groups:
		_spawn_group(GROUP_SIZES[g], spawns[g].position, zones)
	_hunter.equip(items)
	_hunter.start_hunt()
	_hunter.interacted.connect(_on_interacted)
	_hunter.downed.connect(_on_downed)
	_hunter.shouted.connect(_on_shouted)
	_hunter.bait_placed.connect(_on_bait_placed)
	var minimap := $Hud/Minimap
	minimap.hunter = _hunter
	minimap.escape_zones = zones
	minimap.return_point = Vector2($ReturnPoint.position.x, $ReturnPoint.position.z)
	_show_goal()


## Spawns size boars in a ring around centre; a group of two or more shares one herd array.
func _spawn_group(size: int, centre: Vector3, zones: Array[Vector2]) -> void:
	var herd: Array[Node3D] = []
	for i in size:
		var boar := BoarScene.instantiate()
		boar.boar_type = BoarTypes.pick(randf())
		boar.hunter = _hunter
		boar.escape_zones = zones
		boar.baits = _baits
		if size > 1:
			boar.herd = herd
			herd.append(boar)
		var ring := 1.2 * sqrt(size)
		boar.position = centre + Vector3(cos(TAU * i / size) * ring, 0.0, sin(TAU * i / size) * ring)
		boar.outcome_reached.connect(_on_outcome)
		boar.held_changed.connect(_on_held_changed)
		$Boars.add_child(boar)


func _on_outcome(type_id: String, kind: int) -> void:
	if hunt.is_over():
		return
	hunt.record(type_id, kind)
	_show_goal()
	if hunt.is_over():
		_end()


func _on_held_changed(held: bool) -> void:
	if hunt.is_over():
		return
	hunt.held += 1 if held else -1
	_show_goal()
	if hunt.is_over():
		_end()


func _on_interacted() -> void:
	if hunt.is_over() or _hunter.global_position.distance_to($ReturnPoint.global_position) > RETURN_RADIUS:
		return
	hunt.returned = true
	_end()


## Zero health: back to camp with what was caught, no defeat screen (section 10).
func _on_downed() -> void:
	if hunt.is_over():
		return
	hunt.returned = true
	_end()


func _end() -> void:
	hunt.used_items = _hunter.loadout.used.duplicate()
	var held_types := []
	for boar in $Boars.get_children():
		if boar.state_name() == "TRAPPED":
			held_types.append(boar.boar_type.id)
	hunt.close_traps(held_types)
	hunt_ended.emit(hunt)


func _on_shouted(at: Vector3) -> void:
	for boar in $Boars.get_children():
		if boar.global_position.distance_to(at) <= SHOUT_RADIUS:
			boar.hear_shout(at)


func _on_bait_placed(bait: Node3D) -> void:
	# Drop eaten bait; boars skip freed entries in between.
	_baits.assign(_baits.filter(is_instance_valid))
	_baits.append(bait)


func _show_goal() -> void:
	_goal.text = "Boars left: %d   In traps: %d   Killed: %d   Caught: %d   Escaped: %d" % [
		hunt.remaining(),
		hunt.held,
		hunt.count_all(BoarOutcome.Kind.DEAD),
		hunt.count_all(BoarOutcome.Kind.CAPTURED),
		hunt.count_all(BoarOutcome.Kind.ESCAPED),
	]
