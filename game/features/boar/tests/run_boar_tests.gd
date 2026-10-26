extends SceneTree

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_hit_on_flee_panics(), "hit on flee boar panics")
	failures += _check(_net_captures_free_boar(), "net captures free boar")
	failures += _check(_captured_ignores_hits_and_escape(), "captured boar ignores hit and escape")
	failures += _check(_zero_health_is_dead(), "zero health is dead")
	failures += _check(_escape_only_when_fleeing(), "escape only when fleeing")
	failures += _check(_trap_held_counts_as_captured(), "trap held to hunt end counts as captured")
	print("boar tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _hit_on_flee_panics() -> bool:
	var boar := Boar.new("runner", 5)
	boar.flee()
	boar.take_hit(1)
	return boar.state == Boar.State.PANIC and boar.health == 4


func _net_captures_free_boar() -> bool:
	var boar := Boar.new("runner", 5)
	boar.flee()
	boar.net_capture()
	return boar.state == Boar.State.CAPTURED and boar.outcome_kind() == BoarOutcome.Kind.CAPTURED


func _captured_ignores_hits_and_escape() -> bool:
	var boar := Boar.new("runner", 5)
	boar.flee()
	boar.net_capture()
	boar.take_hit(9)
	boar.escape()
	return boar.state == Boar.State.CAPTURED and boar.health == 5


func _zero_health_is_dead() -> bool:
	var boar := Boar.new("runner", 2)
	boar.take_hit(2)
	return boar.state == Boar.State.DEAD and boar.outcome_kind() == BoarOutcome.Kind.DEAD


func _escape_only_when_fleeing() -> bool:
	var calm := Boar.new("runner", 5)
	calm.escape()
	var fleeing := Boar.new("runner", 5)
	fleeing.flee()
	fleeing.escape()
	return calm.state == Boar.State.WANDER and fleeing.state == Boar.State.ESCAPED


func _trap_held_counts_as_captured() -> bool:
	var boar := Boar.new("armored", 9)
	boar.trap()
	return boar.state == Boar.State.TRAPPED and boar.outcome_kind() == BoarOutcome.Kind.CAPTURED
