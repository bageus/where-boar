extends SceneTree

const Stamina = preload("res://game/features/hunter/domain/stamina.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")
const Health = preload("res://game/features/hunter/domain/health.gd")
const Ride = preload("res://game/features/hunter/domain/ride.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_sprint_drains_stamina(), "sprint drains stamina")
	failures += _check(_walking_restores_stamina(), "walking restores stamina")
	failures += _check(_empty_stamina_locks_sprint_until_recovered(), "empty stamina locks sprint until 20")
	failures += _check(_lunge_costs_stamina(), "lunge costs 25 and fails without stamina")
	failures += _check(_spear_throw_and_pick(), "spear is thrown once and picked up again")
	failures += _check(_nets_run_out(), "nets run out and can be picked up")
	failures += _check(_health_runs_down_to_zero(), "damage lowers health and stops at zero")
	failures += _check(_bought_weapons_unlock(), "bought weapons unlock; arrows run out")
	failures += _check(_bait_strongest_first(), "bait is placed strongest first and counted as used")
	failures += _check(_traps_cycle_and_run_out(), "traps cycle and run out")
	failures += _check(_meal_and_water(), "carried meals stack on max stamina; water sips restore it")
	failures += _check(_porter_and_any_trap(), "porter adds nets and arrows; any trap in stock can be set")
	failures += _check(_ride_by_mount_type(), "mount type sets speed and perk; only the stab works when riding")
	failures += _check(_saddles_from_items(), "saddled mount types come from camp items")
	print("hunter tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _sprint_drains_stamina() -> bool:
	var stamina := Stamina.new()
	return stamina.tick(1.0, true) and is_equal_approx(stamina.value, 98.0)


func _walking_restores_stamina() -> bool:
	var stamina := Stamina.new()
	stamina.value = 50.0
	return not stamina.tick(1.0, false) and is_equal_approx(stamina.value, 65.0)


func _empty_stamina_locks_sprint_until_recovered() -> bool:
	var stamina := Stamina.new()
	stamina.tick(100.0, true)
	var emptied := stamina.value == 0.0
	var locked := not stamina.tick(1.0, true)
	var still_locked := not stamina.tick(0.1, true)
	stamina.tick(1.0, false)
	return emptied and locked and still_locked and stamina.tick(0.1, true)


func _lunge_costs_stamina() -> bool:
	var stamina := Stamina.new()
	var first := stamina.try_lunge()
	stamina.value = 10.0
	return first and not stamina.try_lunge() and is_equal_approx(stamina.value, 10.0)


func _spear_throw_and_pick() -> bool:
	var loadout := Loadout.new()
	var thrown := loadout.throw_spear()
	var again := loadout.throw_spear()
	loadout.pick_spear()
	var single := thrown and not again and loadout.spear_in_hand
	var armed := Loadout.new()
	armed.equip({"item_spear": 5})
	var three := armed.spears == 3 and armed.throw_spear() and armed.throw_spear() and armed.throw_spear()
	var empty := not armed.throw_spear()
	for i in 4:
		armed.pick_spear()
	return single and three and empty and armed.spears == 3


func _nets_run_out() -> bool:
	var loadout := Loadout.new()
	for i in Loadout.START_NETS:
		loadout.throw_net()
	var empty := not loadout.throw_net()
	loadout.pick_net()
	return empty and loadout.nets == 1


func _health_runs_down_to_zero() -> bool:
	var health := Health.new()
	health.take(30)
	var hurt := health.value == 70 and not health.is_down()
	health.take(500)
	return hurt and health.value == 0 and health.is_down()


func _bought_weapons_unlock() -> bool:
	var loadout := Loadout.new()
	var locked := not loadout.has(Loadout.Weapon.BOW) and not loadout.shoot_arrow()
	loadout.equip({"item_bow": 1, "item_club": 0})
	for i in Loadout.START_ARROWS:
		loadout.shoot_arrow()
	return locked and loadout.has(Loadout.Weapon.BOW) and not loadout.has(Loadout.Weapon.CLUB) \
		and loadout.has(Loadout.Weapon.SPEAR) and not loadout.shoot_arrow()


func _bait_strongest_first() -> bool:
	var loadout := Loadout.new()
	loadout.equip({"item_acorns": 1, "item_apple": 1})
	var first := loadout.place_bait()
	var second := loadout.place_bait()
	return first == "item_apple" and second == "item_acorns" and loadout.place_bait() == "" \
		and loadout.used == {"item_apple": 1, "item_acorns": 1}


func _traps_cycle_and_run_out() -> bool:
	var loadout := Loadout.new()
	loadout.equip({"item_snare": 1})
	var none := loadout.place_trap() == ""
	loadout.cycle_trap()
	return none and loadout.place_trap() == "item_snare" and loadout.place_trap() == "" \
		and loadout.used == {"item_snare": 1}


func _meal_and_water() -> bool:
	var loadout := Loadout.new()
	loadout.equip({"item_stew": 2, "item_feast": 1, "item_water_bag": 1})
	var stamina := Stamina.new()
	stamina.eat(loadout.eat_meals())
	var fed := is_equal_approx(stamina.max_value, 190.0) and is_equal_approx(stamina.value, 190.0)
	stamina.value = 0.0
	stamina.drink(40.0)
	for i in Loadout.WATER_SIPS:
		loadout.drink()
	return fed and is_equal_approx(stamina.value, 40.0) and not loadout.drink() \
		and loadout.used == {"item_feast": 1, "item_stew": 2} and is_zero_approx(loadout.eat_meals())


func _porter_and_any_trap() -> bool:
	var loadout := Loadout.new()
	loadout.equip({"item_porter": 1, "item_cage": 1})
	return loadout.nets == Loadout.START_NETS + 2 and loadout.arrows == Loadout.START_ARROWS + 6 \
		and loadout.place_any_trap() == "item_cage" and loadout.place_any_trap() == ""


func _ride_by_mount_type() -> bool:
	var ride := Ride.new()
	var on_foot := ride.speed(4.0) == 4.0 and ride.allows(Loadout.Weapon.NET, false)
	ride.mount(BoarTypes.find("armored_black"))
	var armored := ride.shrugs_off_knock() and not ride.rams() and ride.speed(4.0) == 6.5
	ride.mount(BoarTypes.find("aggressive_red"))
	var angry := ride.rams() and not ride.shrugs_off_knock()
	var stab_only := ride.allows(Loadout.Weapon.SPEAR, false) and not ride.allows(Loadout.Weapon.SPEAR, true) \
		and ride.allows(Loadout.Weapon.BOW, false) and ride.allows(Loadout.Weapon.NET, false) \
		and not ride.allows(Loadout.Weapon.CLUB, false) and not ride.allows(Loadout.Weapon.SLING, false)
	ride.dismount()
	return on_foot and armored and angry and stab_only and not ride.is_riding()


func _saddles_from_items() -> bool:
	var loadout := Loadout.new()
	loadout.equip({"item_saddle_aggressive_red": 1, "item_saddle_runner_grey": 0})
	return loadout.saddled == ["aggressive_red"]
