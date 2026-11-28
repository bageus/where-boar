extends SceneTree

## Loads the main scene headless and checks the hunt wiring: start, camp, boars spawn, see the hunter,
## react to a thrown net and spear, the goal counts the capture and returning to camp shows results.

const MainScene = preload("res://game/bootstrap/app/main.tscn")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const MapScene = preload("res://game/presentation/hunt_map/public/hunt_map.tscn")

var _frame := 0
var _failures := 0
## A script error skips the rest of a frame silently; counting checks catches that.
const EXPECTED_CHECKS := 40
var _checks := 0
var _main: Node
var _map: Node3D
var _hunt: RefCounted
var _net_target: CharacterBody3D
var _spear_target: CharacterBody3D
var _pit_target: CharacterBody3D
var _relief_target: CharacterBody3D


func _initialize() -> void:
	seed(59)  # Repeatable herd types and AI choices in the smoke fixture.
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
		_map = _start_at_signpost(camp)
		return false
	if _frame == 122:
		_check(_main.current.name == "ResultsScreen", "returning to camp shows results")
		_check("caught 1" in _main.current.get_node("%Summary").text or "caught 2" in _main.current.get_node("%Summary").text, "results list the caught boars")
		_check(_hunt.count_all(BoarOutcome.Kind.CAPTURED) == 2 and _hunt.held == 0, "the trapped boar counts as caught at hunt end")
		_check(FileAccess.file_exists(_main.save_store.path), "results are saved")
		_check("Gathered:" in _main.current.get_node("%Summary").text, "results list the forest finds")
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
			# Keep references: node order can change as the hunt progresses.
			_net_target = boars[1]
			_spear_target = boars[2]
			_pit_target = boars[3]
			_relief_target = boars[4]
			# Park every boar far away so none wanders into the throws below.
			for i in boars.size():
				boars[i].set_physics_process(false)
				boars[i].global_position = _on_ground(Vector3(-40 + i * 2, 0, -60))
			# Keep the pit target clear of the parked herd before enabling the trap.
			_pit_target.global_position = _on_ground(Vector3(0, 0, -35))
			_freeze_and_aim(hunter, _net_target, Vector3(-3, 0, 20), hunter.NET_SPEED)
			hunter.weapon = hunter.Weapon.NET
			hunter._attack()
		60:
			_check(_net_target.state_name() == "CAPTURED", "thrown net captures boar")
			# A pit dug under a parked boar holds it.
			var pit: Node3D = hunter.TRAP_SCENES["item_pit"].instantiate()
			_map.add_child(pit)
			pit.global_position = _pit_target.global_position
			_pit_target.set_physics_process(true)
			_check_wild_birds(hunter)
			_freeze_and_aim(hunter, _spear_target, Vector3(3, 0, 20), hunter.SPEAR_MAX_SPEED, 4.0)
		62:
			# Give the physics server two ticks to synchronize the moved static hitbox.
			_aim_at_target(hunter, _spear_target, hunter.SPEAR_MAX_SPEED, 4.0)
			hunter.weapon = hunter.Weapon.SPEAR
			Input.action_press("aim")
			hunter._aim_power = 1.0  # a fully charged throw
			hunter._attack()
			Input.action_release("aim")
		120:
			_check(_spear_target.state_name() == "PANIC", "thrown spear hits and panics boar")
			_check_stuck_items(hunter, _spear_target, _net_target)
			_check(_map.hunt.remaining() == _map.hunt.total - 2 and _map.hunt.count_all(BoarOutcome.Kind.CAPTURED) == 1, "goal counts the capture")
			_check(_map.hunt.held == 1 and _pit_target.state_name() == "TRAPPED", "pit holds its target boar")
			_hunt = _map.hunt
			_check(_spear_target.get_node("HealthBar/Fill").scale.x < 1.0, "health bar shrinks after a hit")
			_check_relief(hunter, _relief_target)
			_gather_and_return(hunter)
	return false


## Net a rooster, grab the isolated turkey, then check the one-helper limit.
func _check_wild_birds(hunter: CharacterBody3D) -> void:
	# Helpers: a netted wild rooster goes to the pen; pen animals can be summoned once.
	_map.get_node("Wild").get_child(0).net_hit()
	_check(_map.hunt.helpers_caught == {"rooster": 1}, "a netted wild rooster is caught")
	var turkey: Node3D = _map.get_node("Wild").get_child(1)
	# Isolate the intended bird: neighbours, including the queued rooster,
	# must not win the same-frame interaction depending on random wander.
	for animal: Node3D in _map.get_node("Wild").get_children():
		animal.set_physics_process(false)
		animal.global_position = _on_ground(Vector3(55, 0, -55))
	turkey.global_position = _on_ground(Vector3(12, 0, 30))
	hunter.global_position = turkey.global_position + Vector3(1.0, 0.0, 0.0)
	_map._on_interacted()
	_check(_map.hunt.helpers_caught == {"rooster": 1, "turkey": 1}, "a wild turkey within reach is grabbed with E")
	_map.helpers = {"rooster": 1, "turkey": 1}
	_map.summon("turkey")
	_map.summon("rooster")
	_check(not _map.get_node("Hud/Minimap").marked.is_empty() and _map.get_node_or_null("RoosterDriver") == null,
			"turkey marks a group on the minimap; only one helper per hunt")


