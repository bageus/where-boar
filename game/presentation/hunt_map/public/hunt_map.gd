extends Node3D

## Green Valley grey-box hunt map (section 11): spawns boars at random markers, counts their outcomes and ends the hunt (M007).

const BoarScene = preload("res://game/features/boar/public/boar_body.tscn")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const CompanionRules = preload("res://game/features/companions/public/companion_rules.gd")
const RoosterScene = preload("res://game/features/companions/public/rooster_driver.tscn")
const ShoutWaveScene = preload("res://game/presentation/hunt_map/props/shout_wave.tscn")
const WILD_SCENES := [
	preload("res://game/features/companions/public/wild_rooster.tscn"),
	preload("res://game/features/companions/public/wild_turkey.tscn"),
]

## Fact: the hunter returned to camp, was downed, or no free boars are left.
signal hunt_ended(hunt: Hunt)

## ASSUMPTION (D013, section 11): two herds, six groups and loners.
const GROUP_SIZES := [15, 12, 4, 4, 3, 3, 3, 1, 1, 1]
const RETURN_RADIUS := 3.0
## ASSUMPTION (D013): how far a shout carries, metres.
const SHOUT_RADIUS := 15.0
## The hired trap setter covers this many escape zones, this far in front of each (ASSUMPTION).
const SETTER_TRAPS := 2
const SETTER_OFFSET := 5.0
const TIP_SECONDS := 8.0
const SCOUT_CHECK_SECONDS := 0.5
const TIPS := [
	"Boars flee when you get close. Caps Lock toggles sneaking.",
	"Hit a boar with the spear (LMB), or hold RMB and click to throw it. Press E to pick it up.",
	"Switch to the net (2) and throw it to catch a boar alive: caught boars pay more tusks.",
	"Fleeing boars escape through the red zones shown on the minimap.",
	"A hurt boar may turn and ram you. Keep moving!",
	"Walk back to the green camp zone and press E to end the hunt with your loot.",
]

var hunt: Hunt
## Camp gear (item_id -> count), injected before the map enters the tree.
var items: Dictionary = {}
## Helper animals in the camp pen (animal_id -> count), injected like items. Each kind helps once per hunt.
var helpers: Dictionary = {}
var _helpers_used: Array[String] = []
## The one helper animal taken on this hunt (owner, 2026-10-27); "" means the first one in the pen.
var companion := ""
## The turkey keeps a group marked and looks for another when it scatters or is gone.
var _scouting := false
var _scout_left := 0.0
## Injected: the player's first hunt shows tips (section 16).
var first_hunt := false
var _tip := 0
var _tip_left := 0.0
## Bait on the ground; the same array is shared with every boar.
var _baits: Array[Node3D] = []

@onready var _hunter: CharacterBody3D = $Hunter
@onready var _terrain: StaticBody3D = $Terrain
@onready var _goal: Label = $Hud/Goal


func _ready() -> void:
	var zones: Array[Vector2] = []
	for zone: Node3D in $EscapeZones.get_children():
		zones.append(Vector2(zone.position.x, zone.position.z))
	var spawns := $BoarSpawns.get_children()
	spawns.shuffle()
	var groups := mini(GROUP_SIZES.size(), spawns.size())
	var total := 0
	for g in groups:
		total += GROUP_SIZES[g]
	hunt = Hunt.new(total)
	for g in groups:
		_spawn_group(GROUP_SIZES[g], spawns[g].position, zones)
	# Spare spawn points get one wild rooster and one wild turkey to catch (D024).
	for w in mini(WILD_SCENES.size(), spawns.size() - groups):
		var animal: CharacterBody3D = WILD_SCENES[w].instantiate()
		animal.hunter = _hunter
		animal.position = spawns[groups + w].position
		animal.caught.connect(_on_helper_caught)
		animal.killed.connect(func(animal_id: String) -> void: _announce("Killed a %s" % animal_id))
		$Wild.add_child(animal)
	_hunter.equip(items)
	_hunter.start_hunt()
	if items.get("item_trap_setter", 0) > 0:
		_set_traps_at_zones(zones)
		_hunter.bring_trap_setter()
	_hunter.interacted.connect(_on_interacted)
	_hunter.downed.connect(_on_downed)
	_hunter.shouted.connect(_on_shouted)
	_hunter.bait_placed.connect(_on_bait_placed)
	var minimap := $Hud/Minimap
	minimap.hunter = _hunter
	minimap.escape_zones = zones
	minimap.return_point = Vector2($ReturnPoint.position.x, $ReturnPoint.position.z)
	_show_goal()
	$Hud/Tip.visible = first_hunt


