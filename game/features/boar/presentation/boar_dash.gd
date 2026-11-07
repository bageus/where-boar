extends RefCounted

## A charging boar (playtest 2026-10-27): runs at the hunter; once close it locks its line and dashes through him.

const DASH_DISTANCE := 4.0
const DASH_SECONDS := 1.0
const HIT_DISTANCE := 1.3

var _heading := Vector2.ZERO
var _left := 0.0
var _hit := false


## Heading for this frame; the dash over, it ends the charge (body.boar leaves CHARGE).
func heading(body: CharacterBody3D, delta: float, pos: Vector2, hunter_pos: Vector2, impulse: float, damage: int) -> Vector2:
	var hunter: Node3D = body.hunter
	if not body.boar.ramming:
		var at := (hunter_pos - pos).normalized()
		if pos.distance_to(hunter_pos) <= DASH_DISTANCE:
			body.boar.ramming = true
			body.get_node("Model").attack()
			body.get_node("Sounds").attack()
			_heading = at
			_left = DASH_SECONDS
			_hit = false
			body.add_collision_exception_with(hunter)
		return at
	if not _hit and body.global_position.distance_to(hunter.global_position) <= HIT_DISTANCE:
		_hit = true
		hunter.knock(Vector3(_heading.x, 0.0, _heading.y) * impulse + Vector3.UP * 3.0, damage, body.boar_type)
	_left -= delta
	if _left <= 0.0:
		body.remove_collision_exception_with(hunter)
		body.boar.end_charge()
	return _heading
