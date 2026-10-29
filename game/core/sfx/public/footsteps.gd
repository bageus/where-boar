extends Node3D

## Footsteps of whoever this node is a child of (owner, 2026-10-29): one take every stride metres walked,
## from the water group in a river, the grass group on grass, the ground group elsewhere.
## With bush set, also a rustle on stepping into or out of a bush or tall grass.

const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## Physics layer 5: bushes and tall grass (cover), see boar_body.gd.
const COVER_LAYER := 1 << 4
## Physics layer 7: river water areas (river_segment.tscn).
const WATER_LAYER := 1 << 6

@export var ground := "character_step"
## "" uses ground on grass too.
@export var grass := ""
@export var water := "river_steps"
@export var bush := ""
@export var stride := 2.0
@export var volume_db := 0.0
@export var max_distance := 25.0

## Set by the owner: false in the air or in the saddle, or a boar that only walks (then only water is heard).
var active := true
## Added to volume_db, e.g. quieter while sneaking.
var quiet_db := 0.0

var _last := Vector3.INF
var _travel := 0.0
var _in_bush := false


func _physics_process(_delta: float) -> void:
	var pos := global_position
	var moved := Vector2(pos.x - _last.x, pos.z - _last.z).length()
	_last = pos
	if bush != "" and _in_cover(pos) != _in_bush:
		_in_bush = not _in_bush
		Sfx.play(self, bush, volume_db + quiet_db, max_distance)
	if moved > 1.0:  # spawned or teleported
		return
	_travel += moved
	if _travel < stride:
		return
	_travel = 0.0
	var group := _surface(pos)
	if group != "":
		Sfx.play(self, group, volume_db + quiet_db, max_distance)


func _surface(pos: Vector3) -> String:
	var space := get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.position = pos + Vector3.UP * 0.3
	query.collision_mask = WATER_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	if not space.intersect_point(query, 1).is_empty():
		return water
	if not active:
		return ""
	if grass != "":
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 1.0, 1))
		if hit and hit.collider.has_method("grassy_at") and hit.collider.grassy_at(pos.x, pos.z):
			return grass
	return ground


func _in_cover(pos: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = pos + Vector3.UP * 0.5
	query.collision_mask = COVER_LAYER
	return not get_world_3d().direct_space_state.intersect_point(query, 1).is_empty()
