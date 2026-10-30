extends SceneTree

## Loads the main scene headless and checks the hunt wiring: start, camp, boars spawn, see the hunter,
## react to a thrown net and spear, the goal counts the capture and returning to camp shows results.

const MainScene = preload("res://game/bootstrap/app/main.tscn")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const MapScene = preload("res://game/presentation/hunt_map/public/hunt_map.tscn")

var _frame := 0
var _failures := 0
## A script error skips the rest of a frame silently; counting checks catches that.
const EXPECTED_CHECKS := 37
var _checks := 0
var _main: Node
var _map: Node3D
var _hunt: RefCounted


func _initialize() -> void:
	ShopCatalog.free_for_testing = false
	_main = MainScene.instantiate()
	# Keep the player's real save out of the test.
	_main.save_store.path = "user://smoke_save.json"
	_main.settings_store.path = "user://smoke_settings.json"
	for file_path in [_main.save_store.path, _main.save_store.backup_path(), _main.settings_store.path]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	root.add_child(_main)


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_main.current.get_node("%Start").pressed.emit()
		var camp: Node3D = _main.current
		_check_pause_and_settings(camp)
		camp.hunter.global_position = camp.get_node("Stations/StartHunt").global_position + Vector3(0, 0, 1.5)
		camp.hunter.interacted.emit()
		_map = _main.current
		_check(_map.name == "HuntMap", "start hunt station in camp opens the hunt")
		return false
	if _frame == 122:
		_check(_main.current.name == "ResultsScreen", "returning to camp shows results")
		_check("caught 1" in _main.current.get_node("%Summary").text or "caught 2" in _main.current.get_node("%Summary").text, "results list the caught boars")
		_check(_hunt.count_all(BoarOutcome.Kind.CAPTURED) == 2 and _hunt.held == 0, "the trapped boar counts as caught at hunt end")
		_check(FileAccess.file_exists(_main.save_store.path), "results are saved")
		_main.current.get_node("%Again").pressed.emit()
		_check(_main.current.name == "Camp" and "Tusks:" in _main.current.get_node("Hud/Progress").text, "results lead back to camp")
		_buy_club(_main.current)
		_check_trap_setter()
		if _checks != EXPECTED_CHECKS:
			_failures += 1
			push_error("FAIL: ran %d of %d checks" % [_checks, EXPECTED_CHECKS])
		print("hunt map smoke test: %d failure(s)" % _failures)
		quit(1 if _failures else 0)
	if _frame > 120:
		return false
	if _failures > 0:
		# Later frames depend on earlier steps; stop at the first failure.
		print("hunt map smoke test: %d failure(s)" % _failures)
		quit(1)
		return false
	var hunter: CharacterBody3D = _map.get_node("Hunter")
	var boars := _map.get_node("Boars").get_children()
	match _frame:
		2:
			_check(boars.size() == 47, "herds, groups and loners spawn")
			# Put the hunter 5 m from the first boar, facing it; it must start fleeing.
			hunter.global_position = _on_ground(boars[0].global_position + Vector3(0, 0, 5))
			hunter.rotation = Vector3.ZERO
		3:
			# Alert builds up over time (playtest 2026-10-27); a witnessed kill makes it run at once.
			_check(boars[0].alert.progress > 0.0 and boars[0].state_name() == "WANDER", "boar near hunter grows alert before it runs")
			boars[0].saw_kill()
		4:
			_check(boars[0].state_name() == "FLEE" and boars[0]._calm_left > 10.0, "a boar that saw a kill flees, for twice as long")
			_check(boars[14].state_name() != "WANDER", "fear spreads through the herd")
			hunter.shout()
			_check(boars[0]._forced_left > 0.0, "a shout steers the fleeing boar")
			hunter.equip(_map.items.merged({"item_pear": 1}))
			hunter._place_bait()
			_check(boars[3].baits.size() == 1 and hunter.loadout.used == {"item_pear": 1}, "placed bait is shown to boars")
		5:
			# Park every boar far away so none wanders into the throws below.
			for i in boars.size():
				boars[i].set_physics_process(false)
				boars[i].global_position = _on_ground(Vector3(-40 + i * 2, 0, -60))
			_freeze_and_aim(hunter, boars[1], Vector3(-3, 0, 20), hunter.NET_SPEED)
			hunter.weapon = hunter.Weapon.NET
			hunter._attack()
		60:
			_check(boars[1].state_name() == "CAPTURED", "thrown net captures boar")
			# A pit dug under a parked boar holds it.
			var pit: Node3D = hunter.TRAP_SCENES["item_pit"].instantiate()
			_map.add_child(pit)
			pit.global_position = boars[3].global_position
			boars[3].set_physics_process(true)
			# Helpers: a netted wild rooster goes to the pen; pen animals can be summoned once.
			_map.get_node("Wild").get_child(0).net_hit()
			_check(_map.hunt.helpers_caught == {"rooster": 1}, "a netted wild rooster is caught")
			var turkey: Node3D = _map.get_node("Wild").get_child(1)
			hunter.global_position = turkey.global_position + Vector3(1.0, 0.0, 0.0)
			_map._on_interacted()
			_check(_map.hunt.helpers_caught == {"rooster": 1, "turkey": 1}, "a wild turkey within reach is grabbed with E")
			_map.helpers = {"rooster": 1, "turkey": 1}
			_map.summon("turkey")
			_map.summon("rooster")
			_check(not _map.get_node("Hud/Minimap").marked.is_empty() and _map.get_node_or_null("RoosterDriver") == null,
					"turkey marks a group on the minimap; only one helper per hunt")
			_freeze_and_aim(hunter, boars[2], Vector3(3, 0, 20))
			hunter.weapon = hunter.Weapon.SPEAR
			Input.action_press("aim")
			hunter._aim_power = 1.0  # a fully charged throw
			hunter._attack()
			Input.action_release("aim")
		120:
			_check(boars[2].state_name() == "PANIC", "thrown spear hits and panics boar")
			_check_stuck_items(hunter, boars[2], boars[1])
			_check(_map.hunt.remaining() == _map.hunt.total - 2 and _map.hunt.count_all(BoarOutcome.Kind.CAPTURED) == 1, "goal counts the capture")
			_check(_map.hunt.held == 1, "pit holds a boar")  # wide opening: a herd mate of the parked boar may drop in first
			_hunt = _map.hunt
			_check(boars[2].get_node("HealthBar/Fill").scale.x < 1.0, "health bar shrinks after a hit")
			_check_relief(hunter, boars[4])
			hunter.global_position = _map.get_node("ReturnPoint").global_position
			hunter.interacted.emit()
	return false


