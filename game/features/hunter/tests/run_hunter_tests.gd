extends SceneTree

const Stamina = preload("res://game/features/hunter/domain/stamina.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_sprint_drains_stamina(), "sprint drains stamina")
	failures += _check(_walking_restores_stamina(), "walking restores stamina")
	failures += _check(_empty_stamina_locks_sprint_until_recovered(), "empty stamina locks sprint until 20")
	failures += _check(_lunge_costs_stamina(), "lunge costs 25 and fails without stamina")
	failures += _check(_spear_throw_and_pick(), "spear is thrown once and picked up again")
	failures += _check(_nets_run_out(), "nets run out and can be picked up")
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
