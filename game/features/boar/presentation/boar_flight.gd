extends RefCounted

## Steers a fleeing or panicking boar (owner, 2026-11-02): eases toward its flight heading, and while the
## hunter runs at it, dodges by BoarDodge and checks for a wall on its escape side.

const BoarDodge = preload("res://game/features/boar/domain/boar_dodge.gd")
const Surroundings = preload("res://game/features/boar/presentation/boar_surroundings.gd")

## Turn rate toward the flight heading when not pressed, radians per second (ASSUMPTION).
const EASE_TURN_RATE := 6.0

var dodge := BoarDodge.new()
## Set by heading() when the boar decided to turn on the hunter this frame.
var turned_on := false


## Heading for this frame. away: the plain flight heading (away from the hunter, zone, scatter).
func heading(body: CharacterBody3D, delta: float, current: Vector2, pos: Vector2, hunter_pos: Vector2,
		away: Vector2, eye_rise: float) -> Vector2:
	turned_on = false
	var hunter_velocity = body.hunter.get("velocity")
	var closing := Vector2(hunter_velocity.x, hunter_velocity.z) if hunter_velocity is Vector3 else Vector2.ZERO
	if not BoarDodge.pressing(pos, hunter_pos, closing):
		dodge.release()
		return BoarDodge.ease_toward(current, away, EASE_TURN_RATE * delta)
	if not dodge.pressed():
		dodge.press(randf())
	var start := current if current != Vector2.ZERO else away
	var next := dodge.steer(delta, start, pos, hunter_pos, randf(), randf())
	var blocked := dodge.turn_side != 0 and pos.distance_to(hunter_pos) <= BoarDodge.CORNER_DISTANCE \
			and Surroundings.wall_toward(body, next.rotated(dodge.turn_side * BoarDodge.LOOK_ANGLE), BoarDodge.WALL_LOOK, eye_rise)
	var kind = body.boar_type
	turned_on = dodge.turns_on_hunter(blocked, BoarDodge.head_on(next, pos, hunter_pos), randf(),
			BoarDodge.corner_chance(kind.max_health, kind.aggression), kind.cunning)
	return next
