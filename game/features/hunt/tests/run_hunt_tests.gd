extends SceneTree

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_results_and_tusks(), "results count per type and tusks follow rewards")
	failures += _check(_empty_hunt_pays_nothing(), "empty hunt has no results and no tusks")
	failures += _check(_ends_when_no_boars_left(), "hunt ends when every boar is resolved")
	failures += _check(_ends_on_return(), "hunt ends when the hunter returns early")
	failures += _check(_trapped_boars_end_hunt_and_count(), "trapped boars end the hunt and count as captured")
	print("hunt tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


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
