class_name BoarDodge
extends RefCounted

## How a fleeing boar dodges a hunter running at it (owner, 2026-11-02). Plain values only, no scene.
## Approached from a side it veers away from that side; met head-on it swerves to a random side;
## chased from straight behind it keeps running and now and then jinks any way; chased from a little to
## one side behind it bends to the other side. Cornered (its escape side walled off) it may turn on the
## hunter, the more likely the bigger and angrier the type; cunning rare types may run at him head-on.

# ASSUMPTION numbers (D013), tune in playtests.
## The hunter presses the boar when within this many metres and closing in at least PRESS_MIN_CLOSING m/s.
const PRESS_RADIUS := 10.0
const PRESS_MIN_CLOSING := 1.0
## Hunter within this angle of the boar's nose: head-on.
const HEAD_ON_DEG := 25.0
## Hunter within this angle of the boar's tail: chased from behind (jinks happen).
const BEHIND_DEG := 30.0
## Share of the remaining angle to "straight away from the hunter" the boar wants to turn.
const AWAY_GAIN := 0.8
## Fastest turn while dodging, radians per second.
const TURN_RATE := 3.0
## Chased from behind: chance per second of a jink, its largest angle, how long it may take.
const JINK_PER_SECOND := 0.4
const JINK_MAX := PI * 0.6
const JINK_SECONDS := 0.8
## Cornered checks: hunter this close, a wall within WALL_LOOK metres at LOOK_ANGLE off the heading
## toward the escape side.
const CORNER_DISTANCE := 6.0
const WALL_LOOK := 3.0
const LOOK_ANGLE := PI / 3.0
## Cornered attack chance: base for a common boar (3 health), per extra health point, per aggression.
const CORNER_BASE := 0.3
const CORNER_PER_HEALTH := 0.08
const CORNER_PER_AGGRESSION := 0.3
const CORNER_MIN := 0.1
const CORNER_MAX := 0.95
## A cornered boar that does not attack cuts this far to the other side, radians.
const CORNER_CUT := PI / 2.0

## Side (+1 or -1) a head-on boar swerves to; rolled when the hunter starts pressing.
var head_on_side := 1
## Side (+1, -1) the boar turned to on the last steer, 0 when it ran straight; the escape side.
var turn_side := 0
var _pressed := false
var _corner_rolled := false
var _cunning_rolled := false
var _jink := 0.0
var _jink_left := 0.0


## True when the hunter is close and running at the boar (hunter_velocity on the XZ plane).
static func pressing(boar_pos: Vector2, hunter_pos: Vector2, hunter_velocity: Vector2) -> bool:
	var to_boar := boar_pos - hunter_pos
	var distance := to_boar.length()
	if distance > PRESS_RADIUS or distance < 0.01:
		return false
	return hunter_velocity.dot(to_boar / distance) >= PRESS_MIN_CLOSING


## Signed angle (radians) from the boar's heading to the hunter: 0 straight ahead, +-PI straight behind.
static func hunter_angle(heading: Vector2, boar_pos: Vector2, hunter_pos: Vector2) -> float:
	return heading.angle_to(hunter_pos - boar_pos)


## Turn the boar wants, radians: away from the hunter's side, larger the more the hunter is in front;
## head-on it takes swerve_side. Zero when the hunter is straight behind.
static func dodge_turn(heading: Vector2, boar_pos: Vector2, hunter_pos: Vector2, swerve_side: int) -> float:
	var rel := hunter_angle(heading, boar_pos, hunter_pos)
	var side := float(swerve_side) if head_on(heading, boar_pos, hunter_pos) else -signf(rel)
	return side * (PI - absf(rel)) * AWAY_GAIN


## True when the hunter is in front of the boar's nose.
static func head_on(heading: Vector2, boar_pos: Vector2, hunter_pos: Vector2) -> bool:
	return absf(hunter_angle(heading, boar_pos, hunter_pos)) < deg_to_rad(HEAD_ON_DEG)


## Chance a cornered boar turns on the hunter: bigger (more health) and angrier types attack more.
static func corner_chance(max_health: int, aggression: float) -> float:
	var chance := CORNER_BASE + CORNER_PER_HEALTH * (max_health - 3) + CORNER_PER_AGGRESSION * aggression
	return clampf(chance, CORNER_MIN, CORNER_MAX)


## Rotates heading toward target by at most max_turn radians.
static func ease_toward(heading: Vector2, target: Vector2, max_turn: float) -> Vector2:
	if heading == Vector2.ZERO:
		return target
	var turn := heading.angle_to(target)
	return heading.rotated(clampf(turn, -max_turn, max_turn))


## The hunter started pressing: a new swerve side and fresh rolls. side_roll in [0, 1).
func press(side_roll: float) -> void:
	_pressed = true
	head_on_side = -1 if side_roll < 0.5 else 1
	_corner_rolled = false
	_cunning_rolled = false
	_jink_left = 0.0


## The hunter stopped pressing.
func release() -> void:
	_pressed = false
	turn_side = 0


func pressed() -> bool:
	return _pressed


## Next heading of a pressed boar. jink_roll and angle_roll are in [0, 1).
func steer(delta: float, heading: Vector2, boar_pos: Vector2, hunter_pos: Vector2, jink_roll: float, angle_roll: float) -> Vector2:
	var turn := dodge_turn(heading, boar_pos, hunter_pos, head_on_side)
	_jink_left -= delta
	var behind := absf(hunter_angle(heading, boar_pos, hunter_pos)) > PI - deg_to_rad(BEHIND_DEG)
	if behind and _jink_left <= 0.0 and jink_roll < JINK_PER_SECOND * delta:
		_jink = lerpf(-JINK_MAX, JINK_MAX, angle_roll)
		_jink_left = JINK_SECONDS
	if _jink_left > 0.0 and absf(_jink) > 0.01:
		turn = _jink
	var step := clampf(turn, -TURN_RATE * delta, TURN_RATE * delta)
	if _jink_left > 0.0:
		_jink -= step
	turn_side = int(signf(turn)) if absf(turn) > 0.05 else 0
	return heading.rotated(step)


## Rolls once per press whether the boar turns on the hunter: when its escape side is walled off
## (corner_odds), or, for a cunning type, when met head-on (cunning_odds). A cornered boar that does not
## attack dodges to the other side instead. roll is in [0, 1).
func turns_on_hunter(blocked: bool, head_on: bool, roll: float, corner_odds: float, cunning_odds: float) -> bool:
	if blocked and not _corner_rolled:
		_corner_rolled = true
		if roll < corner_odds:
			return true
		_jink = -turn_side * CORNER_CUT
		_jink_left = JINK_SECONDS
	if head_on and not _cunning_rolled and cunning_odds > 0.0:
		_cunning_rolled = true
		return roll < cunning_odds
	return false