## First-hunt tips, one every TIP_SECONDS; the turkey re-checks its marks.
func _process(delta: float) -> void:
	_scout_left -= delta
	if _scouting and _scout_left <= 0.0:
		_scout_left = SCOUT_CHECK_SECONDS
		_scout()
	if not first_hunt:
		return
	_tip_left -= delta
	if _tip_left > 0.0:
		return
	_tip_left = TIP_SECONDS
	$Hud/Tip.text = TIPS[_tip] if _tip < TIPS.size() else ""
	_tip += 1


## Spawns size boars in a ring around centre; a group of two or more shares one herd array.
func _spawn_group(size: int, centre: Vector3, zones: Array[Vector2]) -> void:
	var herd: Array[Node3D] = []
	for i in size:
		var boar := BoarScene.instantiate()
		boar.boar_type = BoarTypes.pick(randf())
		boar.hunter = _hunter
		boar.escape_zones = zones
		boar.baits = _baits
		if size > 1:
			boar.herd = herd
			herd.append(boar)
		var ring := 1.2 * sqrt(size)
		boar.position = centre + Vector3(cos(TAU * i / size) * ring, 0.0, sin(TAU * i / size) * ring)
		boar.position.y = _terrain.height_at(boar.position.x, boar.position.z) + 0.5
		boar.outcome_reached.connect(_on_outcome)
		boar.held_changed.connect(_on_held_changed)
		$Boars.add_child(boar)


## Trap setter (M013): traps from stock go on the way into the first escape zones, towards the map centre.
func _set_traps_at_zones(zones: Array[Vector2]) -> void:
	for zone: Vector2 in zones.slice(0, SETTER_TRAPS):
		var spot := zone - zone.normalized() * SETTER_OFFSET
		var facing := Basis(Vector3.UP, atan2(zone.x, zone.y))
		if not _hunter.set_trap_for_hunter(Transform3D(facing, Vector3(spot.x, _terrain.height_at(spot.x, spot.y), spot.y))):
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_helper"):
		summon(_companion())


## The helper taken on this hunt: the one chosen in the pens, else the first one the pen has.
func _companion() -> String:
	if helpers.get(companion, 0) > 0:
		return companion
	for animal_id in [CompanionRules.ROOSTER, CompanionRules.TURKEY]:
		if helpers.get(animal_id, 0) > 0:
			return animal_id
	return ""


## Releases the helper taken from the camp pen (M016, M017), once per hunt: the rooster drives the
## nearest group at the hunter, the turkey keeps a herd, group or loner marked on the minimap.
func summon(animal_id: String) -> void:
	if helpers.get(animal_id, 0) == 0 or not _helpers_used.is_empty() or hunt.is_over():
		return
	_helpers_used.append(animal_id)
	if animal_id == CompanionRules.TURKEY:
		_scouting = true
		_scout()
	else:
		var hunter_pos := Vector2(_hunter.global_position.x, _hunter.global_position.z)
		var spots: Array[Vector2] = []
		for boar in $Boars.get_children():
			spots.append(Vector2(boar.global_position.x, boar.global_position.z))
		var centre := CompanionRules.target_group_centre(spots, hunter_pos, 10.0)
		var land := CompanionRules.drive_point(centre, hunter_pos)
		var rooster: Node3D = RoosterScene.instantiate()
		rooster.target = Vector3(land.x, _terrain.height_at(land.x, land.y) + 0.5, land.y)
		rooster.boars = $Boars.get_children()
		rooster.position = _hunter.position + Vector3.UP * 3.0
		add_child(rooster)
	_show_goal()


func _on_helper_caught(animal_id: String) -> void:
	hunt.helpers_caught[animal_id] = hunt.helpers_caught.get(animal_id, 0) + 1
	_announce("Caught a %s for the pen" % animal_id)
	_show_goal()


func _on_outcome(type_id: String, kind: int, wounded: bool) -> void:
	if hunt.is_over():
		return
	var tusks_before := hunt.tusks()
	hunt.record(type_id, kind, wounded)
	if hunt.tusks() > tusks_before:
		_hunter.show_gain("+%d tusks" % (hunt.tusks() - tusks_before))
	var type := BoarTypes.find(type_id)
	var verb: String = {BoarOutcome.Kind.DEAD: "killed", BoarOutcome.Kind.CAPTURED: "caught", BoarOutcome.Kind.ESCAPED: "escaped!"}[kind]
	if wounded and kind == BoarOutcome.Kind.CAPTURED:
		verb = "caught wounded (pays less)"
	_announce("%s %s" % [type.display_name if type else type_id, verb])
	_show_goal()
	if hunt.is_over():
		_end()


