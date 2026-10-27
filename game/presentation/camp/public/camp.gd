extends Node3D

## First-person camp hub (section 07, settlement): the hunter walks between stations and uses them with E.

## Fact: the hunter used the Start hunt station.
signal hunt_requested
## Fact: something was bought; the game saves (section 18).
signal purchased

const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const Progress = preload("res://game/features/settlement/public/progress.gd")
const PEN_ANIMALS := {
	"rooster": preload("res://game/features/companions/public/wild_rooster.tscn"),
	"turkey": preload("res://game/features/companions/public/wild_turkey.tscn"),
}
## At most this many of each helper animal stand in the pen (owner, 2026-10-27).
const PEN_SHOWN := 4

const USE_RADIUS := 2.5

## Injected before the camp enters the tree.
var progress: Progress

@onready var hunter: CharacterBody3D = $Hunter
@onready var _shop: PanelContainer = $Hud/ShopPanel


func _ready() -> void:
	hunter.interacted.connect(_on_interacted)
	hunter.equip(progress.items)
	_shop.progress = progress
	_shop.purchased.connect(_on_purchased)
	_shop.closed.connect(_on_shop_closed)
	_show_progress()
	_fill_pen()


## Roosters and turkeys caught on hunts stand by the pens.
func _fill_pen() -> void:
	var pen: Vector3 = $Stations/Pens.global_position
	var row := 0
	for animal_id in PEN_ANIMALS:
		for i in mini(progress.helpers.get(animal_id, 0), PEN_SHOWN):
			var animal: CharacterBody3D = PEN_ANIMALS[animal_id].instantiate()
			animal.process_mode = Node.PROCESS_MODE_DISABLED
			add_child(animal)
			animal.global_position = pen + Vector3(2.5 + i * 0.9, 0.0, -1.5 + row * 1.2)
		row += 1


## Shows the tribe's tusks and live catches in the camp HUD.
func _show_progress() -> void:
	var caught := progress.caught
	var lines := PackedStringArray(["Tusks: %d" % progress.tusks])
	for type_id in caught:
		var type := BoarTypes.find(type_id)
		lines.append("%s: %d in pens" % [type.display_name if type else type_id, caught[type_id]])
	for animal_id in progress.helpers:
		lines.append("%s: %d in pens" % [animal_id, progress.helpers[animal_id]])
	if progress.hunts == 0:
		lines.append("First time? Walk to Start hunt (north) and press E.\nShops: Armory (west), Hunting hut (east), Campfire, Tavern (south), Pens (south-east).")
	$Hud/Progress.text = "\n".join(lines)


func _on_interacted() -> void:
	if _shop.visible:
		return
	for station: Node3D in $Stations.get_children():
		if hunter.global_position.distance_to(station.global_position) <= USE_RADIUS:
			_use(station)
			return


func _use(station: Node3D) -> void:
	if station.station_id == "start_hunt":
		hunt_requested.emit()
		return
	# Every other station is a shop: freeze the hunter and free the mouse while it is open.
	hunter.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_shop.open(station.station_id, station.title)


func _on_purchased(_item_id: String) -> void:
	hunter.equip(progress.items)
	_show_progress()
	purchased.emit()


func _on_shop_closed() -> void:
	hunter.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
