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


## A trapped boar stays in the trap when hurt, unless the hit kills it.
func take_hit(damage: int) -> void:
	if state in [State.CAPTURED, State.DEAD, State.ESCAPED]:
		return
	health = max(0, health - damage)
	if health == 0:
		state = State.DEAD
	elif state != State.TRAPPED:
		state = State.PANIC


## After an attack a panicking boar may turn and ram the hunter (D018).
func charge() -> void:
	if state == State.PANIC:
		state = State.CHARGE


## The charge is over (rammed or gave up): the boar runs off again.
func end_charge() -> void:
	if state == State.CHARGE:
		state = State.FLEE


## A net or a closing cage captures a free or trapped boar (M004, D023).
func net_capture() -> void:
	if is_free() or state == State.TRAPPED:
		state = State.CAPTURED


func trap() -> void:
	if is_free():
		state = State.TRAPPED


## A big boar tore out of a snare (D023) and runs.
func break_free() -> void:
	if state == State.TRAPPED:
		state = State.PANIC


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
