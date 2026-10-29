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
## Cage slots on the rack, local to the pens station: roosters on the lower row, turkeys on the upper one.
const CAGE_ROW_Y := {"rooster": 0.25, "turkey": 1.07}
const CAGE_X := [-0.71, 0.01, 0.73]
const CAGE_Z := -4.62
const CAGE_BIRD_SCALE := 0.45
## Standing spots inside the pen fence (x, z, yaw), local to the pens station; clear of shelter, trough and basin.
const PEN_SPOTS: Array[Vector3] = [Vector3(-2.0, 0.6, 0.5), Vector3(1.0, 0.2, 2.2), Vector3(3.2, 1.2, -1.0),
		Vector3(-1.0, 2.2, 3.5), Vector3(2.0, 2.3, -2.4)]
const BoarModelScene = preload("res://game/features/boar/public/boar_model.tscn")

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


## Roosters and turkeys caught on hunts stand in the cages, the newest boars (up to five) in the pen.
func _fill_pen() -> void:
	var pens: Node3D = $Stations/Pens
	for animal_id in PEN_ANIMALS:
		for i in mini(progress.helpers.get(animal_id, 0), CAGE_X.size()):
			var animal: CharacterBody3D = PEN_ANIMALS[animal_id].instantiate()
			animal.process_mode = Node.PROCESS_MODE_DISABLED
			animal.get_node("Label").free()
			pens.add_child(animal)
			animal.scale = Vector3.ONE * CAGE_BIRD_SCALE
			animal.position = Vector3(CAGE_X[i], CAGE_ROW_Y[animal_id], CAGE_Z)
	for i in mini(progress.pen.size(), PEN_SPOTS.size()):
		var boar: Node3D = BoarModelScene.instantiate()
		pens.add_child(boar)
		boar.show_type(BoarTypes.find(progress.pen[i]))
		boar.position = Vector3(PEN_SPOTS[i].x, 0.0, PEN_SPOTS[i].y)
		boar.rotation.y = PEN_SPOTS[i].z


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
