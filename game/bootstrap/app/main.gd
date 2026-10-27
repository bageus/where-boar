extends Node

## Composition root: start screen -> camp -> hunt map -> results -> camp (section 07).

const StartScene = preload("res://game/presentation/menus/public/start_screen.tscn")
const ResultsScene = preload("res://game/presentation/menus/public/results_screen.tscn")
const PauseScene = preload("res://game/presentation/menus/public/pause_menu.tscn")
const MapScene = preload("res://game/presentation/hunt_map/public/hunt_map.tscn")
const CampScene = preload("res://game/presentation/camp/public/camp.tscn")
const Progress = preload("res://game/features/settlement/public/progress.gd")
const SaveStore = preload("res://game/infrastructure/save/public/save_store.gd")

## The one screen or map shown now.
var current: Node
var save_store := SaveStore.new()
var progress: Progress
## Settings live in their own file, apart from progress (section 18).
var settings_store := _settings_store()
var settings := {"fov": 80.0, "mouse_sensitivity": 0.002, "camera_motion": true}
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
		if saved.has(key) and typeof(saved[key]) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL]:
			settings[key] = saved[key]
	_pause = PauseScene.instantiate()
	add_child(_pause)
	_pause.resumed.connect(_resume)
	_pause.quit_requested.connect(_quit_to_title)
	_pause.settings_changed.connect(_on_settings_changed)
	show_start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused and current and current.has_node("Hunter"):
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_pause.open(settings)


func _resume() -> void:
	_pause.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _quit_to_title() -> void:
	_pause.hide()
	get_tree().paused = false
	show_start()


func _on_settings_changed(changed: Dictionary) -> void:
	settings = changed
	settings_store.save_data(settings)
	if current and current.has_node("Hunter"):
		current.get_node("Hunter").apply_settings(settings)


func show_start() -> void:
	var start := StartScene.instantiate()
	_swap(start)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start.get_node("%Start").pressed.connect(show_camp)


func show_camp() -> void:
	var camp := CampScene.instantiate()
	camp.progress = progress
	_swap(camp)
	camp.hunter.apply_settings(settings)
	camp.purchased.connect(_save)
	camp.hunt_requested.connect(start_hunt)


func _save() -> void:
	save_store.save_data(progress.to_dict())


func start_hunt() -> void:
	var map := MapScene.instantiate()
	map.items = progress.items
	map.helpers = progress.helpers
	map.first_hunt = progress.hunts == 0
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
	results.show_results(hunt, progress.tusks)
	results.get_node("%Again").pressed.connect(show_camp)


func _swap(next: Node) -> void:
	if current:
		current.queue_free()
	current = next
	next.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(next)
