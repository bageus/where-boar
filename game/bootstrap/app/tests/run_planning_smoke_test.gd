extends SceneTree

## Opens planning mode on the hunt map and the camp through main, adds, moves and deletes objects, then checks
## a fresh level given the captured layout looks the same. Nothing is written to the player's layout files.

const MainScene = preload("res://game/bootstrap/app/main.tscn")
const MapScene = preload("res://game/presentation/hunt_map/public/hunt_map.tscn")
const CampScene = preload("res://game/presentation/camp/public/camp.tscn")
const Planner = preload("res://game/presentation/planning/public/planner.gd")
const LevelLayout = preload("res://game/core/level_layout/public/level_layout.gd")
const EXPECTED_CHECKS := 11

var _frame := 0
var _failures := 0
var _checks := 0
var _main: Node
var _fresh: Node3D
var _expect := {}  # node path -> global position in the fresh level
var _gone := ""
## Ground point raised by the brush, with its new height.
var _raised := Vector3.ZERO


func _initialize() -> void:
	_main = MainScene.instantiate()
	_main.save_store.path = "user://smoke_save.json"
	_main.settings_store.path = "user://smoke_settings.json"
	root.add_child(_main)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("FAIL: " + what)


func _planner() -> Planner:
	for child in _main.current.get_children():
		if child is Planner:
			return child
	return null


## Adds a stump, moves the first target, deletes the first removable one; returns the captured layout.
func _edit(level_id: String) -> Dictionary:
	var planner := _planner()
	_check(planner != null and not _main.current.has_node("Hunter"), "%s planning has a planner and no hunter" % level_id)
	var centre: Vector3 = _main.current.planning_centre()
	planner._add({"res": "res://assets/nature/meshes/peak/PeakStump1.res", "solid": "box"}, centre + Vector3(3, 0, 3))
	var added: Node3D = planner._selected
	var moved: Node3D = planner._targets[0]
	moved.global_position += Vector3(2, 0, 0)
	_expect = {String(_main.current.get_path_to(added)): added.global_position,
			String(_main.current.get_path_to(moved)): moved.global_position}
	_gone = ""
	for target in planner._targets:
		if target not in [added, moved] and _main.current.planning_removable(target):
			_gone = String(_main.current.get_path_to(target))
			planner._selected = target
			planner._delete()
			break
	return LevelLayout.capture(_main.current, planner._targets, planner._removed)


func _verify(level_id: String) -> void:
	var ok := true
	for path: String in _expect:
		var node := _fresh.get_node_or_null(path) as Node3D
		ok = ok and node != null and node.global_position.is_equal_approx(_expect[path])
	_check(ok, "%s layout moves and adds objects in a fresh level" % level_id)
	_check(_gone == "" or not _fresh.has_node(_gone), "%s layout removes the deleted object" % level_id)
	_fresh.queue_free()


func _fresh_level(scene: PackedScene, data: Dictionary) -> void:
	_fresh = scene.instantiate()
	_fresh.planning = true
	_fresh.layout = JSON.parse_string(JSON.stringify(data))
	if "progress" in _fresh:
		_fresh.progress = _main.progress
	root.add_child(_fresh)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		1:
			_main.show_planning("hunt")
		3:
			var data := _edit("hunt")
			_check(_gone != "", "a hunt prop can be deleted")
			var planner := _planner()
			var terrain: Node3D = _main.current.planning_terrain()
			var at := Vector3(20, 0, 20)
			var before: float = terrain.height_at(at.x, at.z)
			planner._brush = "raise"
			planner.sculpt(Vector3(at.x, before, at.z), 1.0)
			_raised = Vector3(at.x, terrain.height_at(at.x, at.z), at.z)
			_check(_raised.y > before + 1.5, "the brush raises the ground")
			planner._brush = "paint:sand"
			planner.sculpt(Vector3(-20, 0, 20), 0.1)
			data = planner._layout()
			_fresh_level(MapScene, data)
		5:
			_check(is_equal_approx(_fresh.planning_terrain().height_at(_raised.x, _raised.z), _raised.y), "a fresh hunt map has the raised ground")
			_check(not _fresh.planning_terrain().grassy_at(-20, 20), "a fresh hunt map has the sand painted, with no grass")
			_verify("hunt")
			_main.show_planning("camp")
		7:
			_fresh_level(CampScene, _edit("camp"))
		9:
			_verify("camp")
		11:
			_planner().closed.emit()
			_check(_main.current.has_node("%PlanHunt"), "Exit goes back to the start screen")
			if _checks != EXPECTED_CHECKS:
				_failures += 1
				push_error("FAIL: %d of %d checks ran" % [_checks, EXPECTED_CHECKS])
			print("planning smoke test: %d failure(s)" % _failures)
			quit(1 if _failures else 0)
	return false
