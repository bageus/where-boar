extends SceneTree

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarSenses = preload("res://game/features/boar/domain/boar_senses.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_perceive_starts_flee_inside_radius(), "hunter is noticed inside the radius, not outside")
	failures += _check(_scatter_splits_into_groups_and_loners(), "scared herd splits into groups and wide-angle loners")
	failures += _check(_sneaking_hunter_behind_or_in_cover_is_unseen(), "sneaking hunter is unseen behind the boar or in cover")
	failures += _check(_hunter_far_above_is_unnoticed(), "a hunter 3 m or more above the boar is not noticed")
	failures += _check(_shout_deflects_without_panic(), "shout deflects 30 degrees and does not panic")
	failures += _check(_bait_pulls_within_radius(), "nearest bait in reach pulls the boar")
	failures += _check(_fear_spreads_in_herd(), "a scared herd mate nearby makes a calm boar flee")
	failures += _check(_strays_walk_back(), "a stray herd boar walks back to the centre")
	failures += _check(_nearest_zone_choice(), "nearest escape zone is chosen")
	failures += _check(_zone_escape_rules(), "only fleeing or panicking boars escape in a zone")
	failures += _check(_flee_heading_bends_to_zone(), "flee heading bends toward a zone ahead, ignores a zone behind")
	print("senses tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _perceive_starts_flee_inside_radius() -> bool:
	return BoarSenses.notices(Vector2.ZERO, Vector2(5, 0), 10.0) and not BoarSenses.notices(Vector2.ZERO, Vector2(20, 0), 10.0)


func _scatter_splits_into_groups_and_loners() -> bool:
	var groups := [BoarSenses.scatter_angle(0.5, 0.1), BoarSenses.scatter_angle(0.9, 0.5), BoarSenses.scatter_angle(0.5, 0.99)]
	var loner_left := rad_to_deg(BoarSenses.scatter_angle(0.1, 0.2))
	var loner_right := rad_to_deg(BoarSenses.scatter_angle(0.1, 0.7))
	return is_equal_approx(rad_to_deg(groups[0]), -45.0) and groups[1] == 0.0 and is_equal_approx(rad_to_deg(groups[2]), 45.0) \
			and loner_left <= -40.0 and loner_left >= -100.0 and loner_right >= 40.0 and loner_right <= 100.0


func _hunter_far_above_is_unnoticed() -> bool:
	var above := BoarSenses.notices(Vector2.ZERO, Vector2(5, 0), 10.0, Vector2.RIGHT, false, true, 3.0)
	var slightly_above := BoarSenses.notices(Vector2.ZERO, Vector2(5, 0), 10.0, Vector2.RIGHT, false, true, 1.5)
	return not above and slightly_above


func _sneaking_hunter_behind_or_in_cover_is_unseen() -> bool:
	var behind := BoarSenses.notices(Vector2.ZERO, Vector2(-5, 0), 10.0, Vector2.RIGHT, true)
	var covered := BoarSenses.notices(Vector2.ZERO, Vector2(5, 0), 10.0, Vector2.RIGHT, true, false)
	var in_front := BoarSenses.notices(Vector2.ZERO, Vector2(5, 0), 10.0, Vector2.RIGHT, true)
	var walking := BoarSenses.notices(Vector2.ZERO, Vector2(-5, 0), 10.0, Vector2.RIGHT, false, false)
	return not behind and not covered and in_front and walking


func _shout_deflects_without_panic() -> bool:
	var boar := Boar.new("runner", 5)
	var left := BoarSenses.shout_heading(boar, Vector2(10, 0), Vector2.ZERO, 1)
	var right := BoarSenses.shout_heading(boar, Vector2(10, 0), Vector2.ZERO, -1)
	var angle := rad_to_deg(left.angle())
	return boar.state == Boar.State.FLEE and is_equal_approx(angle, 30.0) and is_equal_approx(right.angle(), -left.angle())


func _nearest_zone_choice() -> bool:
	var zones: Array[Vector2] = [Vector2(50, 0), Vector2(5, 5), Vector2(-30, 0)]
	var none: Array[Vector2] = []
	return BoarSenses.nearest_zone(Vector2.ZERO, zones) == 1 and BoarSenses.nearest_zone(Vector2.ZERO, none) == -1


func _zone_escape_rules() -> bool:
	var calm := Boar.new("runner", 5)
	BoarSenses.enter_zone(calm, Vector2.ZERO, Vector2.ZERO, 3.0)
	var panicked := Boar.new("runner", 5)
	panicked.flee()
	panicked.take_hit(1)
	BoarSenses.enter_zone(panicked, Vector2(2, 0), Vector2.ZERO, 3.0)
	var outside := Boar.new("runner", 5)
	outside.flee()
	BoarSenses.enter_zone(outside, Vector2(9, 0), Vector2.ZERO, 3.0)
	return calm.state == Boar.State.WANDER and panicked.state == Boar.State.ESCAPED and outside.state == Boar.State.FLEE


func _flee_heading_bends_to_zone() -> bool:
	var no_zone := BoarSenses.flee_heading(Vector2.ZERO, Vector2(-5, 0), [] as Array[Vector2])
	var ahead := BoarSenses.flee_heading(Vector2.ZERO, Vector2(-5, 0), [Vector2(10, 10)] as Array[Vector2])
	var behind := BoarSenses.flee_heading(Vector2.ZERO, Vector2(-5, 0), [Vector2(-10, 1)] as Array[Vector2])
	return no_zone.is_equal_approx(Vector2.RIGHT) \
		and ahead.is_equal_approx((Vector2.RIGHT + Vector2(1, 1).normalized()).normalized()) \
		and behind.is_equal_approx(Vector2.RIGHT)


func _bait_pulls_within_radius() -> bool:
	var baits: Array[Vector3] = [Vector3(10, 0, 5), Vector3(-6, 0, 20), Vector3(-8, 0, 20)]
	return BoarSenses.bait_target(Vector2.ZERO, baits) == 1 \
		and BoarSenses.bait_target(Vector2(30, 0), baits) == -1


func _fear_spreads_in_herd() -> bool:
	var near := Boar.new("runner", 3)
	var far := Boar.new("runner", 3)
	var scared: Array[Vector2] = [Vector2(3, 0)]
	BoarSenses.hear_herd(near, Vector2.ZERO, scared, 8.0)
	BoarSenses.hear_herd(far, Vector2(20, 0), scared, 8.0)
	return near.state == Boar.State.FLEE and far.state == Boar.State.WANDER


func _strays_walk_back() -> bool:
	return BoarSenses.cohesion_heading(Vector2(10, 0), Vector2.ZERO, 6.0).is_equal_approx(Vector2.LEFT) \
		and BoarSenses.cohesion_heading(Vector2(2, 0), Vector2.ZERO, 6.0) == Vector2.ZERO
