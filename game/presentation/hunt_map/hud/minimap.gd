extends Control

## Top-down minimap (D011): escape zones, the return point and the hunter.
## Placed traps show as blue squares (owner, 2026-10-27).
## Boars appear only while a turkey scout has marked them (M017).

## Half the map's side in metres; the map is centred on the origin.
const MAP_HALF_SIZE := 80.0
const ZONE_RADIUS := 3.0
## Same name as the hunter's PLACED_TRAPS_GROUP; the map may not depend on the hunter's internals.
const TRAPS_GROUP := "placed_traps"

var hunter: Node3D
var escape_zones: Array[Vector2] = []
var return_point := Vector2.ZERO
## Parent of the boar nodes, and seconds the turkey's marks still show.
var boars: Node
var reveal_left := 0.0


func _process(delta: float) -> void:
	reveal_left -= delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.2, 0.1, 0.7))
	var scale_px := size.x / (2.0 * MAP_HALF_SIZE)
	for zone in escape_zones:
		draw_circle(_to_px(zone), maxf(ZONE_RADIUS * scale_px, 4.0), Color(0.9, 0.2, 0.15))
	draw_circle(_to_px(return_point), maxf(ZONE_RADIUS * scale_px, 4.0), Color(0.2, 0.8, 0.3))
	for trap: Node3D in get_tree().get_nodes_in_group(TRAPS_GROUP):
		var spot := _to_px(Vector2(trap.global_position.x, trap.global_position.z))
		draw_rect(Rect2(spot - Vector2(3, 3), Vector2(6, 6)), Color(0.55, 0.85, 1.0))
	if boars and reveal_left > 0.0:
		for boar: Node3D in boars.get_children():
			draw_circle(_to_px(Vector2(boar.global_position.x, boar.global_position.z)), 3.0, Color(1, 0.85, 0.3))
	if hunter:
		var at := _to_px(Vector2(hunter.global_position.x, hunter.global_position.z))
		var forward := Vector2(-hunter.global_basis.z.x, -hunter.global_basis.z.z).normalized()
		draw_colored_polygon(PackedVector2Array([
			at + forward * 7.0, at + forward.orthogonal() * 4.0, at - forward.orthogonal() * 4.0,
		]), Color.WHITE)


func _to_px(world: Vector2) -> Vector2:
	return (world / (2.0 * MAP_HALF_SIZE) + Vector2(0.5, 0.5)) * size
