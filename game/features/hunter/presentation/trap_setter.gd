extends Node3D

## The hired trap setter (M013, owner 2026-10-28): follows the hunter and walks to every trap ghost to build it.

const BuildSite = preload("res://game/features/hunter/presentation/traps/build_site.gd")

const SPEED := 3.5
const BUILD_REACH := 1.5
## Distance kept from the hunter while there is nothing to build.
const FOLLOW_DISTANCE := 3.0

var hunter: CharacterBody3D


func _ready() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	body.mesh = capsule
	body.position.y = 0.8
	add_child(body)
	var tag := Label3D.new()
	tag.text = "Trap setter"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 32
	tag.outline_size = 8
	tag.position.y = 2.0
	add_child(tag)


# shortcut: walks straight over the ground with no collision or pathing, so it can pass through rocks;
# give it a NavigationAgent3D if playtest shows it.
func _physics_process(delta: float) -> void:
	var site := _nearest_ghost()
	var goal := site.global_position if site else hunter.global_position
	var stop := BUILD_REACH if site else FOLLOW_DISTANCE
	var to_goal := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	if to_goal.length() > stop:
		var step := to_goal.normalized() * minf(SPEED * delta, to_goal.length() - stop)
		global_position = hunter.ground_at(global_position + step)
		look_at(global_position + to_goal, Vector3.UP)
	elif site:
		BuildSite.build(site, delta)


func _nearest_ghost() -> Node3D:
	var best: Node3D = null
	for trap: Node3D in get_tree().get_nodes_in_group(hunter.PLACED_TRAPS_GROUP):
		if BuildSite.is_ghost(trap) and (best == null \
				or trap.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = trap
	return best
