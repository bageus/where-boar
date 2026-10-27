extends SceneTree

const Stamina = preload("res://game/features/hunter/domain/stamina.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")
const Health = preload("res://game/features/hunter/domain/health.gd")


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
	print("hunter tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _sprint_drains_stamina() -> bool:
	var stamina := Stamina.new()
	return stamina.tick(1.0, true) and is_equal_approx(stamina.value, 80.0)


func _walking_restores_stamina() -> bool:
	var stamina := Stamina.new()
	stamina.value = 50.0
	return not stamina.tick(1.0, false) and is_equal_approx(stamina.value, 65.0)


func _empty_stamina_locks_sprint_until_recovered() -> bool:
	var stamina := Stamina.new()
	stamina.tick(10.0, true)
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
	return thrown and not again and loadout.spear_in_hand


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
