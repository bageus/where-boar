extends Node

## Composition root: start screen -> camp -> hunt map -> results -> camp (section 07).

const StartScene = preload("res://game/presentation/menus/public/start_screen.tscn")
const ResultsScene = preload("res://game/presentation/menus/public/results_screen.tscn")
const PauseScene = preload("res://game/presentation/menus/public/pause_menu.tscn")
const ViewerScene = preload("res://game/presentation/menus/public/animation_viewer.tscn")
const MapScene = preload("res://game/presentation/hunt_map/public/hunt_map.tscn")
const GatherScene = preload("res://game/presentation/hunt_map/public/gather_map.tscn")
const CampScene = preload("res://game/presentation/camp/public/camp.tscn")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const Progress = preload("res://game/features/settlement/public/progress.gd")
const Shaman = preload("res://game/features/settlement/public/shaman.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const SaveStore = preload("res://game/infrastructure/save/public/save_store.gd")
const Planner = preload("res://game/presentation/planning/public/planner.gd")
## A layout committed with the game (Export in planning mode), used when this machine has none saved.
const SHIPPED_LAYOUT := "res://content/layouts/%s.json"

## The one screen or map shown now.
var current: Node
var save_store := SaveStore.new()
var progress: Progress
## Settings live in their own file, apart from progress (section 18).
var settings_store := _settings_store()
var settings := {"quality": "high", "fov": 80.0, "mouse_sensitivity": 0.002, "camera_motion": true, "sfx_volume": 1.0, "character": "bearded"}
var _pause: CanvasLayer


static func _settings_store() -> SaveStore:
	var store := SaveStore.new()
	store.path = "user://settings.json"
	return store


func _ready() -> void:
	# Main keeps running while paused so it can unpause; screens it shows are pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	progress = Progress.from_dict(save_store.load_data())
	var saved := settings_store.load_data()
	for key in settings:
		if saved.has(key) and typeof(saved[key]) == typeof(settings[key]):  # JSON numbers load as floats
			settings[key] = saved[key]
	SunFx.set_quality(settings["quality"])
	Sfx.preload_all()
	_apply_volume()
	_pause = PauseScene.instantiate()
	add_child(_pause)
	_pause.resumed.connect(_resume)
	_pause.quit_requested.connect(_quit_to_title)
	_pause.settings_changed.connect(_on_settings_changed)
	show_start()


## Frame rate in the top-right corner (owner, 2026-10-28).
func _process(_delta: float) -> void:
	$FpsLayer/Fps.text = "FPS %d" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused and current and current.has_node("Hunter"):
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause.open(settings, current.stats_text() if current.has_method("stats_text") else "")


func _resume() -> void:
	_pause.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _quit_to_title() -> void:
	_pause.hide()
	get_tree().paused = false
	show_start()


## Every sound in the game is an effect, so the slider sets the master bus.
func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(settings["sfx_volume"]))


func _on_settings_changed(changed: Dictionary) -> void:
	settings = changed
	settings_store.save_data(settings)
	_apply_volume()
	SunFx.set_quality(settings["quality"], get_tree())
	if current and current.has_node("Hunter"):
		current.get_node("Hunter").apply_settings(settings)


func show_start() -> void:
	var start := StartScene.instantiate()
	_swap(start)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start.get_node("%Start").pressed.connect(show_camp)
	start.get_node("%Animations").pressed.connect(show_viewer)
	start.get_node("%PlanHunt").pressed.connect(show_planning.bind("hunt"))
	start.get_node("%PlanCamp").pressed.connect(show_planning.bind("camp"))


func show_viewer() -> void:
	var viewer := ViewerScene.instantiate()
	_swap(viewer)
	viewer.closed.connect(show_start)


## Planning mode (issue #29): the level with no hunter, under a free camera; Save stores its layout.
func show_planning(level_id: String) -> void:
	var level: Node3D = (MapScene if level_id == "hunt" else CampScene).instantiate()
	level.planning = true
	level.layout = _layout(level_id)
	if level_id == "camp":
		level.progress = progress
	_swap(level)
	var planner := Planner.new()
	planner.level = level
	planner.saved.connect(func(data: Dictionary) -> void: _layout_store(level_id).save_data(data))
	planner.reset_requested.connect(func() -> void:
		var store := _layout_store(level_id)
		for file_path in [store.path, store.backup_path()]:
			DirAccess.remove_absolute(file_path)
		show_planning(level_id))
	planner.closed.connect(show_start)
	level.add_child(planner)


static func _layout_store(level_id: String) -> SaveStore:
	var store := SaveStore.new()
	store.path = "user://layout_%s.json" % level_id
	return store


## The layout saved on this machine, else the one shipped with the game, else none.
func _layout(level_id: String) -> Dictionary:
	var data := _layout_store(level_id).load_data()
	if data.is_empty() and FileAccess.file_exists(SHIPPED_LAYOUT % level_id):
		var shipped = JSON.parse_string(FileAccess.get_file_as_string(SHIPPED_LAYOUT % level_id))
		data = shipped if shipped is Dictionary else {}
	return data


func show_camp() -> void:
	var camp := CampScene.instantiate()
	camp.progress = progress
	camp.layout = _layout("camp")
	_swap(camp)
	camp.hunter.apply_settings(settings)
	camp.purchased.connect(_save)
	camp.hunt_requested.connect(start_hunt)
	camp.gather_requested.connect(start_gather)


func _save() -> void:
	save_store.save_data(progress.to_dict())


func start_hunt() -> void:
	var map := MapScene.instantiate()
	map.layout = _layout("hunt")
	map.items = progress.hunt_items()  # only the packed gear and the ridden boar's saddle (issues #15, #16)
	map.helpers = progress.helpers
	map.companion = progress.companion
	map.first_hunt = progress.hunts == 0
	map.hunts_done = progress.hunts
	if progress.clan and progress.clan.stew_active(int(Time.get_unix_time_from_system())):
		map.stew = progress.clan.stew_bonus()
	if progress.blessed_until > int(Time.get_unix_time_from_system()):
		map.blessing = Shaman.HEALTH_SHARE
	if progress.paint.has("mount"):
		map.mount_paint = Color(ShopCatalog.PAINTS[progress.paint["mount"]]["color"])
	map.hunt_ended.connect(_show_results, CONNECT_DEFERRED)
	_swap(map)
	map.get_node("Hunter").apply_settings(settings)


## The gathering woods: the packed gear goes along, the finds come back like a hunt's (not counted as one).
func start_gather() -> void:
	var map := GatherScene.instantiate()
	map.items = progress.hunt_items()
	map.hunt_ended.connect(_show_results, CONNECT_DEFERRED)
	_swap(map)
	map.get_node("Hunter").apply_settings(settings)


func _show_results(hunt: RefCounted) -> void:
	# Save point: hunt results (section 18).
	progress.add_hunt(hunt)
	_save()
	var results := ResultsScene.instantiate()
	_swap(results)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	results.show_results(hunt, progress.tusks, Progress.Trophies.names(progress.last_trophies))
	results.get_node("%Again").pressed.connect(show_camp)


func _swap(next: Node) -> void:
	if current:
		current.queue_free()
	current = next
	next.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(next)
