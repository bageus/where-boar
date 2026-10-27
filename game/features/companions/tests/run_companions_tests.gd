extends SceneTree

const CompanionRules = preload("res://game/features/companions/public/companion_rules.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_rooster_lands_behind_herd(), "rooster lands behind the herd, away from the hunter")
	failures += _check(_nearest_group_is_targeted(), "the group nearest the hunter is targeted")
	print("companions tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _rooster_lands_behind_herd() -> bool:
	var spot := CompanionRules.drive_point(Vector2(0, -10), Vector2(0, 10))
	return spot.is_equal_approx(Vector2(0, -10 - CompanionRules.DRIVE_DISTANCE))


func _nearest_group_is_targeted() -> bool:
	var boars: Array[Vector2] = [Vector2(0, 0), Vector2(2, 0), Vector2(30, 30)]
	return CompanionRules.target_group_centre(boars, Vector2(0, 10), 8.0).is_equal_approx(Vector2(1, 0))
