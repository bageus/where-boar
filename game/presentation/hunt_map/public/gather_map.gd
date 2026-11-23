extends Node3D

## Gathering woods (owner, 2026-11-23): the hunt map's size with steeper relief (hills rising into crags),
## denser trees and undergrowth and more forest finds; no boars, birds or terminators. E picks up the find
## in front of the hunter; E at the return point goes back to camp with the pockets.

const BakedShadow = preload("res://game/core/baked_shadow/public/baked_shadow.gd")
const SfxLoop = preload("res://game/core/sfx/public/sfx_loop.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")

## Fact: the hunter went back to camp or was downed; hunt.gathering is set, so it is not counted as a hunt.
signal hunt_ended(hunt: Hunt)

const RETURN_RADIUS := 3.0
## Same reach as on the hunt (hunt_map.gd, issue #26).
const GATHER_REACH := 1.3
const GATHER_AHEAD := 0.9
## The cliff wind is heard from the nearest slope this steep (rise per metre), looked for every CLIFF_GRID metres.
const CLIFF_SLOPE := 0.9
const CLIFF_GRID := 4.0
const HALF := 80.0

var hunt := Hunt.new()
## Camp gear (item_id -> count), injected before the map enters the tree.
var items: Dictionary = {}
var _cliffs: Array[Vector3] = []

@onready var _hunter: CharacterBody3D = $Hunter
@onready var _terrain: StaticBody3D = $Terrain


func _ready() -> void:
	hunt.gathering = true
	add_child(preload("res://game/core/clouds/public/clouds.gd").new())
	BakedShadow.bake(self, $Sun, [$Terrain, $Surroundings], Vector3.ZERO, 240.0)
	for node: Node3D in [_hunter, $ReturnPoint]:
		node.position.y = _terrain.height_at(node.position.x, node.position.z) + 0.1
	_find_cliffs()
	_ambience()
	_hunter.equip(items)
	_hunter.start_hunt()
	_hunter.health.armor = _hunter.loadout.armor
	_hunter.pit_dug.connect(_terrain.dig)
	_hunter.interacted.connect(_on_interacted)
	_hunter.downed.connect(_end)
	$Hud/Minimap.hunter = _hunter
	$Hud/Minimap.return_point = Vector2($ReturnPoint.position.x, $ReturnPoint.position.z)
	_show_goal()


## Jungle birds all around, as on the hunt and in camp; the wind near the crags (owner: sounds from both).
func _ambience() -> void:
	var jungle := SfxLoop.new()
	jungle.group = "jungle_sound"
	jungle.max_distance = 0.0
	jungle.volume_db = -8.0
	jungle.paused_boost_db = 8.0
	add_child(jungle)
	var cliff := SfxLoop.new()
	cliff.name = "CliffSound"
	cliff.group = "cliff_sound"
	cliff.single_take = true
	cliff.max_distance = 20.0
	add_child(cliff)


func _find_cliffs() -> void:
	var x := -HALF
	while x <= HALF:
		var z := -HALF
		while z <= HALF:
			var rise := Vector2(_terrain.height_at(x + 1.0, z) - _terrain.height_at(x - 1.0, z),
					_terrain.height_at(x, z + 1.0) - _terrain.height_at(x, z - 1.0)).length() * 0.5
			if rise > CLIFF_SLOPE:
				_cliffs.append(Vector3(x, _terrain.height_at(x, z) + 2.0, z))
			z += CLIFF_GRID
		x += CLIFF_GRID


func _process(_delta: float) -> void:
	var at := _hunter.global_position
	var best := Vector3(0.0, -1000.0, 0.0)
	for spot in _cliffs:
		if spot.distance_squared_to(at) < best.distance_squared_to(at):
			best = spot
	$CliffSound.position = best


func _on_interacted() -> void:
	if hunt.returned:
		return
	if _hunter.global_position.distance_to($ReturnPoint.global_position) <= RETURN_RADIUS:
		_end()
		return
	var gatherables: Node3D = _terrain.get_node_or_null("Gatherables")
	if gatherables == null:
		return
	var found: Dictionary = gatherables.find(_hunter.global_position - _hunter.global_basis.z * GATHER_AHEAD, GATHER_REACH)
	if found.is_empty():
		return
	var material_id: String = found["material"]
	var name_: String = ShopCatalog.MATERIAL_NAMES[material_id]
	if not hunt.gather(material_id):
		_hunter.show_gain("No room for more %s" % name_.to_lower())
		return
	gatherables.remove(found)
	_hunter.show_gain("+1 %s (%d/%d)" % [name_, hunt.gathered[material_id], Hunt.POCKET[material_id]])
	Sfx.play(_hunter, "rustle", -6.0)
	_show_goal()


func _end() -> void:
	if hunt.returned:
		return
	hunt.returned = true
	hunt.used_items = _hunter.loadout.used.duplicate()
	hunt_ended.emit(hunt)


func _show_goal() -> void:
	var total := 0
	for material_id in hunt.gathered:
		total += hunt.gathered[material_id]
	$Hud/Goal.text = "Gathered: %d" % total


## Pocket contents for the pause menu.
func stats_text() -> String:
	var lines := PackedStringArray()
	for material_id: String in Hunt.POCKET:
		lines.append("%s: %d/%d" % [ShopCatalog.MATERIAL_NAMES[material_id], hunt.gathered.get(material_id, 0), Hunt.POCKET[material_id]])
	return "\n".join(lines)