## E next to a frog puts a find in the pockets (issue #26), then E at the return point ends the hunt.
func _gather_and_return(hunter: CharacterBody3D) -> void:
	hunter.global_position = _map.get_node("Terrain/Gatherables")._critters[0].global_position
	hunter.interacted.emit()
	_check(_map.hunt.gathered.values() == [1], "E picks up a forest find in reach into the pockets")
	hunter.global_position = _map.get_node("ReturnPoint").global_position
	hunter.interacted.emit()


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
	# The cliff's slope is now wider; stand at its base rather than halfway up.
	boar.global_position = _on_ground(Vector3(-30, 0, 13))
	hunter.global_position = _on_ground(Vector3(-30, 0, 20))
	var ray := PhysicsRayQueryParameters3D.create(boar.global_position + Vector3.UP * boar.EYE_RISE,
			hunter.global_position + Vector3.UP * boar.HUNTER_RISE, boar.collision_mask | boar.COVER_LAYER,
			[boar.get_rid(), hunter.get_rid()])
	var hit := boar.get_world_3d().direct_space_state.intersect_ray(ray)
	var blocked: bool = hit.get("collider") == _map.get_node("Terrain")
	_check(hunter.global_position.y - boar.global_position.y > 4.0 and blocked,
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
	var placing: bool = hunter._placement != null and hunter.loadout.traps["item_snare"] == 1
	hunter._placement.update(hunter)
	hunter._placement.turn = 0.5
	hunter._put_down_trap(hunter._placement.transform_for(hunter))
	placing = placing and hunter._placement == null
	var ghost: Node3D = hunter.get_children().filter(func(n: Node) -> bool: return n is Area3D)[-1]
	var BuildSite = hunter.BuildSite
	var was_ghost: bool = placing and BuildSite.is_ghost(ghost) and hunter.loadout.traps["item_snare"] == 0
	_check(was_ghost and BuildSite.build(ghost, hunter.TRAP_BUILD_SECONDS["item_snare"]) and not BuildSite.is_ghost(ghost) \
			and hunter.get_children().any(func(n: Node) -> bool: return n.get_script() == hunter.Crew.HIRES["item_trap_setter"]), "a placed trap is a ghost until built; the setter comes along")
	# A tripwire goes down in two presses: the rope runs from the first peg to the second, at most 10 m.
	hunter.loadout.traps["item_tripwire"] = 1
	hunter.loadout.trap_id = "item_tripwire"
	hunter.place_trap()
	hunter._put_down_trap(hunter._placement.transform_for(hunter))
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
	_check_healer()


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


## Moves the target to open ground and uses the current camera and target transforms.
func _freeze_and_aim(hunter: CharacterBody3D, boar: CharacterBody3D, spot: Vector3, speed: float = 18.0, distance := 6.0) -> void:
	boar.global_position = _on_ground(spot)
	boar.rotation = Vector3.ZERO
	hunter.global_position = _on_ground(spot + Vector3(0, 0, distance)) + Vector3(0, 0.05, 0)
	hunter.rotation = Vector3.ZERO
	_aim_at_target(hunter, boar, speed, distance)


func _aim_at_target(hunter: CharacterBody3D, boar: CharacterBody3D, speed: float, distance: float) -> void:
	var camera: Camera3D = hunter.get_node("Camera")
	var target: Vector3 = boar.get_node("Hitbox/Shape").global_position
	var drop := 4.9 * pow(distance / speed, 2.0)
	camera.look_at(target + Vector3.UP * drop, Vector3.UP)


func _check(ok: bool, name: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("FAIL: " + name)


## A hired healer comes along instead of the trap setter and heals the hunter standing next to him (issue #12).
func _check_healer() -> void:
	var map: Node3D = MapScene.instantiate()
	map.items = {"item_healer": 1}
	root.add_child(map)
	var hunter: CharacterBody3D = map.get_node("Hunter")
	var mates := hunter.get_children().filter(func(n: Node) -> bool: return n.get_script() in hunter.Crew.HIRES.values())
	var healer: Node3D = mates[0] if mates.size() == 1 else null
	hunter.health.value = 50
	if healer:
		healer.global_position = hunter.global_position + Vector3(1.0, 0.0, 0.0)
		healer._physics_process(1.0)
	_check(healer and healer.get_script() == hunter.Crew.HIRES["item_healer"] and hunter.health.value == 60, "a hired healer comes along and heals")
	map.free()


## E at the signpost opens its window; Start (with the countdown cut to nothing) opens the hunt (issue #24).
func _start_at_signpost(camp: Node3D) -> Node:
	camp.hunter.interacted.emit()
	var signpost_open: bool = camp._signpost.visible
	camp._launch("public", 0, PackedStringArray())
	_check(signpost_open and _main.current.name == "HuntMap", "the signpost opens its window, then its hunt starts")
	return _main.current