func _on_held_changed(held: bool) -> void:
	if hunt.is_over():
		return
	hunt.held += 1 if held else -1
	_show_goal()
	if hunt.is_over():
		_end()


func _on_interacted() -> void:
	# A wild rooster or turkey within reach is grabbed by hand (playtest 2026-10-27).
	for animal in $Wild.get_children():
		if animal.try_grab(_hunter.global_position):
			return
	if hunt.is_over() or _hunter.global_position.distance_to($ReturnPoint.global_position) > RETURN_RADIUS:
		return
	hunt.returned = true
	_end()


## Zero health: back to camp with what was caught, no defeat screen (section 10).
func _on_downed() -> void:
	if hunt.is_over():
		return
	hunt.returned = true
	_end()


func _end() -> void:
	hunt.used_items = _hunter.loadout.used.duplicate()
	var held_types := []
	for boar in $Boars.get_children():
		if boar.state_name() == "TRAPPED":
			held_types.append(boar.boar_type.id)
	hunt.close_traps(held_types)
	hunt_ended.emit(hunt)


func _on_shouted(at: Vector3) -> void:
	for boar in $Boars.get_children():
		if boar.global_position.distance_to(at) <= SHOUT_RADIUS:
			boar.hear_shout(at)
	# A wave shows the shout's reach, and the minimap points out where the saddled boar waits (owner, 2026-10-27).
	var wave: MeshInstance3D = ShoutWaveScene.instantiate()
	wave.radius = SHOUT_RADIUS
	wave.position = Vector3(at.x, at.y + 0.3, at.z)
	add_child(wave)
	$Hud/Minimap.show_mount(_hunter.mount_node())


func _on_bait_placed(bait: Node3D) -> void:
	# Drop eaten bait; boars skip freed entries in between.
	_baits.assign(_baits.filter(is_instance_valid))
	_baits.append(bait)


## Short HUD message for an outcome (M006 feedback), fading out.
func _announce(text: String) -> void:
	var label: Label = $Hud/Message
	label.text = text
	label.modulate.a = 1.0
	create_tween().tween_property(label, "modulate:a", 0.0, 2.5).set_delay(1.0)


## Keeps the turkey's group marked; when every marked boar is gone, caught or one of them runs,
## it picks the calm group nearest the hunter instead.
func _scout() -> void:
	var minimap := $Hud/Minimap
	var calm := 0
	var running := false
	for boar in minimap.marked:
		if is_instance_valid(boar) and boar.boar.is_free():
			if boar.state_name() == "WANDER":
				calm += 1
			else:
				running = true
	if calm > 0 and not running:
		return
	var best: Node3D = null
	for boar in $Boars.get_children():
		if boar.state_name() == "WANDER" and boar not in minimap.marked \
				and (best == null or boar.global_position.distance_to(_hunter.global_position) < best.global_position.distance_to(_hunter.global_position)):
			best = boar
	var group: Array[Node3D] = []
	if best:
		for mate in (best.herd if not best.herd.is_empty() else [best]):
			if is_instance_valid(mate) and mate.boar.is_free():
				group.append(mate)
	minimap.marked = group


## Tusks under the minimap; the helpers line sits above the trap slot (owner, 2026-10-28).
func _show_goal() -> void:
	_goal.text = "Tusks: %s" % Hunt.tusk_bracket(hunt.tusks())
	var lines := PackedStringArray()
	if items.get("item_trap_setter", 0) > 0:
		lines.append("Helper: trap setter")
	var animal_id := _companion()
	if animal_id != "" and _helpers_used.is_empty():
		lines.append("[Z] release %s" % animal_id)
	_hunter.show_helper("\n".join(lines))


## Boar counts for the pause menu (owner, 2026-10-28: stats on Esc, not on screen).
func stats_text() -> String:
	return "Boars left: %d\nIn traps: %d\nKilled: %d\nCaught: %d\nEscaped: %d" % [
		hunt.remaining(),
		hunt.held,
		hunt.count_all(BoarOutcome.Kind.DEAD),
		hunt.count_all(BoarOutcome.Kind.CAPTURED),
		hunt.count_all(BoarOutcome.Kind.ESCAPED),
	]
