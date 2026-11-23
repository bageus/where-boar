extends SceneTree

## Loads the main scene headless and checks the gathering trip: the signpost's Gather opens the gathering woods,
## finds are scattered, E picks one up, E at the return point shows results, and the trip is not counted as a hunt.

const MainScene = preload("res://game/bootstrap/app/main.tscn")

var _frame := 0
var _failures := 0
var _main: Node
var _map: Node3D


func _initialize() -> void:
	_main = MainScene.instantiate()
	_main.save_store.path = "user://gather_smoke_save.json"
	_main.settings_store.path = "user://gather_smoke_settings.json"
	for file_path in [_main.save_store.path, _main.save_store.backup_path(), _main.settings_store.path]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_main.current.get_node("%Start").pressed.emit()
		_main.current._signpost.gather_chosen.emit()
		_map = _main.current
		_check(_map.name == "GatherMap", "the signpost's Gather opens the gathering woods")
		return false
	if _frame == 10:
		var gatherables: Node3D = _map.get_node("Terrain/Gatherables")
		var finds := 0
		for key in gatherables._batches:
			finds += gatherables._batches[key].size()
		print("gathering woods: %d still finds, %d critters" % [finds, gatherables._critters.size()])
		_check(finds > 1000, "the woods are full of finds")
		var hunter: Node3D = _map.get_node("Hunter")
		_check(absf(hunter.global_position.y - _map.get_node("Terrain").height_at(hunter.global_position.x, hunter.global_position.z)) < 0.5, "the hunter stands on the ground")
		hunter.global_position = gatherables._critters[0].global_position
		hunter.interacted.emit()
		_check(_map.hunt.gathered.values() == [1], "E picks up a find")
		hunter.global_position = _map.get_node("ReturnPoint").global_position
		hunter.interacted.emit()
		return false
	if _frame == 12:
		_check(_main.current.name == "ResultsScreen", "E at the return point shows results")
		_check(_main.progress.hunts == 0 and _main.progress.materials.values() == [1], "the finds are kept, no hunt is counted")
		print("gather map smoke test: %d failure(s)" % _failures)
		quit(1 if _failures else 0)
	return false


func _check(ok: bool, name: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + name)
