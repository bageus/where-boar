class_name Boar
extends RefCounted

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")

enum State { WANDER, FLEE, PANIC, CHARGE, TRAPPED, CAPTURED, DEAD, ESCAPED }

var type_id: String
var health: int
var state: State = State.WANDER


func _init(p_type_id: String, p_health: int) -> void:
	type_id = p_type_id
	health = p_health


func is_free() -> bool:
	return state in [State.WANDER, State.FLEE, State.PANIC, State.CHARGE]


func flee() -> void:
	if state == State.WANDER:
		state = State.FLEE


func take_hit(damage: int) -> void:
	if state in [State.CAPTURED, State.DEAD, State.ESCAPED]:
		return
	health = max(0, health - damage)
	state = State.DEAD if health == 0 else State.PANIC


func net_capture() -> void:
	if is_free():
		state = State.CAPTURED


func trap() -> void:
	if is_free():
		state = State.TRAPPED


func escape() -> void:
	if state in [State.FLEE, State.PANIC]:
		state = State.ESCAPED


func outcome_kind() -> BoarOutcome.Kind:
	match state:
		State.DEAD:
			return BoarOutcome.Kind.DEAD
		State.CAPTURED, State.TRAPPED:
			# A trap that is still holding the boar at hunt end counts as captured.
			return BoarOutcome.Kind.CAPTURED
		State.ESCAPED:
			return BoarOutcome.Kind.ESCAPED
	return BoarOutcome.Kind.NONE
