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
## Cage slots, local to the cage rack (its cages open towards +x): roosters on the lower row, turkeys on the upper one.
const CAGE_ROW_Y := {"rooster": 0.25, "turkey": 1.07}
const CAGE_Z := [-1.4, -2.12, -2.84]
const CAGE_X := 5.15
const CAGE_BIRD_SCALE := 0.45
## Standing spots inside the pen fence (x, z, yaw), local to the pens station; clear of shelter, trough and basin.
const PEN_SPOTS: Array[Vector3] = [Vector3(-2.0, 0.6, 0.5), Vector3(1.0, 0.2, 2.2), Vector3(3.2, 1.2, -1.0),
		Vector3(-1.0, 2.2, 3.5), Vector3(2.0, 2.3, -2.4)]
## Saddles hung over the front fence rail (x, yaw), local to the pens station.
const RAIL_SADDLES := [Vector2(-3.2, 0.0), Vector2(2.2, 0.1), Vector2(3.6, -0.1)]
const RAIL_Z := 3.38
const RAIL_TOP := 1.0
const Saddle = preload("res://assets/models/saddle.glb")
const BoarModelScene = preload("res://game/features/boar/public/boar_model.tscn")
const Helper = preload("res://assets/models/caveman_helper.glb")
## The helper's seat on the tavern's inner bench, local to the tavern model, facing the feast table;
## lowered by his knee height (0.25 m) so he sits on the bench top (0.52).
const HELPER_SEAT := Vector3(-0.2, 0.52 - 0.25, 0.37)

const USE_RADIUS := 2.5  # from a point station
const USE_RADIUS_SOLID := 1.5  # from the edge of a solid one
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const SfxLoop = preload("res://game/core/sfx/public/sfx_loop.gd")
## The tavern hearth's flames, local to the tavern model.
const TAVERN_HEARTH := Vector3(-1.63, 0.3, -0.75)
## Wind over the drop-off (east side and south-east corner), heard near the rim; follows the hunter along it.
const DROP_EAST := 17.0  # Dressing.HALF
const DROP_SOUTH_FROM := 2.0  # Dressing.SOUTH_SPLIT
## Penned boars grunt now and then, less than wild ones (owner, 2026-10-29).
const PEN_VOICE_SECONDS := Vector2(6.0, 16.0)

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
	_seat_helper()
	_ambience()
	var buildings: Array[Node3D] = [$LargeTent, $AFrameTent, $RoundTent, $RoundTent2, $Stations/WeaponShop,
			$Stations/HuntingHut, $Stations/Tavern, $Stations/Well]
	$Dressing.dress($Stations/Campfire.global_position, $Stations/StartHunt.global_position, buildings)


## Roosters and turkeys caught on hunts stand in the cages, the newest boars (up to five) in the pen.
func _fill_pen() -> void:
	var pens: Node3D = $Stations/Pens
	for animal_id in PEN_ANIMALS:
		for i in mini(progress.helpers.get(animal_id, 0), CAGE_Z.size()):
			var animal: CharacterBody3D = PEN_ANIMALS[animal_id].instantiate()
			animal.process_mode = Node.PROCESS_MODE_DISABLED
			$Stations/Cages.add_child(animal)
			animal.scale = Vector3.ONE * CAGE_BIRD_SCALE
			animal.position = Vector3(CAGE_X, CAGE_ROW_Y[animal_id], CAGE_Z[i])
			animal.rotation.y = -PI / 2  # faces out of the cage
			animal.get_node("Model").process_mode = Node.PROCESS_MODE_ALWAYS  # idles in the cage
	var penned: Array[Node3D] = []
	for i in mini(progress.pen.size(), PEN_SPOTS.size()):
		var boar: Node3D = BoarModelScene.instantiate()
		pens.add_child(boar)
		penned.append(boar)
		boar.show_type(BoarTypes.find(progress.pen[i]))
		boar.position = Vector3(PEN_SPOTS[i].x, 0.0, PEN_SPOTS[i].y)
		boar.rotation.y = PEN_SPOTS[i].z
	if not penned.is_empty():
		get_tree().create_timer(randf_range(0.0, PEN_VOICE_SECONDS.y)).timeout.connect(_pen_voice.bind(penned))
	for spot: Vector2 in RAIL_SADDLES:
		var saddle: Node3D = Saddle.instantiate()
		pens.add_child(saddle)
		saddle.position = Vector3(spot.x, RAIL_TOP - 0.3, RAIL_Z)
		saddle.rotation.y = PI / 2 + spot.y  # spine along the rail, stirrups hang on both sides


## The crackle of the campfire with its brazier and of the tavern hearth, heard only close by; the jungle
## all around; the wind at the drop-off (owner, 2026-10-29).
func _ambience() -> void:
	$Stations/Campfire.add_child(SfxLoop.new())
	var hearth := SfxLoop.new()
	hearth.position = TAVERN_HEARTH
	hearth.volume_db = -4.0
	$Stations/Tavern.add_child(hearth)
	var jungle := SfxLoop.new()
	jungle.group = "jungle_sound"
	jungle.max_distance = 0.0
	jungle.volume_db = -10.0
	add_child(jungle)
	var cliff := SfxLoop.new()
	cliff.name = "CliffSound"
	cliff.group = "cliff_sound"
	cliff.single_take = true
	cliff.max_distance = 20.0
	add_child(cliff)


func _process(_delta: float) -> void:
	var at := hunter.global_position
	var east := Vector3(DROP_EAST, 0.0, clampf(at.z, -DROP_EAST, DROP_EAST))
	var south := Vector3(clampf(at.x, DROP_SOUTH_FROM, DROP_EAST), 0.0, DROP_EAST)
	$CliffSound.position = east if at.distance_to(east) < at.distance_to(south) else south


func _pen_voice(boars: Array[Node3D]) -> void:
	Sfx.play(boars.pick_random(), "boar_voice", -6.0, 30.0)
	get_tree().create_timer(randf_range(PEN_VOICE_SECONDS.x, PEN_VOICE_SECONDS.y)).timeout.connect(_pen_voice.bind(boars))


## The helper for hire sits at the tavern's feast table (owner, 2026-10-29), his hammer put away.
func _seat_helper() -> void:
	var tavern: Node3D = $Stations/Tavern
	var helper: Node3D = Helper.instantiate()
	tavern.add_child(helper)
	helper.position = HELPER_SEAT
	helper.scale = Vector3.ONE / tavern.scale.x  # the tavern model is scaled up, the helper is not
	helper.find_child("hammer").hide()
	var player: AnimationPlayer = helper.find_child("AnimationPlayer")
	player.get_animation("sit").loop_mode = Animation.LOOP_LINEAR
	player.play("sit")


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
		lines.append("First time? Walk to Start hunt (north) and press E.\nShops: Armory (west), Hunting hut (east), Campfire, Tavern (south-east), Pens and Cages (south-west), Well (water).")
	$Hud/Progress.text = "\n".join(lines)


func _on_interacted() -> void:
	if _shop.visible:
		return
	for station: Node3D in $Stations.get_children():
		if station.distance_to(hunter.global_position) <= (USE_RADIUS_SOLID if station.solid else USE_RADIUS):
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
