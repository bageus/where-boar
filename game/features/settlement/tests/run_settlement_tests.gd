extends SceneTree

const Progress = preload("res://game/features/settlement/public/progress.gd")
const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const QuestBoard = preload("res://game/features/settlement/public/quest_board.gd")


func _init() -> void:
	ShopCatalog.free_for_testing = false
	var failures := 0
	failures += _check(_free_for_testing_costs_nothing(), "while testing, items are free and saddles unlocked")
	failures += _check(_hunt_adds_tusks_and_catches(), "a hunt adds tusks and live catches and spends bait")
	failures += _check(_spend_needs_enough_tusks(), "spending needs enough tusks")
	failures += _check(_round_trip(), "progress survives to_dict/from_dict")
	failures += _check(_bad_data_falls_back(), "malformed save data falls back to defaults")
	failures += _check(_buy_weapon_once(), "a weapon is bought once for its price")
	failures += _check(_one_crewman_at_a_time(), "hiring a warrior sends the trap setter home; the porter stays")
	failures += _check(_pick_helper_from_pen(), "a helper in the pen can be taken on the hunt, one at a time")
	failures += _check(_extra_spears_stop_at_two(), "spears stack to three, arrows come in packs, new games get the starter kit once")
	failures += _check(_saddle_needs_caught_boar(), "a saddle needs a caught boar of its type")
	failures += _check(_pen_holds_five_newest(), "the camp pen keeps the five newest caught boars, oldest out first")
	failures += _check(_sell_whole_tusks_only(), "selling pays whole tusks and keeps the rest of the stack")
	failures += _check(_forge_takes_gifts_until_built(), "the forge takes gifts until its cost is reached")
	failures += _check(_forge_recipes_need_forge_and_metal(), "forge recipes need the built forge, tusks and metal parts")
	failures += _check(_clan_needs_hut_and_tent(), "a clan is founded with the hut, its clan tent and a name, rates its hunts and survives a save")
	failures += _check(_quests_accept_progress_claim(), "quests are drawn, accepted, met by hunts or materials and claimed once")
	failures += _check(_hut_and_board_survive_save(), "the bought hut, forge gifts, materials and quests survive a save")
	failures += _check(_ride_a_saddled_boar(), "the pens pick which saddled boar is ridden; only its saddle goes on the hunt")
	failures += _check(_sell_birds_and_baits(), "cages sell caught birds, the hunting hut sells baits back")
	failures += _check(_gear_box_caps(), "the gear box packs 2 weapon kinds, 3 baits, 1 trap; a helper doubles baits and traps")
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
	hunt.invasion.loot = {"item_metal_plate": 2}
	var progress := Progress.new()
	progress.items = {"item_acorns": 3}
	progress.add_hunt(hunt)
	return progress.tusks == 22 and progress.hunts == 1 and progress.caught == {"golden_tusk": 1} and progress.items["item_acorns"] == 2 \
		and progress.helpers == {"rooster": 1} and progress.items["item_metal_plate"] == 2


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


func _forge_recipes_need_forge_and_metal() -> bool:
	var progress := Progress.new()
	progress.tusks = 2500
	progress.items = {"item_metal_plate": 25, "item_component": 5, "item_metal_tusk": 10}
	var before_built := not progress.buy("item_armor")
	progress.forge = ShopCatalog.FORGE_COST
	var short := not progress.buy("item_armor_shock")
	return before_built and short and progress.buy("item_armor") and progress.owns("item_armor") and progress.tusks == 500 \
		and progress.items["item_metal_plate"] == 5 and progress.items["item_component"] == 0 and not progress.buy("item_armor")


func _clan_needs_hut_and_tent() -> bool:
	var progress := Progress.new()
	progress.tusks = 8000
	var no_tent_first := not progress.buy("item_clan_tent") and progress.buy("item_hut") and not progress.found_clan("Tusks")
	var founded := progress.buy("item_clan_tent") and not progress.found_clan("  ") and progress.found_clan(" Tusks ")
	progress.clan.rules = {"hunts": 5}
	var hunt := Hunt.new(3)
	hunt.record("common_brown", BoarOutcome.Kind.DEAD)
	hunt.record("golden_tusk", BoarOutcome.Kind.CAPTURED)
	hunt.invasion.record_terminator(true)
	progress.add_hunt(hunt)
	progress.add_hunt(Hunt.new(1))  # nothing killed or caught: not a hunt for the clan
	var back := Progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	return no_tent_first and founded and back.clan.name == "Tusks" and back.clan.rules == {"hunts": 5} \
		and back.clan.rating() == 100 + 20 + 50 + 200 and back.clan.achievements() == ["First hunt", "First boar caught", "First terminator"] \
		and back.clan.tier_name() == "New" and Progress.from_dict({}).clan == null


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


func _one_crewman_at_a_time() -> bool:
	var progress := Progress.new()
	progress.tusks = 1000
	var hired := progress.buy("item_porter") and progress.buy("item_trap_setter") and progress.buy("item_warrior")
	return hired and progress.owns("item_warrior") and not progress.owns("item_trap_setter") \
		and progress.team() == PackedStringArray(["Porter", "Warrior"])


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


func _sell_whole_tusks_only() -> bool:
	var progress := Progress.new()
	progress.materials = {"stick": 30}
	var earned := progress.sell("stick", 30, 12)
	return earned == 2 and progress.tusks == 2 and progress.materials["stick"] == 6 and progress.sell("stick", 6, 12) == 0 \
		and progress.sell("feather", 50, 12) == 0


