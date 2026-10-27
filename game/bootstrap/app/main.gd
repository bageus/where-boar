extends Node

## Composition root: start screen -> hunt map -> results -> start screen (M007).

const StartScene = preload("res://game/presentation/menus/public/start_screen.tscn")
const ResultsScene = preload("res://game/presentation/menus/public/results_screen.tscn")
const MapScene = preload("res://game/presentation/hunt_map/public/hunt_map.tscn")

## The one screen or map shown now.
var current: Node


func _ready() -> void:
	show_start()


func show_start() -> void:
	var start := StartScene.instantiate()
	_swap(start)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start.get_node("%Start").pressed.connect(start_hunt)


func start_hunt() -> void:
	var map := MapScene.instantiate()
	map.hunt_ended.connect(_show_results, CONNECT_DEFERRED)
	_swap(map)


func _show_results(hunt: RefCounted) -> void:
	var results := ResultsScene.instantiate()
	_swap(results)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	results.show_results(hunt)
	results.get_node("%Again").pressed.connect(show_start)


func _swap(next: Node) -> void:
	if current:
		current.queue_free()
	current = next
	add_child(next)
