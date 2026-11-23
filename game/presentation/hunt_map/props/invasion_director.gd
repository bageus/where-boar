extends Node3D

## Terminator invasion on the hunt map (issue 8): the sky turns blood red at dusk (still bright enough to see),
## every free boar runs off the map, and terminators land around the hunter in teleport eggs.
## Terminators are children of this node, kept out of $Boars (the cyborg body is its own thread's work).

const TeleportEgg = preload("res://game/presentation/hunt_map/props/teleport_egg.gd")
const CYBORG_PATH := "res://game/features/boar/public/cyborg_body.tscn"
const VARIANTS := ["cannon", "machinegun"]

## A terminator left the hunt; killed ones drop loot.
signal terminator_gone(killed: bool)

const DUSK_SECONDS := 4.0
## Eggs land one after another, this many seconds apart, this far from the hunter (ASSUMPTION).
const EGG_GAP := 0.4
const LAND_NEAR := 18.0
const LAND_FAR := 35.0
## Keeps eggs inside the map, whose escape zones sit about 80 m out.
const MAP_HALF := 72.0
## shortcut: boars still on the map after this long jump to their exit once this far from the hunter; upgrade if one is seen popping.
const LEAVE_SECONDS := 25.0
const VANISH_DISTANCE := 30.0

var hunter: Node3D
var terrain: Node3D
var boars: Node
var world: WorldEnvironment
var sun: DirectionalLight3D
var _leave_left := 0.0


## The cyborg body may not be in the build yet; then no invasion can start.
static func available() -> bool:
	return ResourceLoader.exists(CYBORG_PATH)


func start(count: int) -> void:
	_dusk()
	for boar in boars.get_children():
		boar.leave()
	_leave_left = LEAVE_SECONDS
	for n in count:
		var egg := TeleportEgg.new()
		var at := _landing()
		egg.position = Vector3(at.x, terrain.height_at(at.x, at.y) + TeleportEgg.RADIUS * 0.6, at.y)
		egg.opened.connect(_spawn.bind(egg.position, VARIANTS[n % VARIANTS.size()]))
		get_tree().create_timer(n * EGG_GAP, false).timeout.connect(add_child.bind(egg))
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_leave_left -= delta
	if _leave_left > 0.0:
		return
	for boar in boars.get_children():
		if boar.boar.is_free() and boar.global_position.distance_to(hunter.global_position) > VANISH_DISTANCE \
				and not boar.escape_zones.is_empty():
			# Put it on its nearest exit: the body escapes there on its next tick and reports it.
			var pos := Vector2(boar.global_position.x, boar.global_position.z)
			var exit: Vector2 = boar.escape_zones.reduce(func(a: Vector2, b: Vector2) -> Vector2:
				return a if a.distance_to(pos) < b.distance_to(pos) else b)
			boar.leave()
			boar.global_position = Vector3(exit.x, terrain.height_at(exit.x, exit.y) + 0.5, exit.y)


func _landing() -> Vector2:
	var around := Vector2(hunter.global_position.x, hunter.global_position.z) \
			+ Vector2.from_angle(randf() * TAU) * randf_range(LAND_NEAR, LAND_FAR)
	return around.clamp(Vector2.ONE * -MAP_HALF, Vector2.ONE * MAP_HALF)


func _spawn(at: Vector3, variant: String) -> void:
	var cyborg: Node3D = load(CYBORG_PATH).instantiate()
	cyborg.variant = variant
	cyborg.hunter = hunter
	cyborg.position = at
	cyborg.outcome_reached.connect(func(_type_id: String, kind: int, _wounded: bool) -> void:
		terminator_gone.emit(kind == BoarOutcome.Kind.DEAD))
	add_child(cyborg)


## Red dusk: the sky, sun and shade turn red over DUSK_SECONDS; the map's environment is copied first
## because the scene's resources are shared with the next hunt.
func _dusk() -> void:
	world.environment = world.environment.duplicate(true)
	var environment := world.environment
	var sky := environment.sky.sky_material as ProceduralSkyMaterial
	var tween := create_tween().set_parallel()
	tween.tween_property(sky, "sky_top_color", Color(0.55, 0.02, 0.01), DUSK_SECONDS)
	tween.tween_property(sky, "sky_horizon_color", Color(1.0, 0.16, 0.05), DUSK_SECONDS)
	tween.tween_property(sky, "ground_horizon_color", Color(1.0, 0.16, 0.05), DUSK_SECONDS)
	tween.tween_property(sun, "light_color", Color(1.0, 0.32, 0.2), DUSK_SECONDS)
	tween.tween_property(sun, "light_energy", 0.8, DUSK_SECONDS)
	tween.tween_property(environment, "ambient_light_color", Color(0.85, 0.35, 0.3), DUSK_SECONDS)
	# A thin red haze reddens the far trees and hills too (owner, 2026-11-22: redder).
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.9, 0.12, 0.05)
	environment.fog_sky_affect = 0.0
	environment.fog_density = 0.0
	tween.tween_property(environment, "fog_density", 0.0025, DUSK_SECONDS)
