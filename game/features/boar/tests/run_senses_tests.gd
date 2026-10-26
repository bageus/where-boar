extends SceneTree

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarSenses = preload("res://game/features/boar/domain/boar_senses.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_perceive_starts_flee_inside_radius(), "hunter inside radius starts flee, outside does not")
	failures += _check(_shout_deflects_without_panic(), "shout deflects 30 degrees and does not panic")
	failures += _check(_nearest_zone_choice(), "nearest escape zone is chosen")
	failures += _check(_zone_escape_rules(), "only fleeing or panicking boars escape in a zone")
	print("senses tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _perceive_starts_flee_inside_radius() -> bool:
	var near := Boar.new("runner", 5)
	BoarSenses.perceive(near, Vector2.ZERO, Vector2(5, 0), 10.0)
	var far := Boar.new("runner", 5)
	BoarSenses.perceive(far, Vector2.ZERO, Vector2(20, 0), 10.0)
	return near.state == Boar.State.FLEE and far.state == Boar.State.WANDER


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
