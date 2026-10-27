extends SceneTree

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_hit_on_flee_panics(), "hit on flee boar panics")
	failures += _check(_net_captures_free_boar(), "net captures free boar")
	failures += _check(_captured_ignores_hits_and_escape(), "captured boar ignores hit and escape")
	failures += _check(_zero_health_is_dead(), "zero health is dead")
	failures += _check(_escape_only_when_fleeing(), "escape only when fleeing")
	failures += _check(_trap_held_counts_as_captured(), "trap held to hunt end counts as captured")
	failures += _check(_only_panic_turns_to_charge(), "only a panicking boar charges, then flees")
	failures += _check(_hit_scares_attacker_but_not_rammer(), "hit scares an attacking boar off, a ramming one keeps charging")
	failures += _check(_types_pick_by_weight(), "five types, rarer types need higher rolls")
	failures += _check(_trapped_boar_stays_until_freed(), "trapped boar stays when hurt, can be netted or break free")
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


func _only_panic_turns_to_charge() -> bool:
	var calm := Boar.new("runner", 3)
	calm.charge()
	var boar := Boar.new("runner", 3)
	boar.take_hit(1)
	boar.charge()
	var charging := boar.state == Boar.State.CHARGE and boar.is_free()
	boar.escape()
	var stays := boar.state == Boar.State.CHARGE
	boar.end_charge()
	return calm.state == Boar.State.WANDER and charging and stays and boar.state == Boar.State.FLEE


func _hit_scares_attacker_but_not_rammer() -> bool:
	var attacker := Boar.new("runner", 5)
	attacker.take_hit(1)
	attacker.charge()
	attacker.take_hit(1)
	var rammer := Boar.new("runner", 5)
	rammer.take_hit(1)
	rammer.charge()
	rammer.ramming = true
	rammer.take_hit(1)
	var whole := Boar.new("runner", 5)
	return attacker.state == Boar.State.FLEE and rammer.state == Boar.State.CHARGE \
			and rammer.is_wounded() and not whole.is_wounded()


func _types_pick_by_weight() -> bool:
	var ids := BoarTypes.ALL.map(func(type: Resource) -> String: return type.id)
	return ids == ["common_brown", "runner_grey", "aggressive_red", "armored_black", "golden_tusk"] \
		and BoarTypes.pick(0.0).id == "common_brown" \
		and BoarTypes.pick(0.999).id == "golden_tusk" \
		and BoarTypes.rewards()["golden_tusk"] == {"dead": 10, "captured": 20, "wounded": 15}


func _trapped_boar_stays_until_freed() -> bool:
	var boar := Boar.new("runner", 3)
	boar.trap()
	boar.take_hit(1)
	var held := boar.state == Boar.State.TRAPPED and not boar.is_free()
	boar.break_free()
	var loose := boar.state == Boar.State.PANIC
	boar.trap()
	boar.net_capture()
	return held and loose and boar.state == Boar.State.CAPTURED
