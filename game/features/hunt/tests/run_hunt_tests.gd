extends SceneTree

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const Invasion = preload("res://game/features/hunt/public/invasion.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_results_and_tusks(), "results count per type and tusks follow rewards")
	failures += _check(_wounded_capture_pays_less(), "wounded captured boar counts as caught, pays between dead and whole")
	failures += _check(Hunt.tusk_bracket(0) == "< 10" and Hunt.tusk_bracket(10) == "< 20" and Hunt.tusk_bracket(499) == "< 500" \
			and Hunt.tusk_bracket(1000) == "1000+", "tusks show as rough brackets")
	failures += _check(_empty_hunt_pays_nothing(), "empty hunt has no results and no tusks")
	failures += _check(_ends_when_no_boars_left(), "hunt ends when every boar is resolved")
	failures += _check(_ends_on_return(), "hunt ends when the hunter returns early")
	failures += _check(_trapped_boars_end_hunt_and_count(), "trapped boars end the hunt and count as captured")
	failures += _check(_no_terminators_before_eleventh_hunt(), "no terminators before the 11th hunt")
	failures += _check(_leader_kill_or_kill_target_calls_them(), "killing the leader or 30-40 boars calls the terminators once")
	failures += _check(_caught_leader_calls_them_off(), "catching the leader alive calls the terminators off")
	failures += _check(_invasion_sizes(), "2-30 terminators, more as hunts go on")
	failures += _check(_hunt_waits_for_terminators(), "hunt goes on until the terminators are gone; kills drop metal")
	failures += _check(_pockets_have_limits(), "forest finds fill the pockets up to their limit; unknown finds are refused")
	print("hunt tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _pockets_have_limits() -> bool:
	var hunt := Hunt.new()
	var taken := 0
	for i in 6:
		taken += 1 if hunt.gather("larva") else 0
	return taken == 4 and hunt.gathered == {"larva": 4} and not hunt.gather("pebble")


func _results_and_tusks() -> bool:
	var hunt := Hunt.new()
	hunt.record("runner", BoarOutcome.Kind.DEAD)
	hunt.record("runner", BoarOutcome.Kind.CAPTURED)
	hunt.record("runner", BoarOutcome.Kind.ESCAPED)
	var rewards := {"runner": {"dead": 2, "captured": 5}}
	return hunt.count("runner", BoarOutcome.Kind.DEAD) == 1 \
		and hunt.count("runner", BoarOutcome.Kind.CAPTURED) == 1 \
		and hunt.count("runner", BoarOutcome.Kind.ESCAPED) == 1 \
		and hunt.tusks(rewards) == 7


func _wounded_capture_pays_less() -> bool:
	var hunt := Hunt.new()
	hunt.record("runner", BoarOutcome.Kind.CAPTURED, true)
	hunt.record("runner", BoarOutcome.Kind.CAPTURED)
	var rewards := {"runner": {"dead": 2, "captured": 6, "wounded": 4}}
	return hunt.count("runner", BoarOutcome.Kind.CAPTURED) == 2 and hunt.tusks(rewards) == 10


func _empty_hunt_pays_nothing() -> bool:
	var hunt := Hunt.new()
	hunt.record("runner", BoarOutcome.Kind.NONE)
	return hunt.tusks({"runner": {"dead": 2, "captured": 5}}) == 0


func _ends_when_no_boars_left() -> bool:
	var hunt := Hunt.new(2)
	hunt.record("common_brown", BoarOutcome.Kind.DEAD)
	var open := not hunt.is_over() and hunt.remaining() == 1
	hunt.record("golden_tusk", BoarOutcome.Kind.CAPTURED)
	return open and hunt.is_over() and hunt.tusks() == 2 + 20 \
		and hunt.count_all(BoarOutcome.Kind.DEAD) == 1


func _ends_on_return() -> bool:
	var hunt := Hunt.new(3)
	hunt.returned = true
	return hunt.is_over() and hunt.tusks() == 0


func _trapped_boars_end_hunt_and_count() -> bool:
	var hunt := Hunt.new(2)
	hunt.record("common_brown", BoarOutcome.Kind.DEAD)
	hunt.held += 1
	var over := hunt.is_over()
	hunt.close_traps(["armored_black"])
	return over and hunt.held == 0 and hunt.count("armored_black", BoarOutcome.Kind.CAPTURED) == 1 \
		and hunt.tusks() == 2 + 14


func _no_terminators_before_eleventh_hunt() -> bool:
	var invasion := Invasion.new(9, 0.0, 0.0)
	return not invasion.allowed and not invasion.record_boar(true, false, true) and invasion.size == 0


func _leader_kill_or_kill_target_calls_them() -> bool:
	var by_leader := Invasion.new(10, 0.0, 0.0)
	var leader_ok := by_leader.record_boar(true, false, true) and by_leader.left == by_leader.size \
			and not by_leader.record_boar(true, false, false)
	var by_kills := Invasion.new(10, 0.999, 0.0)
	var calls := 0
	for n in 40:
		calls += 1 if by_kills.record_boar(true, false, false) else 0
	var captures := Invasion.new(10, 0.0, 0.0)
	for n in 50:
		captures.record_boar(false, true, false)
	return leader_ok and by_kills.kill_target == 40 and calls == 1 and Invasion.new(10, 0.0, 0.0).kill_target == 30 \
			and not captures.started


func _caught_leader_calls_them_off() -> bool:
	var invasion := Invasion.new(20, 0.0, 0.0)
	invasion.record_boar(false, true, true)
	for n in 40:
		invasion.record_boar(true, false, false)
	return not invasion.started


func _invasion_sizes() -> bool:
	return Invasion.new(10, 0.0, 0.0).size == 2 and Invasion.new(10, 0.0, 0.999).size == 4 \
			and Invasion.new(100, 0.0, 0.999).size == 30 and Invasion.new(100, 0.0, 0.0).size == 2


func _hunt_waits_for_terminators() -> bool:
	var hunt := Hunt.new(1)
	hunt.invasion = Invasion.new(10, 0.0, 0.0)
	var started := hunt.record("runner", BoarOutcome.Kind.DEAD, false, true)
	var waits := started and not hunt.is_over()
	hunt.invasion.record_terminator(true)
	hunt.invasion.record_terminator(false)
	return waits and hunt.is_over() and hunt.invasion.loot.get("item_metal_plate", 0) == Invasion.LOOT["item_metal_plate"]
