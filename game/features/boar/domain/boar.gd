class_name Boar
extends RefCounted

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")

enum State { WANDER, FLEE, PANIC, CHARGE, TRAPPED, CAPTURED, DEAD, ESCAPED }

var type_id: String
var health: int
var state: State = State.WANDER
## True during the last dash of a charge: the boar runs through the hunter and hits do not stop it.
var ramming := false
var _max_health: int


func _init(p_type_id: String, p_health: int) -> void:
	type_id = p_type_id
	health = p_health
	_max_health = p_health


func is_free() -> bool:
	return state in [State.WANDER, State.FLEE, State.PANIC, State.CHARGE]


func flee() -> void:
	if state == State.WANDER:
		state = State.FLEE


## A trapped boar stays in the trap when hurt, unless the hit kills it.
## A hit scares an attacking boar off (FLEE); a ramming one keeps running (playtest 2026-10-27).
func take_hit(damage: int) -> void:
	if state in [State.CAPTURED, State.DEAD, State.ESCAPED]:
		return
	health = max(0, health - damage)
	if health == 0:
		state = State.DEAD
		ramming = false
	elif state == State.CHARGE:
		if not ramming:
			state = State.FLEE
	elif state != State.TRAPPED:
		state = State.PANIC


## Hurt but alive; a wounded boar caught alive pays less than a whole one.
func is_wounded() -> bool:
	return health < _max_health


## After an attack a panicking boar may turn and ram the hunter (D018).
func charge() -> void:
	if state == State.PANIC:
		state = State.CHARGE


## The charge is over (rammed or gave up): the boar runs off again.
func end_charge() -> void:
	if state == State.CHARGE:
		state = State.FLEE
	ramming = false


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


## An alarmed calm boar goes straight for the hunter (aggressive types, playtest 2026-10-27).
func attack() -> void:
	if state in [State.WANDER, State.FLEE]:
		state = State.CHARGE


## The flight is over: a fleeing or panicking boar calms down and roams again.
func calm() -> void:
	if state in [State.FLEE, State.PANIC]:
		state = State.WANDER


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
