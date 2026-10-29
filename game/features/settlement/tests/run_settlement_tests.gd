extends SceneTree

const Progress = preload("res://game/features/settlement/public/progress.gd")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")


func _init() -> void:
	ShopCatalog.free_for_testing = false
	var failures := 0
	failures += _check(_free_for_testing_costs_nothing(), "while testing, items are free and saddles unlocked")
	failures += _check(_hunt_adds_tusks_and_catches(), "a hunt adds tusks and live catches and spends bait")
	failures += _check(_spend_needs_enough_tusks(), "spending needs enough tusks")
	failures += _check(_round_trip(), "progress survives to_dict/from_dict")
	failures += _check(_bad_data_falls_back(), "malformed save data falls back to defaults")
	failures += _check(_buy_weapon_once(), "a weapon is bought once for its price")
	failures += _check(_pick_helper_from_pen(), "a helper in the pen can be taken on the hunt, one at a time")
	failures += _check(_extra_spears_stop_at_two(), "spears stack to three, arrows come in packs, new games get the starter kit once")
	failures += _check(_saddle_needs_caught_boar(), "a saddle needs a caught boar of its type")
	failures += _check(_pen_holds_five_newest(), "the camp pen keeps the five newest caught boars, oldest out first")
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


func _pen_holds_five_newest() -> bool:
	var hunt := Hunt.new(3)
	for id in ["bone", "bone", "bun", "camo", "tiny", "golden_tusk"]:
		hunt.record(id, BoarOutcome.Kind.CAPTURED)
	var progress := Progress.new()
	progress.add_hunt(hunt)
	var back := Progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	var old := Progress.from_dict({"caught": {"bun": 7}})
	return progress.pen.size() == 5 and back.pen == progress.pen and old.pen.size() == 5 and progress.pen[-1] == "golden_tusk" \
		and progress.pen[0] != "" and progress.pen.count("bone") == 1


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


func _free_for_testing_costs_nothing() -> bool:
	ShopCatalog.free_for_testing = true
	var progress := Progress.new()
	var ok := progress.buy("item_bow") and progress.buy("item_saddle_runner_grey") and progress.tusks == 0
	ShopCatalog.free_for_testing = false
	return ok


func _pick_helper_from_pen() -> bool:
	var progress := Progress.new()
	var empty_pen := not progress.buy("item_take_turkey") and progress.companion == ""
	progress.helpers = {"rooster": 1, "turkey": 2}
	var turkey := progress.buy("item_take_turkey") and progress.sold_out("item_take_turkey")
	var rooster := progress.buy("item_take_rooster") and not progress.sold_out("item_take_turkey")
	return empty_pen and turkey and rooster and Progress.from_dict(progress.to_dict()).companion == "rooster"


func _buy_weapon_once() -> bool:
	var progress := Progress.new()
	progress.tusks = 60
	var bought := progress.buy("item_sling")
	var twice := progress.buy("item_sling")
	var too_expensive := progress.buy("item_bow")
	return bought and not twice and not too_expensive and progress.tusks == 35 \
		and progress.owns("item_sling") and not progress.buy("item_unknown")


func _extra_spears_stop_at_two() -> bool:
	var progress := Progress.new()
	progress.tusks = 100
	var three := progress.buy("item_spear") and progress.buy("item_spear") and progress.buy("item_spear")
	var spears: bool = three and not progress.buy("item_spear") and progress.items["item_spear"] == 3 and progress.sold_out("item_spear")
	var arrows: bool = progress.buy("item_arrow") and progress.items["item_arrow"] == 6
	var kit: Dictionary = Progress.from_dict({}).items
	var old_save_kit: Dictionary = Progress.from_dict({"items": {"item_net": 1}}).items
	var kept: Dictionary = Progress.from_dict({"items": {"item_net": 1}, "kit": true}).items
	return spears and arrows and kit == ShopCatalog.STARTER_KIT and old_save_kit["item_net"] == 3 and kept == {"item_net": 1}


func _saddle_needs_caught_boar() -> bool:
	var progress := Progress.new()
	progress.tusks = 100
	var locked := not progress.buy("item_saddle_runner_grey")
	progress.caught = {"runner_grey": 1}
	return locked and progress.tusks == 100 and progress.buy("item_saddle_runner_grey") and progress.tusks == 50