## Hits stay in the boar (owner, 2026-10-27): the net comes back from the caught boar only up close,
## the spear not at all while its boar still runs.
func _check_stuck_items(hunter: CharacterBody3D, running: Node3D, caught: Node3D) -> void:
	var nets_before: int = hunter.loadout.nets
	hunter.global_position = running.global_position + Vector3(1.0, 0.0, 0.0)
	hunter._pick_up()
	var spear_stays: bool = not hunter.loadout.spear_in_hand
	hunter.global_position = caught.global_position + Vector3(1.0, 0.0, 0.0)
	hunter._pick_up()
	_check(nets_before == 2 and spear_stays and hunter.loadout.nets == 3, "stuck spear stays in a running boar; net taken back from the caught one")
	var pile: Node3D = _map.get_node("Props/StonePile1")
	var stones: int = hunter.loadout.stones
	hunter.global_position = pile.global_position
	hunter._pick_up()
	_check(hunter.loadout.stones == stones + 3 and pile.is_queued_for_deletion(), "a stone pile on the map refills the sling pouch")


## Relief (owner, 2026-10-27): the lookout mesa's cliff hides a hunter on top from a boar below;
## things set on its gentle east slope lie on the ground.
func _check_relief(hunter: CharacterBody3D, boar: CharacterBody3D) -> void:
	boar.global_position = _on_ground(Vector3(-30, 0, 15))
	hunter.global_position = _on_ground(Vector3(-30, 0, 25))
	_check(hunter.global_position.y - boar.global_position.y > 4.0 and not boar._sight_clear(),
			"a hunter on the lookout is out of sight of a boar under the cliff")
	var slope := Vector3(-18, 0, 25)
	var set_down: Vector3 = hunter.ground_at(slope + Vector3.UP * (_on_ground(slope).y + 1.0))
	_check(absf(set_down.y - _on_ground(slope).y) < 0.1, "things set on a slope lie on the ground")


## point moved onto the terrain surface.
func _on_ground(point: Vector3) -> Vector3:
	return Vector3(point.x, _map.get_node("Terrain").height_at(point.x, point.z), point.z)


## Esc pauses the camp; changing FOV applies to the hunter and is saved; Continue unpauses.
func _check_pause_and_settings(camp: Node3D) -> void:
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	_main._unhandled_input(esc)
	_check(paused and _main._pause.visible, "Esc pauses the game")
	_main._pause.get_node("%Fov").value = 95.0
	_check(is_equal_approx(camp.hunter.get_node("Camera").fov, 95.0) and FileAccess.file_exists(_main.settings_store.path), "FOV setting applies and is saved")
	_main._pause.get_node("%Continue").pressed.emit()
	_check(not paused, "Continue unpauses")


