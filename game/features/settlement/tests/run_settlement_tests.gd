extends SceneTree

const Progress = preload("res://game/features/settlement/public/progress.gd")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_hunt_adds_tusks_and_catches(), "a hunt adds tusks and live catches and spends bait")
	failures += _check(_spend_needs_enough_tusks(), "spending needs enough tusks")
	failures += _check(_round_trip(), "progress survives to_dict/from_dict")
	failures += _check(_bad_data_falls_back(), "malformed save data falls back to defaults")
	failures += _check(_buy_weapon_once(), "a weapon is bought once for its price")
	failures += _check(_saddle_needs_caught_boar(), "a saddle needs a caught boar of its type")
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
	hunt.used_items = {"item_acorns": 1}
	hunt.helpers_caught = {"rooster": 1}
	var progress := Progress.new()
	progress.items = {"item_acorns": 3}
	progress.add_hunt(hunt)
	return progress.tusks == 22 and progress.hunts == 1 and progress.caught == {"golden_tusk": 1} and progress.items["item_acorns"] == 2 \
		and progress.helpers == {"rooster": 1}


func _spend_needs_enough_tusks() -> bool:
	var progress := Progress.new()
	progress.tusks = 10
	return not progress.spend(11) and progress.spend(10) and progress.tusks == 0


func _round_trip() -> bool:
	var progress := Progress.new()
	progress.tusks = 7
	progress.caught = {"common_brown": 2}
	progress.items = {"item_bow": 1}
	var back := Progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	return back.tusks == 7 and back.caught == {"common_brown": 2} and back.owns("item_bow")


func _bad_data_falls_back() -> bool:
	var back := Progress.from_dict({"tusks": -5, "caught": "oops"})
	return back.tusks == 0 and back.caught.is_empty()


func _buy_weapon_once() -> bool:
	var progress := Progress.new()
	progress.tusks = 60
	var bought := progress.buy("item_sling")
	var twice := progress.buy("item_sling")
	var too_expensive := progress.buy("item_bow")
	return bought and not twice and not too_expensive and progress.tusks == 35 \
		and progress.owns("item_sling") and not progress.buy("item_unknown")


func _saddle_needs_caught_boar() -> bool:
	var progress := Progress.new()
	progress.tusks = 100
	var locked := not progress.buy("item_saddle_runner_grey")
	progress.caught = {"runner_grey": 1}
	return locked and progress.tusks == 100 and progress.buy("item_saddle_runner_grey") and progress.tusks == 50
