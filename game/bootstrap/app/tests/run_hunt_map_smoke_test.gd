extends SceneTree

## Loads the main scene headless and checks the hunt wiring: start, boars spawn, see the hunter,
## react to a thrown net and spear, the goal counts the capture and returning to camp shows results.

const MainScene = preload("res://game/bootstrap/app/main.tscn")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")

var _frame := 0
var _failures := 0
var _main: Node
var _map: Node3D


func _initialize() -> void:
	_main = MainScene.instantiate()
	# Keep the player's real save out of the test.
	_main.save_store.path = "user://smoke_save.json"
	for file_path in [_main.save_store.path, _main.save_store.backup_path()]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_main.current.get_node("%Start").pressed.emit()
		_map = _main.current
		return false
	if _frame == 122:
		_check(_main.current.name == "ResultsScreen", "returning to camp shows results")
		_check("caught 1" in _main.current.get_node("%Summary").text, "results list the caught boar")
		_check(FileAccess.file_exists(_main.save_store.path), "results are saved")
		print("hunt map smoke test: %d failure(s)" % _failures)
		quit(1 if _failures else 0)
	if _frame > 120:
		return false
	var hunter: CharacterBody3D = _map.get_node("Hunter")
	var boars := _map.get_node("Boars").get_children()
	match _frame:
		2:
			_check(boars.size() == 6, "six boars spawn")
			# Put the hunter 5 m from the first boar, facing it; it must start fleeing.
			hunter.global_position = boars[0].global_position + Vector3(0, -0.4, 5)
			hunter.rotation = Vector3.ZERO
		4:
			_check(boars[0].state_name() == "FLEE", "boar near hunter flees")
		5:
			# Park every boar far away so none wanders into the throws below.
			for i in boars.size():
				boars[i].set_physics_process(false)
				boars[i].global_position = Vector3(-30 + i * 3, 0, -32)
			_freeze_and_aim(hunter, boars[1], Vector3(-3, 0, 20))
			hunter.weapon = hunter.Weapon.NET
			hunter._attack()
		60:
			_check(boars[1].state_name() == "CAPTURED", "thrown net captures boar")
			_freeze_and_aim(hunter, boars[2], Vector3(3, 0, 20))
			hunter.weapon = hunter.Weapon.SPEAR
			Input.action_press("aim")
			hunter._attack()
			Input.action_release("aim")
		120:
			_check(boars[2].state_name() == "PANIC", "thrown spear hits and panics boar")
			_check(not hunter.loadout.spear_in_hand and hunter.loadout.nets == 2, "loadout spent")
			_check(_map.hunt.remaining() == 5 and _map.hunt.count_all(BoarOutcome.Kind.CAPTURED) == 1, "goal counts the capture")
			_check(boars[2].get_node("HealthBar/Fill").scale.x < 1.0, "health bar shrinks after a hit")
			hunter.global_position = _map.get_node("ReturnPoint").global_position
			hunter.interacted.emit()
	return false


## Moves the target to open ground at spot and puts the hunter 6 m south of it, aiming at its body.
func _freeze_and_aim(hunter: CharacterBody3D, boar: CharacterBody3D, spot: Vector3) -> void:
	boar.global_position = spot
	hunter.global_position = spot + Vector3(0, 0.05, 6)
	hunter.rotation = Vector3.ZERO
	# Eye 1.6 m, boar body 0.5 m, about 0.5 m of throw drop over 6 m.
	hunter.get_node("Camera").rotation = Vector3(-atan(0.6 / 6.0), 0, 0)


func _check(ok: bool, name: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + name)
