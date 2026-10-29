extends Node3D

## The hired helper (M013, owner 2026-10-29): the tavern's tribesman follows the hunter, walking or
## running to keep up, and at every trap ghost crouches and hammers the ground until it is built.
## Boars sense only the hunter, so they never notice him.

const BuildSite = preload("res://game/features/hunter/presentation/traps/build_site.gd")
const Helper = preload("res://assets/models/caveman_helper.glb")

const WALK_SPEED := 3.5
const RUN_SPEED := 7.5  # a little over the hunter's sprint so he catches up
## Farther than this from where he is going, he runs.
const RUN_DISTANCE := 6.0
const BUILD_REACH := 1.0
## Distance kept from the hunter while there is nothing to build.
const FOLLOW_DISTANCE := 3.0

var hunter: CharacterBody3D

var _player: AnimationPlayer


func _ready() -> void:
	var body: Node3D = Helper.instantiate()
	body.rotation.y = PI  # the model faces +z, look_at points -z at the goal
	add_child(body)
	_player = body.find_child("AnimationPlayer") as AnimationPlayer
	_player.animation_finished.connect(func(anim: StringName) -> void: _player.play(anim))


# shortcut: walks straight over the ground with no collision or pathing, so it can pass through rocks;
# give it a NavigationAgent3D if playtest shows it.
func _physics_process(delta: float) -> void:
	var site := _nearest_ghost()
	var goal := site.global_position if site else hunter.global_position
	var stop := BUILD_REACH if site else FOLLOW_DISTANCE
	var to_goal := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var anim := "idle"
	if to_goal.length() > stop:
		var running := to_goal.length() > RUN_DISTANCE
		var speed := RUN_SPEED if running else WALK_SPEED
		var step := to_goal.normalized() * minf(speed * delta, to_goal.length() - stop)
		global_position = hunter.ground_at(global_position + step)
		look_at(global_position + to_goal, Vector3.UP)
		anim = "run" if running else "walk"
	elif site:
		if to_goal.length() > 0.1:
			look_at(global_position + to_goal, Vector3.UP)
		BuildSite.build(site, delta)
		anim = "hammer"
	if _player.current_animation != anim:
		_player.play(anim, 0.2)


func _nearest_ghost() -> Node3D:
	var best: Node3D = null
	for trap: Node3D in get_tree().get_nodes_in_group(hunter.PLACED_TRAPS_GROUP):
		if BuildSite.is_ghost(trap) and (best == null \
				or trap.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = trap
	return best
