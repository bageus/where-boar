extends SceneTree

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarDodge = preload("res://game/features/boar/domain/boar_dodge.gd")

# The boar runs along +X from the origin in every case.
const AHEAD := Vector2.RIGHT


func _init() -> void:
	var failures := 0
	failures += _check(_pressing_needs_close_and_closing_in(), "hunter presses only when close and running at the boar")
	failures += _check(_side_approach_veers_away(), "approached from a side, the boar veers to the other side")
	failures += _check(_head_on_swerves_to_rolled_side(), "met head-on, the boar swerves to its rolled side")
	failures += _check(_from_behind_keeps_course(), "chased from straight behind, the boar keeps its course")
	failures += _check(_behind_right_bends_left(), "chased from behind a little to one side, it bends a little the other way")
	failures += _check(_turn_is_rate_limited(), "dodge turns are limited by the turn rate")
	failures += _check(_jinks_only_when_chased_from_behind(), "jinks happen only when chased from behind")
	failures += _check(_bigger_angrier_types_attack_more(), "cornered attack chance grows with size and aggression")
	failures += _check(_cornered_rolls_once(), "cornered boar rolls once per press; a miss cuts to the other side")
	failures += _check(_cunning_charges_head_on(), "cunning type may charge when met head-on, plain type never")
	failures += _check(_turn_on_only_from_flight(), "only a fleeing or panicking boar turns on the hunter")
	print("dodge tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _pressing_needs_close_and_closing_in() -> bool:
	var hunter := Vector2(-5, 0)
	return BoarDodge.pressing(Vector2.ZERO, hunter, Vector2(4, 0)) \
			and not BoarDodge.pressing(Vector2.ZERO, hunter, Vector2(-4, 0)) \
			and not BoarDodge.pressing(Vector2.ZERO, hunter, Vector2(0, 4)) \
			and not BoarDodge.pressing(Vector2.ZERO, Vector2(-20, 0), Vector2(4, 0))


func _side_approach_veers_away() -> bool:
	var from_plus := BoarDodge.dodge_turn(AHEAD, Vector2.ZERO, Vector2(0, 5), 1)
	var from_minus := BoarDodge.dodge_turn(AHEAD, Vector2.ZERO, Vector2(0, -5), 1)
	# A turn is positive toward +Y (rotated), so a hunter on +Y gives a negative turn.
	return from_plus < -0.5 and from_minus > 0.5


func _head_on_swerves_to_rolled_side() -> bool:
	var left := BoarDodge.dodge_turn(AHEAD, Vector2.ZERO, Vector2(5, 0), 1)
	var right := BoarDodge.dodge_turn(AHEAD, Vector2.ZERO, Vector2(5, 0), -1)
	return left > 2.0 and right < -2.0 and BoarDodge.head_on(AHEAD, Vector2.ZERO, Vector2(5, 0.5))


func _from_behind_keeps_course() -> bool:
	return absf(BoarDodge.dodge_turn(AHEAD, Vector2.ZERO, Vector2(-5, 0), 1)) < 0.001


func _behind_right_bends_left() -> bool:
	var turn := BoarDodge.dodge_turn(AHEAD, Vector2.ZERO, Vector2(-5, 1), 1)
	return turn < 0.0 and turn > -0.5


func _turn_is_rate_limited() -> bool:
	var dodge := BoarDodge.new()
	dodge.press(0.9)
	var next := dodge.steer(0.1, AHEAD, Vector2.ZERO, Vector2(5, 0), 0.99, 0.5)
	return is_equal_approx(AHEAD.angle_to(next), BoarDodge.TURN_RATE * 0.1) and dodge.turn_side == 1


func _jinks_only_when_chased_from_behind() -> bool:
	var dodge := BoarDodge.new()
	dodge.press(0.9)
	var behind := dodge.steer(0.1, AHEAD, Vector2.ZERO, Vector2(-5, 0), 0.0, 1.0)
	var side := BoarDodge.new()
	side.press(0.9)
	var veer := side.steer(0.1, AHEAD, Vector2.ZERO, Vector2(0, 5), 0.0, 1.0)
	# From behind the jink (angle_roll 1 = full positive) turns +; from +Y side the dodge still turns away (-).
	return AHEAD.angle_to(behind) > 0.0 and AHEAD.angle_to(veer) < 0.0


func _bigger_angrier_types_attack_more() -> bool:
	var tiny := BoarDodge.corner_chance(2, 0.1)
	var common := BoarDodge.corner_chance(3, 0.35)
	var armored := BoarDodge.corner_chance(8, 0.5)
	return tiny < common and common < armored and armored >= 0.8 and tiny >= BoarDodge.CORNER_MIN


func _cornered_rolls_once() -> bool:
	var dodge := BoarDodge.new()
	dodge.press(0.9)
	dodge.steer(0.1, AHEAD, Vector2.ZERO, Vector2(0, -5), 0.99, 0.5)  # turns + (away from -Y)
	var missed := dodge.turns_on_hunter(true, false, 0.9, 0.5, 0.0)
	var again := dodge.turns_on_hunter(true, false, 0.0, 0.5, 0.0)
	var cut := dodge.steer(0.1, AHEAD, Vector2.ZERO, Vector2(0, -5), 0.99, 0.5)
	var fresh := BoarDodge.new()
	fresh.press(0.9)
	var hit := fresh.turns_on_hunter(true, false, 0.1, 0.5, 0.0)
	return not missed and not again and AHEAD.angle_to(cut) < 0.0 and hit


func _cunning_charges_head_on() -> bool:
	var cunning := BoarDodge.new()
	cunning.press(0.9)
	var plain := BoarDodge.new()
	plain.press(0.9)
	return cunning.turns_on_hunter(false, true, 0.2, 0.5, 0.5) and not plain.turns_on_hunter(false, true, 0.0, 0.5, 0.0) \
			and not cunning.turns_on_hunter(false, true, 0.0, 0.5, 0.5)


func _turn_on_only_from_flight() -> bool:
	var fleeing := Boar.new("common", 3)
	fleeing.flee()
	fleeing.turn_on()
	var calm := Boar.new("common", 3)
	calm.turn_on()
	return fleeing.state == Boar.State.CHARGE and calm.state == Boar.State.WANDER
