extends SceneTree

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarAlert = preload("res://game/features/boar/domain/boar_alert.gd")
const BoarIdle = preload("res://game/features/boar/domain/boar_idle.gd")
const BoarHide = preload("res://game/features/boar/domain/boar_hide.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_hit_on_flee_panics(), "hit on flee boar panics")
	failures += _check(_net_captures_free_boar(), "net captures free boar")
	failures += _check(_captured_ignores_hits_and_escape(), "captured boar ignores hit and escape")
	failures += _check(_zero_health_is_dead(), "zero health is dead")
	failures += _check(_escape_only_when_fleeing(), "escape only when fleeing")
	failures += _check(_trap_held_counts_as_captured(), "trap held to hunt end counts as captured")
	failures += _check(_only_panic_turns_to_charge(), "only a panicking boar charges, then flees")
	failures += _check(_hit_scares_attacker_but_not_rammer(), "hit scares an attacking boar off, a ramming one keeps charging")
	failures += _check(_alert_rises_in_stages_and_fades(), "alert rises 1-2-3 while noticed, faster up close, and fades a level per cooldown")
	failures += _check(_quiet_captures_make_mates_wary_then_run(), "a quiet capture makes mates wary; a second one makes them run")
	failures += _check(_flight_calms_and_alarmed_boar_attacks(), "a fleeing boar calms down; an alarmed calm boar can attack")
	failures += _check(_types_pick_by_weight(), "five types, rarer types need higher rolls")
	failures += _check(_trapped_boar_stays_until_freed(), "trapped boar stays when hurt, can be netted or break free")
	failures += _check(_idle_mostly_stands_and_joins_mates(), "idle boar mostly grazes or stands, joins a mate, roams sometimes")
	failures += _check(_fleeing_boar_hides_in_tall_grass(), "a fleeing boar may hide in tall grass, calms there or is flushed out")
	failures += _check(_stray_goes_back_to_herd(), "a calm stray walks back to its herd")
	print("boar tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _hit_on_flee_panics() -> bool:
	var boar := Boar.new("runner", 5)
	boar.flee()
	boar.take_hit(1)
	return boar.state == Boar.State.PANIC and boar.health == 4


func _net_captures_free_boar() -> bool:
	var boar := Boar.new("runner", 5)
	boar.flee()
	boar.net_capture()
	return boar.state == Boar.State.CAPTURED and boar.outcome_kind() == BoarOutcome.Kind.CAPTURED


func _captured_ignores_hits_and_escape() -> bool:
	var boar := Boar.new("runner", 5)
	boar.flee()
	boar.net_capture()
	boar.take_hit(9)
	boar.escape()
	return boar.state == Boar.State.CAPTURED and boar.health == 5


func _zero_health_is_dead() -> bool:
	var boar := Boar.new("runner", 2)
	boar.take_hit(2)
	return boar.state == Boar.State.DEAD and boar.outcome_kind() == BoarOutcome.Kind.DEAD


func _escape_only_when_fleeing() -> bool:
	var calm := Boar.new("runner", 5)
	calm.escape()
	var fleeing := Boar.new("runner", 5)
	fleeing.flee()
	fleeing.escape()
	return calm.state == Boar.State.WANDER and fleeing.state == Boar.State.ESCAPED


func _trap_held_counts_as_captured() -> bool:
	var boar := Boar.new("armored", 9)
	boar.trap()
	return boar.state == Boar.State.TRAPPED and boar.outcome_kind() == BoarOutcome.Kind.CAPTURED


func _only_panic_turns_to_charge() -> bool:
	var calm := Boar.new("runner", 3)
	calm.charge()
	var boar := Boar.new("runner", 3)
	boar.take_hit(1)
	boar.charge()
	var charging := boar.state == Boar.State.CHARGE and boar.is_free()
	boar.escape()
	var stays := boar.state == Boar.State.CHARGE
	boar.end_charge()
	return calm.state == Boar.State.WANDER and charging and stays and boar.state == Boar.State.FLEE


func _hit_scares_attacker_but_not_rammer() -> bool:
	var attacker := Boar.new("runner", 5)
	attacker.take_hit(1)
	attacker.charge()
	attacker.take_hit(1)
	var rammer := Boar.new("runner", 5)
	rammer.take_hit(1)
	rammer.charge()
	rammer.ramming = true
	rammer.take_hit(1)
	var whole := Boar.new("runner", 5)
	return attacker.state == Boar.State.FLEE and rammer.state == Boar.State.CHARGE \
			and rammer.is_wounded() and not whole.is_wounded()


func _alert_rises_in_stages_and_fades() -> bool:
	var alert := BoarAlert.new()
	alert.tick(1.0, true, 1.0)
	var heard := alert.level() == 1
	alert.tick(1.0, true, 1.0)
	var wary := alert.level() == 2 and not alert.alarmed()
	alert.tick(2.9, false, 0.0)
	var held := alert.level() == 2
	alert.tick(0.2, false, 0.0)
	var faded := alert.level() == 1
	var close := BoarAlert.new()
	close.tick(0.75, true, 4.0)
	return heard and wary and held and faded and close.alarmed()


func _quiet_captures_make_mates_wary_then_run() -> bool:
	var alert := BoarAlert.new()
	var first := not alert.witness_capture() and alert.level() == 2
	return first and alert.witness_capture() and alert.alarmed()


func _flight_calms_and_alarmed_boar_attacks() -> bool:
	var boar := Boar.new("runner", 5)
	boar.flee()
	boar.calm()
	var calm := boar.state == Boar.State.WANDER
	boar.attack()
	return calm and boar.state == Boar.State.CHARGE


func _types_pick_by_weight() -> bool:
	var ids := BoarTypes.ALL.map(func(type: Resource) -> String: return type.id)
	return ids == ["common_brown", "runner_grey", "aggressive_red", "armored_black", "bone", "bun", "bubble",
			"mohawk", "dachshund", "camo", "hairy", "tiny", "golden_tusk"] \
		and BoarTypes.pick(0.0).id == "common_brown" \
		and BoarTypes.pick(0.999).id == "golden_tusk" \
		and BoarTypes.rewards()["golden_tusk"] == {"dead": 10, "captured": 20, "wounded": 15}


func _trapped_boar_stays_until_freed() -> bool:
	var boar := Boar.new("runner", 3)
	boar.trap()
	boar.take_hit(1)
	var held := boar.state == Boar.State.TRAPPED and not boar.is_free()
	boar.break_free()
	var loose := boar.state == Boar.State.PANIC
	boar.trap()
	boar.net_capture()
	return held and loose and boar.state == Boar.State.CAPTURED


func _idle_mostly_stands_and_joins_mates() -> bool:
	var picks := {}
	for i in 100:
		var activity := BoarIdle.pick(i / 100.0, true)
		picks[activity] = picks.get(activity, 0) + 1
	var mostly_still: bool = picks[BoarIdle.Activity.GRAZE] + picks[BoarIdle.Activity.STAND] > picks[BoarIdle.Activity.ROAM] * 2
	var loner_never_joins := BoarIdle.pick(0.7, false) == BoarIdle.Activity.STAND and BoarIdle.pick(0.7, true) == BoarIdle.Activity.JOIN
	var idle := BoarIdle.new(0.0)
	idle.start(BoarIdle.Activity.ROAM, 0.0)
	var changed := not idle.tick(2.0, true, 0.0) and idle.tick(1.5, true, 0.0) and idle.activity == BoarIdle.Activity.GRAZE
	idle.start(BoarIdle.Activity.JOIN)
	idle.arrived(0.9)
	return mostly_still and loner_never_joins and changed and idle.standing() and picks.has(BoarIdle.Activity.JOIN)


func _fleeing_boar_hides_in_tall_grass() -> bool:
	var hide := BoarHide.new()
	hide.start_flight(0.9)  # not this flight
	if hide.consider(Vector2.ZERO, Vector3(5, 0, 4)):
		return false
	hide.start_flight(0.1)
	if hide.consider(Vector2.ZERO, Vector3(40, 0, 4)) or hide.consider(Vector2.ZERO, Vector3(0, 0, 0)):
		return false  # too far, or no grass
	if not hide.consider(Vector2.ZERO, Vector3(10, 0, 4)) or hide.heading(Vector2.ZERO) != Vector2.RIGHT:
		return false
	hide.tick(0.1, Vector2(9, 0), 30.0, 0.0)
	if not hide.hidden() or hide.heading(Vector2(9, 0)) != Vector2.ZERO:
		return false
	var calmed := hide.tick(7.0, Vector2(9, 0), 30.0) == BoarHide.Result.KEEP \
			and hide.tick(1.5, Vector2(9, 0), 30.0) == BoarHide.Result.CALMED and not hide.active()
	hide.start_flight(0.1)
	hide.consider(Vector2(9, 0), Vector3(10, 0, 4))
	hide.tick(0.1, Vector2(9, 0), 30.0)
	var flushed := hide.tick(0.1, Vector2(9, 0), 3.0) == BoarHide.Result.FLUSHED and not hide.wants()
	hide.start_flight(0.1)
	hide.consider(Vector2.ZERO, Vector3(10, 0, 4))
	var gave_up := hide.tick(BoarHide.SEEK_SECONDS + 0.1, Vector2.ZERO, 30.0) == BoarHide.Result.GAVE_UP
	return calmed and flushed and gave_up


func _stray_goes_back_to_herd() -> bool:
	var idle := BoarIdle.new(0.0)
	idle.start(BoarIdle.Activity.GRAZE, 0.0)
	idle.tick(100.0, true, 0.0, true)
	return idle.activity == BoarIdle.Activity.JOIN
