extends Node3D

## First-person camp hub (section 07, settlement): the hunter walks between stations and uses them with E.

## Fact: the signpost's countdown ran out with the hunter in its circle (issue #24).
signal hunt_requested
## Fact: something was bought; the game saves (section 18).
signal purchased

const BakedShadow = preload("res://game/core/baked_shadow/public/baked_shadow.gd")
const LevelLayout = preload("res://game/core/level_layout/public/level_layout.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const ItemIcons = preload("res://game/features/settlement/public/item_icons.gd")
const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const ClanPanel = preload("res://game/presentation/camp/hud/clan_panel.gd")
const ClanTent = preload("res://game/presentation/camp/props/clan_tent.gd")
const BoxPanel = preload("res://game/presentation/camp/hud/box_panel.gd")
const SignpostPanel = preload("res://game/presentation/camp/hud/signpost_panel.gd")
const HuntLobby = preload("res://game/features/settlement/public/hunt_lobby.gd")
## The circle around the signpost: who stands in it when the countdown ends goes on the hunt (issue #24).
const HUNT_CIRCLE := 4.0
const BUILDINGS := "res://assets/models/buildings/"
## A free hut shows any of the five looks; a bought one keeps its own (issue #22).
const HUT_VARIANTS: Array[PackedScene] = [
	preload(BUILDINGS + "Burdock_Hut_Variants/01_Coral_High_Peak.glb"),
	preload(BUILDINGS + "Burdock_Hut_Variants/02_Ochre_Wide_Entrance.glb"),
	preload(BUILDINGS + "Burdock_Hut_Variants/03_Russet_Long_Skirt.glb"),
	preload(BUILDINGS + "Burdock_Hut_Variants/04_Sand_Swept_Cap.glb"),
	preload(BUILDINGS + "Burdock_Hut_Variants/05_Prehistoric_Burdock_Tent.glb"),
]
const FORGE_BUILT = preload(BUILDINGS + "Primitive_Blacksmith_Shelter.glb")
## Clan building models for the planning palette (the real clan tent rises with a clan, issue #23).
const CLAN_MODELS := ["Prehistoric_Ochre_Clan_Tent", "Chunky_Boar_Log_Totem", "Tripod_Cauldron_and_Hearth"]
const PALETTE := ["Prehistoric_Communal_Longhouse", "Burdock_Hut_Variants/01_Coral_High_Peak",
	"Burdock_Hut_Variants/02_Ochre_Wide_Entrance", "Burdock_Hut_Variants/03_Russet_Long_Skirt",
	"Burdock_Hut_Variants/04_Sand_Swept_Cap", "Burdock_Hut_Variants/05_Prehistoric_Burdock_Tent", "Prehistoric_Stone_Well",
	"Prehistoric_Cauldron_and_Brazier_Set", "Prehistoric_Trail_Signpost", "Prehistoric_Bow_and_Spear_Stall",
	"Prehistoric_Hunting_Stall", "boar_pen", "Prehistoric_Six_Cage_Rack", "Prehistoric_Hide_Canopy_Tavern",
	"Bird_Bear_Boar_Totem", "Primitive_Stick_Chest", "Prehistoric_Quest_Board", "Prehistoric_Beauty_Hut", "Shaman_Hide_Hut",
	"Primitive_Workshop_Construction_Site", "Primitive_Blacksmith_Shelter"]
const PEN_ANIMALS := {
	"rooster": preload("res://game/features/companions/public/wild_rooster.tscn"),
	"turkey": preload("res://game/features/companions/public/wild_turkey.tscn"),
}
## Cage floors, local to the six-cage rack (cages open towards +z): roosters on the lower shelf, turkeys on
## the upper one. Birds keep their hunt size there (owner, 2026-11-07: a tight fit is fine).
const CAGE_ROW_Y := {"rooster": 0.6, "turkey": 2.07}
const CAGE_X := [-1.08, 0.0, 1.08]
const CAGE_Z := 0.05
## Standing spots inside the pen fence (x, z, yaw), in the pen model's units; clear of shelter, trough and basin.
const PEN_SPOTS: Array[Vector3] = [Vector3(-4.5, 3.0, 0.5), Vector3(1.0, 4.5, 2.2), Vector3(5.0, 0.5, -1.0),
		Vector3(-1.0, -1.0, 2.3), Vector3(2.5, -5.0, -2.4)]
## Saddles hung over the front fence rail (x, yaw), in the pen model's units; the gate is at x -1.2..3.4.
const RAIL_SADDLES := [Vector2(-7.0, 0.0), Vector2(-4.5, 0.1), Vector2(7.0, -0.1)]
const RAIL_Z := 8.07
const RAIL_TOP := 1.56
const Saddle = preload("res://assets/models/peak_gear/saddle.tscn")
const BoarModelScene = preload("res://game/features/boar/public/boar_model.tscn")
const Helper = preload("res://assets/models/peak_cavemen/helper.glb")
## The helper's seat on the tavern's front bench, local to the tavern model, facing the table;
## lowered by his knee height (0.25 m) so he sits on the bench top (0.43).
const HELPER_SEAT := Vector3(-0.1, 0.43 - 0.25, 2.25)
const HunterRig = preload("res://game/features/hunter/public/hunter_rig.gd")
## One of the owner's rigged hunters, picked at random each visit, on the back bench facing the helper
## (owner, 2026-11-23); knees 0.3 m high.
const TAVERN_GUESTS: Array[String] = ["res://assets/models/hunter/prehistoric_hunter.glb", "res://assets/models/hunter/plump_hunter.glb"]
const GUEST_SEAT := Vector3(-0.1, 0.43 - 0.3, 1.55)

const USE_RADIUS := 2.5  # from a point station
const USE_RADIUS_SOLID := 1.5  # from the edge of a solid one
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const SfxLoop = preload("res://game/core/sfx/public/sfx_loop.gd")
## The tavern hearth's flames, local to the tavern model.
const TAVERN_HEARTH := Vector3(1.4, 0.8, -0.9)
## Wind over the drop-off (east side and south-east corner), heard near the rim; follows the hunter along it.
const DROP_EAST := 25.0  # Dressing.HALF
const DROP_SOUTH_FROM := 2.0  # Dressing.SOUTH_SPLIT
## Penned boars grunt now and then, less than wild ones (owner, 2026-10-29).
const PEN_VOICE_SECONDS := Vector2(6.0, 16.0)

## Injected before the camp enters the tree.
var progress: Progress
## Injected: the planned layout (planning mode, issue #29) applied before the camp is dressed.
var layout: Dictionary = {}
## Injected: planning mode shows the camp with no hunter, shops or HUD.
var planning := false

## Shop windows' extra line for stations whose own features come later.
const INFO := {
	"beauty_hut": "Paint and decorations come later; they change only the look.",
	"shaman_hut": "Rituals come later.",
}

var _open_station: Node3D
var _clan_panel := ClanPanel.new()

@onready var hunter: CharacterBody3D = $Hunter
@onready var _shop: PanelContainer = $Hud/ShopPanel
var _box := BoxPanel.new()
var _signpost := SignpostPanel.new()
var _countdown := Label.new()
## Seconds until the hunt starts, < 0 when no countdown runs; the chosen mode and invited names.
var _hunt_left := -1.0
var _hunt_mode := ""
var _hunt_invited := PackedStringArray()


func _ready() -> void:
	LevelLayout.apply(self, layout)
	if planning:
		hunter.free()
		$Hud.hide()
		set_process(false)
		_dress()
		return
	hunter.interacted.connect(_on_interacted)
	hunter.equip(progress.hunt_items())
	_shop.progress = progress
	_shop.purchased.connect(_on_purchased)
	_shop.closed.connect(_on_shop_closed)
	_clan_panel.progress = progress
	$Hud.add_child(_clan_panel)
	_clan_panel.purchased.connect(_on_purchased)
	_clan_panel.closed.connect(_on_shop_closed)
	_box.progress = progress
	$Hud.add_child(_box)
	_box.changed.connect(_on_purchased.bind("box"))
	_box.closed.connect(_on_shop_closed)
	_signpost.progress = progress
	$Hud.add_child(_signpost)
	_signpost.purchased.connect(_on_purchased)
	_signpost.closed.connect(_on_shop_closed)
	_signpost.launched.connect(_launch)
	_hunt_circle()
	_dress_huts()
	_dress_forge()
	if progress.clan:
		ClanTent.raise($Stations, progress.clan)
	_show_progress()
	_fill_pen()
	_seat_helper()
	_ambience()
	_dress()
	# The camp ground and the forest floor behind the palisade.
	BakedShadow.bake(self, $Sun, [$Scenery, $Dressing, $Stations, $Longhouse] as Array[Node],
			Vector3(-10.0, 0.0, -20.0), 120.0, -0.3)  # the wall and drop-off rocks reach far below the camp


func _dress() -> void:
	var buildings: Array[Node3D] = [$Longhouse]
	for station: Node3D in $Stations.get_children():
		if station.name not in ["StartHunt", "Campfire"]:
			buildings.append(station)
	$Dressing.dress($Stations/Campfire.global_position, $Stations/StartHunt.global_position, buildings, $Scenery.rim_rocks)


## Objects planning mode may move, turn, scale, copy and delete: the longhouse and stations.
func planning_targets() -> Array[Node]:
	var nodes: Array[Node] = [$Longhouse]
	nodes.append_array($Stations.get_children())
	nodes.append_array(get_children().filter(func(n: Node) -> bool: return n.has_meta(LevelLayout.ADDED_META)))
	return nodes


func planning_parent() -> Node3D:
	return self


func planning_centre() -> Vector3:
	return $Stations/Campfire.global_position


## Building models (decoration only: a copied stall sells nothing), then the shared nature models.
func planning_palette() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for model: String in PALETTE + CLAN_MODELS:
		entries.append({"name": model.get_file().capitalize(), "res": BUILDINGS + model + ".glb", "solid": ""})
	entries.append_array(LevelLayout.nature_palette())
	return entries


## Tents and stations are used by the camp itself, so only added objects may go.
func planning_removable(node: Node) -> bool:
	return node.has_meta(LevelLayout.ADDED_META)


## Roosters and turkeys caught on hunts stand in the cages, the newest boars (up to five) in the pen.
func _fill_pen() -> void:
	var pens: Node3D = $Stations/Pens
	for animal_id in PEN_ANIMALS:
		for i in mini(progress.helpers.get(animal_id, 0), CAGE_X.size()):
			var animal: CharacterBody3D = PEN_ANIMALS[animal_id].instantiate()
			animal.process_mode = Node.PROCESS_MODE_DISABLED
			$Stations/Cages.add_child(animal)
			animal.position = Vector3(CAGE_X[i], CAGE_ROW_Y[animal_id], CAGE_Z)
			animal.scale = Vector3.ONE / $Stations/Cages.scale.x  # the rack is scaled, the birds keep their size
			animal.rotation.y = PI  # faces out of the cage
			animal.get_node("Model").process_mode = Node.PROCESS_MODE_ALWAYS  # idles in the cage
	var penned: Array[Node3D] = []
	for i in mini(progress.pen.size(), PEN_SPOTS.size()):
		var boar: Node3D = BoarModelScene.instantiate()
		pens.add_child(boar)
		penned.append(boar)
		boar.show_type(BoarTypes.find(progress.pen[i]))
		boar.position = Vector3(PEN_SPOTS[i].x, 0.0, PEN_SPOTS[i].y)
		boar.rotation.y = PEN_SPOTS[i].z
		boar.scale = Vector3.ONE / pens.scale.x  # the pen model is scaled down, the boars are not
	if not penned.is_empty():
		get_tree().create_timer(randf_range(0.0, PEN_VOICE_SECONDS.y)).timeout.connect(_pen_voice.bind(penned))
	for spot: Vector2 in RAIL_SADDLES:
		var saddle: Node3D = Saddle.instantiate()
		pens.add_child(saddle)
		saddle.position = Vector3(spot.x, RAIL_TOP - 0.3 / pens.scale.x, RAIL_Z)
		saddle.rotation.y = PI / 2 + spot.y  # spine along the rail, stirrups hang on both sides
		saddle.scale = Vector3.ONE / pens.scale.x


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
	jungle.paused_boost_db = 8.0
	add_child(jungle)
	var cliff := SfxLoop.new()
	cliff.name = "CliffSound"
	cliff.group = "cliff_sound"
	cliff.single_take = true
	cliff.max_distance = 20.0
	add_child(cliff)


func _process(delta: float) -> void:
	hunter.point_at(null if _window_open() else _station_in_reach())
	if _hunt_left >= 0.0:
		_hunt_left -= delta
		_countdown.text = "The hunt starts in %d s: stay in the circle" % ceili(_hunt_left)
		if _hunt_left <= 0.0:
			_start_hunt()
	var at := hunter.global_position
	var east := Vector3(DROP_EAST, 0.0, clampf(at.z, -DROP_EAST, DROP_EAST))
	var south := Vector3(clampf(at.x, DROP_SOUTH_FROM, DROP_EAST), 0.0, DROP_EAST)
	$CliffSound.position = east if at.distance_to(east) < at.distance_to(south) else south


func _pen_voice(boars: Array[Node3D]) -> void:
	Sfx.play(boars.pick_random(), "boar_voice", -6.0, 30.0)
	get_tree().create_timer(randf_range(PEN_VOICE_SECONDS.x, PEN_VOICE_SECONDS.y)).timeout.connect(_pen_voice.bind(boars))


## The helper for hire sits at the tavern's feast table (owner, 2026-10-29), his hammer put away, a
## hunter across the table.
func _seat_helper() -> void:
	var tavern: Node3D = $Stations/Tavern
	var helper: Node3D = Helper.instantiate()
	tavern.add_child(helper)
	helper.position = HELPER_SEAT
	helper.scale = Vector3.ONE / tavern.scale.x  # the tavern model is scaled, the helper is not
	helper.rotation.y = PI  # faces the table
	helper.find_child("hammer").hide()
	var player: AnimationPlayer = helper.find_child("AnimationPlayer")
	player.get_animation("sit").loop_mode = Animation.LOOP_LINEAR
	player.play("sit")
	var guest := HunterRig.instance(load(TAVERN_GUESTS.pick_random()))
	tavern.add_child(guest)
	guest.position = GUEST_SEAT
	guest.scale = Vector3.ONE / tavern.scale.x
	guest.find_child("AnimationPlayer").play("sit")


## Shows the tribe's tusks and live catches in the camp HUD.
func _show_progress() -> void:
	var caught := progress.caught
	var lines := PackedStringArray([ItemIcons.bbcode("tusk") + "Tusks: %d" % progress.tusks])
	for type_id in caught:
		var type := BoarTypes.find(type_id)
		lines.append("%s: %d in pens" % [type.display_name if type else type_id, caught[type_id]])
	for animal_id in progress.helpers:
		lines.append("%s%s: %d in pens" % [ItemIcons.bbcode(animal_id), animal_id, progress.helpers[animal_id]])
	var finds := PackedStringArray()
	for material_id: String in progress.materials:
		if progress.materials[material_id] > 0:
			finds.append("%s%d" % [ItemIcons.bbcode(material_id, 22), progress.materials[material_id]])
	if not finds.is_empty():
		lines.append(" ".join(finds))
	if progress.hunts == 0:
		lines.append("First time? Walk to Start hunt (north) and press E.\nShops: Armory (west), Hunting hut (east), Campfire, Tavern (south-east), Pens and Cages (south-west), Well (water), Quests (by the gate).")
	$Hud/Progress.text = "[right]%s[/right]" % "\n".join(lines)
	# Quests done of all on the board, green once all are done (issue #25).
	progress.quests.renew_if_due(int(Time.get_unix_time_from_system()))
	var board: Label3D = $Stations/QuestBoard/Label
	var done := progress.quests.claimed_count()
	board.text = "Quests %d / %d" % [done, progress.quests.quests.size()]
	board.modulate = Color(0.45, 1.0, 0.4) if done == progress.quests.quests.size() else Color.WHITE


func _on_interacted() -> void:
	var station := _station_in_reach()
	if station and not _window_open():
		_use(station)


func _window_open() -> bool:
	return _shop.visible or _clan_panel.visible or _box.visible or _signpost.visible


func _station_in_reach() -> Node3D:
	for station: Node3D in $Stations.get_children():
		if station.distance_to(hunter.global_position) <= (USE_RADIUS_SOLID if station.solid else USE_RADIUS):
			return station
	return null


func _use(station: Node3D) -> void:
	# Every station opens a window: freeze the hunter and free the mouse while it is open.
	hunter.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.ui(self, "shop")
	_open_station = station
	if station.station_id == "start_hunt":
		_signpost.open()
		return
	if station.station_id in ["totem", "clan_tent"]:
		_clan_panel.open(false, station.station_id == "clan_tent")
		return
	if station.station_id == "chest":
		_box.open()
		return
	_shop.info = INFO.get(station.station_id, "")
	if station.station_id == "hut" and _is_my_hut(station):
		_shop.info = "Your hut. Its clan tent upgrade lets you found a clan at the totem."
	_shop.open(station.station_id, "Hut" if station.station_id == "hut" else station.title)


func _on_purchased(item_id: String) -> void:
	if item_id == "item_hut":  # bought at a hut, or at the totem (the first hut then)
		var hut: Node3D = _open_station if _open_station.station_id == "hut" else $Stations/Hut1
		progress.hut_slot = hut.get_index() - $Stations/Hut1.get_index()
		progress.hut_variant = hut.get_meta("variant")
		_dress_huts()
	elif item_id == "item_clan_tent" and _shop.visible:  # upgraded in the hut: go on to founding (issue #27)
		_shop.hide()
		_clan_panel.open(true)
	elif item_id == "clan":
		ClanTent.raise($Stations, progress.clan)
	elif item_id.begins_with("item_forge") and progress.forge_built():
		_dress_forge()
	hunter.equip(progress.hunt_items())
	_show_progress()
	purchased.emit()


## Six huts (issue #22): free ones show any look and their price, a bought one keeps its own look.
func _dress_huts() -> void:
	for i in 6:
		var hut: Node3D = get_node("Stations/Hut%d" % (i + 1))
		var mine := progress.hut_slot == i and progress.owns("item_hut")
		if not hut.has_meta("variant") or mine:
			hut.set_meta("variant", progress.hut_variant if mine else randi() % HUT_VARIANTS.size())
			hut.set_model(HUT_VARIANTS[hut.get_meta("variant")])
		hut.title = "Your hut" if mine else "For sale\n%d tusks" % ShopCatalog.ITEMS["item_hut"]["price"]
		hut.get_node("Label").text = hut.title


func _is_my_hut(station: Node3D) -> bool:
	return progress.owns("item_hut") and station == get_node_or_null("Stations/Hut%d" % (progress.hut_slot + 1))


## A building site until the camp has given the forge's cost, then the forge (issue #11).
func _dress_forge() -> void:
	if progress.forge_built():
		$Stations/Forge.set_model(FORGE_BUILT)
		$Stations/Forge.title = "Forge (recipes coming later)"
		$Stations/Forge.get_node("Label").text = $Stations/Forge.title


func _on_shop_closed() -> void:
	hunter.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A ring on the ground around the signpost and the countdown line at the top of the screen (issue #24).
func _hunt_circle() -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = HUNT_CIRCLE - 0.12
	torus.outer_radius = HUNT_CIRCLE
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.3)
	torus.material = glow
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale.y = 0.2  # flat on the ground
	add_child(ring)
	ring.global_position = $Stations/StartHunt.global_position + Vector3(0.0, 0.03, 0.0)
	_countdown.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_countdown.offset_top = 20.0
	_countdown.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_countdown.add_theme_font_size_override("font_size", 26)
	$Hud.add_child(_countdown)


func _launch(mode: String, seconds: int, invited: PackedStringArray) -> void:
	_on_shop_closed()
	_hunt_mode = mode
	_hunt_invited = invited
	_hunt_left = seconds
	if seconds <= 0:  # tests start at once
		_start_hunt()


## Who stands in the circle goes; a crowd would split into several hunts, one player is one hunt for now.
func _start_hunt() -> void:
	_hunt_left = -1.0
	_countdown.text = ""
	# shortcut: one player, so the circle holds only you; co-op fills it from the network (GAME_SPEC 19).
	var me := {"name": "you", "clan": progress.clan.name if progress.clan else "", "pass": progress.owns(HuntLobby.PASS_ID)}
	var in_circle := [me] if hunter.global_position.distance_to($Stations/StartHunt.global_position) <= HUNT_CIRCLE else []
	var groups := HuntLobby.split(HuntLobby.entrants(_hunt_mode, me, in_circle, _hunt_invited))
	if groups.any(func(group: Array) -> bool: return me in group):
		hunt_requested.emit()
	else:
		hunter.show_gain("You left the circle: no hunt")
