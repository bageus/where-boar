extends SceneTree

const Cyborg = preload("res://game/features/boar/domain/cyborg.gd")


func _init() -> void:
	var failures := 0
	failures += _check(_armor_soaks_before_health(), "armour soaks hits before health")
	failures += _check(_slower_than_hunter(), "cyborg is slower than the walking hunter")
	failures += _check(_turret_clamped_to_90(), "turret aim is clamped to 90 degrees each side")
	failures += _check(_cannon_cooldown(), "cannon fires once, then waits 4-5 s")
	failures += _check(_machinegun_bursts(), "machinegun fires a burst of rounds")
	failures += _check(_seen_hiding_is_searched(), "hunter seen hiding is searched for at the spot, found up close")
	failures += _check(_gives_up_after_search(), "cyborg gives up after searching and patrols")
	failures += _check(_hit_makes_it_hunt(), "a hit turns a patrolling cyborg toward the shooter")
	print("cyborg tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _armor_soaks_before_health() -> bool:
	var c := Cyborg.new(Cyborg.Gun.CANNON, 30, 50)
	c.take_hit(20)
	var first := c.armor == 10 and c.health == 50
	c.take_hit(20)
	var second := c.armor == 0 and c.health == 40
	c.take_hit(100)
	return first and second and c.is_dead()


func _slower_than_hunter() -> bool:
	return Cyborg.CHASE_SPEED < 4.0


func _turret_clamped_to_90() -> bool:
	var side := Cyborg.turret_target(Vector2.ZERO, Vector2.RIGHT, Vector2(0, 5))
	var behind := Cyborg.turret_target(Vector2.ZERO, Vector2.RIGHT, Vector2(-5, 1))
	return is_equal_approx(side, PI / 2) and is_equal_approx(absf(behind), PI / 2)


func _chasing(gun: Cyborg.Gun) -> Cyborg:
	var c := Cyborg.new(gun, 10, 10)
	c.think(0.1, Vector2.ZERO, Vector2(10, 0), true)
	return c


func _cannon_cooldown() -> bool:
	var c := _chasing(Cyborg.Gun.CANNON)
	var shots := 0
	for i in 40:  # 4 s at 0.1
		shots += c.update_turret(0.1, Vector2.ZERO, Vector2.RIGHT, Vector2(10, 0), 0.0)
	var later := 0
	for i in 15:
		later += c.update_turret(0.1, Vector2.ZERO, Vector2.RIGHT, Vector2(10, 0), 0.0)
	return shots == 1 and later == 1


func _machinegun_bursts() -> bool:
	var c := _chasing(Cyborg.Gun.MACHINEGUN)
	var shots := 0
	for i in 30:
		shots += c.update_turret(0.05, Vector2.ZERO, Vector2.RIGHT, Vector2(10, 0), 0.0)
	return shots == Cyborg.BURST_ROUNDS


func _seen_hiding_is_searched() -> bool:
	var c := _chasing(Cyborg.Gun.CANNON)
	var target := c.think(0.1, Vector2.ZERO, Vector2(12, 0), false)  # stepped into a bush
	var searching := c.state == Cyborg.State.SEARCH and target == Vector2(10, 0)
	c.think(0.1, Vector2(11, 0), Vector2(12, 0), false)
	return searching and c.state == Cyborg.State.CHASE


func _gives_up_after_search() -> bool:
	var c := _chasing(Cyborg.Gun.CANNON)
	c.think(0.1, Vector2.ZERO, Vector2(30, 0), false)
	for i in 100:
		c.think(0.1, Vector2(10, 0), Vector2(30, 0), false)
	return c.state == Cyborg.State.PATROL and c.speed() == Cyborg.PATROL_SPEED


func _hit_makes_it_hunt() -> bool:
	var c := Cyborg.new(Cyborg.Gun.CANNON, 10, 10)
	c.take_hit(1, Vector2(5, 5))
	return c.state == Cyborg.State.SEARCH and c.last_seen == Vector2(5, 5)