func _forge_takes_gifts_until_built() -> bool:
	var progress := Progress.new()
	progress.tusks = ShopCatalog.FORGE_COST + 500
	for i in ShopCatalog.FORGE_COST / 10000:
		progress.buy("item_forge_10000")
	return progress.forge_built() and not progress.buy("item_forge_100") and progress.tusks == 500 \
		and not progress.items.has("item_forge_10000")


func _quests_accept_progress_claim() -> bool:
	var board := QuestBoard.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	board.renew_if_due(1000, rng)
	var drawn := board.quests.size() == QuestBoard.POOL_SIZE and board.renews_at == 1000 + QuestBoard.RENEW_SECONDS
	var kinds := board.quests.map(func(q: Dictionary) -> String: return q["kind"])
	board.renew_if_due(2000, rng)
	var kept: bool = board.quests.map(func(q: Dictionary) -> String: return q["kind"]) == kinds
	board.quests = [{"kind": "catch", "amount": 2, "reward": 20, "have": 0, "state": "open"},
		{"kind": "stick", "amount": 24, "reward": 3, "have": 0, "state": "open"}]
	var progress := Progress.new()
	progress.quests = board
	var hunt := Hunt.new(2)
	hunt.record("common_brown", BoarOutcome.Kind.CAPTURED)
	progress.add_hunt(hunt)  # not accepted yet: does not count
	board.accept(0)
	board.accept(1)
	progress.add_hunt(hunt)
	var half := not board.can_claim(0, progress.materials)
	progress.add_hunt(hunt)
	progress.materials = {"stick": 30}
	var before := progress.tusks
	var claimed := progress.claim_quest(0) and progress.claim_quest(1) and not progress.claim_quest(1)
	return drawn and kept and half and claimed and progress.tusks == before + 23 and progress.materials["stick"] == 6 \
		and board.claimed_count() == 2


func _hut_and_board_survive_save() -> bool:
	var progress := Progress.new()
	progress.hut_slot = 3
	progress.hut_variant = 4
	progress.forge = 1200
	progress.materials = {"frog": 5}
	progress.quests.renew_if_due(10)
	progress.quests.accept(1)
	var back := Progress.from_dict(JSON.parse_string(JSON.stringify(progress.to_dict())))
	var bad := Progress.from_dict({"hut_slot": 99, "quests": {"quests": [{"kind": "nope"}, 5]}})
	return back.hut_slot == 3 and back.hut_variant == 4 and back.forge == 1200 and back.materials == {"frog": 5} \
		and back.quests.quests.size() == QuestBoard.POOL_SIZE and back.quests.quests[1]["state"] == "accepted" \
		and back.quests.renews_at == progress.quests.renews_at and bad.hut_slot == -1 and bad.quests.quests.is_empty()


func _ride_a_saddled_boar() -> bool:
	var progress := Progress.new()
	var locked := not progress.buy("item_ride_armored_black")
	progress.items = {"item_saddle_runner_grey": 1, "item_saddle_armored_black": 1}
	var first := progress.riding() == "runner_grey"
	var picked := progress.buy("item_ride_armored_black") and progress.sold_out("item_ride_armored_black")
	var taken := progress.hunt_items()
	var back := Progress.from_dict(progress.to_dict())
	return locked and first and picked and taken.has("item_saddle_armored_black") and not taken.has("item_saddle_runner_grey") \
		and back.riding() == "armored_black"


func _sell_birds_and_baits() -> bool:
	var progress := Progress.new()
	progress.helpers = {"rooster": 2}
	progress.items = {"item_mango": 3}
	progress.carried = {"item_mango": 3}
	var rate := ShopCatalog.sell_rate("cages", "rooster")
	var birds: bool = progress.sell("rooster", 1, rate.x, rate.y) == 10 and progress.helpers["rooster"] == 1
	rate = ShopCatalog.sell_rate("hunting_hut", "item_mango")
	var bait: bool = progress.sell("item_mango", 2, rate.x, rate.y) == 12 and progress.items["item_mango"] == 1
	return birds and bait and progress.carried["item_mango"] == 1 and ShopCatalog.sell_rate("pens", "grass") == Vector2i(12, 1)


func _gear_box_caps() -> bool:
	var progress := Progress.new()
	progress.items = {"item_spear": 2, "item_spear_wood": 1, "item_net": 3, "item_bow": 1, "item_club": 1, "item_acorns": 5,
		"item_pit": 2, "item_snare": 1, "item_feast": 1}
	var weapons := progress.carry("item_spear") == 2 and progress.carry("item_spear_wood") == 1 and progress.carry("item_net") == 3 \
		and progress.carry("item_bow") == 0 and progress.carry("item_club") == 1 and progress.slot_used("weapon") == 2
	for i in 5:
		progress.carry("item_acorns")
	var baits: bool = progress.carried["item_acorns"] == 3 and progress.in_box("item_acorns") == 2
	var traps := progress.carry("item_pit") == 1 and progress.carry("item_snare") == 0
	var taken := progress.hunt_items()
	var hunt_kit: bool = taken["item_bow"] == 0 and taken["item_feast"] == 1 and taken["item_acorns"] == 3
	progress.store("item_net")
	var swapped := progress.carry("item_bow") == 1
	progress.items["item_porter"] = 1
	var helped := progress.carry("item_acorns") == 1 and progress.carry("item_snare") == 1 and progress.carry("item_pit") == 0
	var fresh := Progress.from_dict({})
	return weapons and baits and traps and hunt_kit and swapped and helped and fresh.carried == {"item_spear": 1, "item_net": 3}