## A hired trap setter puts two traps at escape zones; a saddled boar waits and can be ridden.
func _check_trap_setter() -> void:
	var map: Node3D = MapScene.instantiate()
	map.items = {"item_trap_setter": 1, "item_snare": 3, "item_saddle_runner_grey": 1}
	root.add_child(map)
	var hunter: CharacterBody3D = map.get_node("Hunter")
	var traps := hunter.get_children().filter(func(n: Node) -> bool: return n is Area3D)
	_check(traps.size() == 2 and hunter.loadout.traps["item_snare"] == 1 \
			and traps.all(func(n: Node) -> bool: return n.is_in_group("placed_traps") and n.has_node("Marker")), "trap setter sets two marked traps")
	# A trap the hunter sets is a ghost until built; the setter comes along to build it.
	hunter.place_trap()
	var ghost: Node3D = hunter.get_children().filter(func(n: Node) -> bool: return n is Area3D)[-1]
	var BuildSite = hunter.BuildSite
	var was_ghost: bool = BuildSite.is_ghost(ghost) and hunter.loadout.traps["item_snare"] == 0
	_check(was_ghost and BuildSite.build(ghost, hunter.TRAP_BUILD_SECONDS["item_snare"]) and not BuildSite.is_ghost(ghost) \
			and hunter.get_children().any(func(n: Node) -> bool: return n.get_script() == hunter.TrapSetter), "a placed trap is a ghost until built; the setter comes along")
	# A tripwire goes down in two presses: the rope runs from the first peg to the second, at most 10 m.
	hunter.loadout.traps["item_tripwire"] = 1
	hunter.loadout.trap_id = "item_tripwire"
	hunter.place_trap()
	var wire: Node3D = hunter._laying_wire
	var laying: bool = wire != null and not BuildSite.is_ghost(wire)
	wire.stretch_to(wire.wire_start + Vector3(30, 0, 0))
	hunter.place_trap()
	_check(laying and BuildSite.is_ghost(wire) and hunter._laying_wire == null \
			and is_equal_approx(wire.get_node("Collision").shape.size.x, 10.0), "tripwire: second T sets the second peg, rope at most 10 m")
	_check("Boars left: 47" in map.stats_text() and map.get_node("Hud/Goal").text.begins_with("Tusks:"), "boar stats for the pause menu; tusks under the minimap")
	var mount: Node3D = hunter.get_node("Rider").mount
	_check(mount != null and mount.boar_type.id == "runner_grey", "the saddled runner waits beside the hunter")
	hunter.get_node("Rider").toggle()
	_check(hunter.ride.is_riding() and not mount.visible and hunter.ride.speed(4.0) == 10.0, "E mounts the runner")
	map.free()


## Uses the armory with enough tusks and buys the first item, the club.
func _buy_club(camp: Node3D) -> void:
	_main.progress.tusks = 100
	camp.hunter.global_position = camp.get_node("Stations/WeaponShop").global_position + Vector3(1.5, 0, 0)
	camp.hunter.interacted.emit()
	var shop: Control = camp.get_node("Hud/ShopPanel")
	_check(shop.visible, "armory opens the shop")
	shop.get_node("%Items").get_child(0).pressed.emit()
	_check(_main.progress.owns("item_club") and _main.progress.tusks == 70, "club bought for 30 tusks")
	_check(camp.hunter.loadout.has(camp.hunter.Weapon.CLUB), "bought club is in the hotbar")
	_check("item_club" in FileAccess.get_file_as_string(_main.save_store.path), "purchase is saved")


## Moves the target to open ground at spot and puts the hunter 6 m south of it, aiming at its body.
func _freeze_and_aim(hunter: CharacterBody3D, boar: CharacterBody3D, spot: Vector3, speed: float = 18.0) -> void:
	boar.global_position = _on_ground(spot)
	hunter.global_position = _on_ground(spot + Vector3(0, 0, 6)) + Vector3(0, 0.05, 0)
	hunter.rotation = Vector3.ZERO
	# Eye 1.6 m, boar body 0.5 m, the throw's drop over 6 m at this speed, plus the ground's rise.
	var drop := 4.9 * pow(6.0 / speed, 2.0)
	var rise := hunter.global_position.y - boar.global_position.y
	hunter.get_node("Camera").rotation = Vector3(-atan((1.1 - drop + rise) / 6.0), 0, 0)


func _check(ok: bool, name: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("FAIL: " + name)
