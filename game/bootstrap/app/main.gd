extends Node

## Composition root: start screen -> camp -> hunt map -> results -> camp (section 07).

const StartScene = preload("res://game/presentation/menus/public/start_screen.tscn")
const ResultsScene = preload("res://game/presentation/menus/public/results_screen.tscn")
const MapScene = preload("res://game/presentation/hunt_map/public/hunt_map.tscn")
const CampScene = preload("res://game/presentation/camp/public/camp.tscn")
const Progress = preload("res://game/features/settlement/public/progress.gd")
const SaveStore = preload("res://game/infrastructure/save/public/save_store.gd")

## The one screen or map shown now.
var current: Node
var save_store := SaveStore.new()
var progress: Progress


func _ready() -> void:
	progress = Progress.from_dict(save_store.load_data())
	show_start()


func show_start() -> void:
	var start := StartScene.instantiate()
	_swap(start)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start.get_node("%Start").pressed.connect(show_camp)


func show_camp() -> void:
	var camp := CampScene.instantiate()
	camp.progress = progress
	_swap(camp)
	camp.purchased.connect(_save)
	camp.hunt_requested.connect(start_hunt)


func _save() -> void:
	save_store.save_data(progress.to_dict())


func start_hunt() -> void:
	var map := MapScene.instantiate()
	map.items = progress.items
	map.hunt_ended.connect(_show_results, CONNECT_DEFERRED)
	_swap(map)


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
	add_child(next)
