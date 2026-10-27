extends SceneTree

const Progress = preload("res://game/features/settlement/public/progress.gd")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_hunt_adds_tusks_and_catches(), "a hunt adds tusks and live catches")
	failures += _check(_spend_needs_enough_tusks(), "spending needs enough tusks")
	failures += _check(_round_trip(), "progress survives to_dict/from_dict")
	failures += _check(_bad_data_falls_back(), "malformed save data falls back to defaults")
	print("settlement tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _hunt_adds_tusks_and_catches() -> bool:
	var hunt := Hunt.new(3)
	hunt.record("common_brown", BoarOutcome.Kind.DEAD)
	hunt.record("golden_tusk", BoarOutcome.Kind.CAPTURED)
	hunt.record("runner_grey", BoarOutcome.Kind.ESCAPED)
	var progress := Progress.new()
	progress.add_hunt(hunt)
	return progress.tusks == 22 and progress.caught == {"golden_tusk": 1}


func _spend_needs_enough_tusks() -> bool:
	var progress := Progress.new()
	progress.tusks = 10
	return not progress.spend(11) and progress.spend(10) and progress.tusks == 0


func _round_trip() -> bool:
	var progress := Progress.new()
	progress.tusks = 7
	progress.caught = {"common_brown": 2}
	var back := Progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	return back.tusks == 7 and back.caught == {"common_brown": 2}


func _bad_data_falls_back() -> bool:
	var back := Progress.from_dict({"tusks": -5, "caught": "oops"})
	return back.tusks == 0 and back.caught.is_empty()
