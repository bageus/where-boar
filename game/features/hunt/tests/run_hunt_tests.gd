extends SceneTree

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const Hunt = preload("res://game/features/hunt/domain/hunt.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_results_and_tusks(), "results count per type and tusks follow rewards")
	failures += _check(_empty_hunt_pays_nothing(), "empty hunt has no results and no tusks")
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
