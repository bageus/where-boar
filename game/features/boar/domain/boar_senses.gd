class_name BoarSenses
extends RefCounted

const Boar = preload("res://game/features/boar/domain/boar.gd")

## Shout deflection from the straight-away direction, degrees (D018, ASSUMPTION, tune in phase 1).
const SHOUT_ANGLE_DEG := 30.0
## How close a boar comes to bait before it stops to eat, metres.
const EAT_DISTANCE := 1.0


## A calm boar that sees the hunter inside its perception radius starts to flee (M002).
static func perceive(boar: Boar, boar_pos: Vector2, hunter_pos: Vector2, radius: float) -> void:
	if boar_pos.distance_to(hunter_pos) <= radius:
		boar.flee()


## A shout scares a boar but never panics it; it runs away at +-30 degrees (D018).
## side is the sign (+1 or -1) of the deflection, chosen by the caller (random in the scene).
static func shout_heading(boar: Boar, boar_pos: Vector2, shout_pos: Vector2, side: int) -> Vector2:
	boar.flee()
	var away := (boar_pos - shout_pos).normalized()
	return away.rotated(deg_to_rad(SHOUT_ANGLE_DEG) * signf(side))


## Index of the escape zone closest to the boar, or -1 when there are none.
static func nearest_zone(boar_pos: Vector2, zones: Array[Vector2]) -> int:
	var best := -1
	for i in zones.size():
		if best == -1 or boar_pos.distance_squared_to(zones[i]) < boar_pos.distance_squared_to(zones[best]):
			best = i
	return best


## Entering a zone makes a FLEE or PANIC boar escape at once (D011); other states pass by.
static func enter_zone(boar: Boar, boar_pos: Vector2, zone_pos: Vector2, zone_radius: float) -> void:
	if boar_pos.distance_to(zone_pos) <= zone_radius:
		boar.escape()


## Fleeing boar runs away from the hunter, bending toward the nearest escape zone
## unless that zone lies on the hunter's side (then it just keeps fleeing, M002).
static func flee_heading(boar_pos: Vector2, hunter_pos: Vector2, zones: Array[Vector2]) -> Vector2:
	var away := (boar_pos - hunter_pos).normalized()
	var i := nearest_zone(boar_pos, zones)
	if i == -1:
		return away
	var to_zone := (zones[i] - boar_pos).normalized()
	if to_zone.dot(away) < 0.0:
		return away
	return (away + to_zone).normalized()


## Heading along a wall of normal `wall_normal` (XZ), on the side that points towards `toward`.
## Keeps a boar sliding out of a corner instead of pushing into it.
static func slide_heading(wall_normal: Vector2, toward: Vector2) -> Vector2:
	var tangent := Vector2(-wall_normal.y, wall_normal.x)
	return tangent if tangent.dot(toward) >= 0.0 else -tangent


## Index of the nearest bait whose pull radius reaches the boar, or -1 (M011).
## baits hold Vector3(x, z, pull_radius).
static func bait_target(boar_pos: Vector2, baits: Array[Vector3]) -> int:
	var best := -1
	var best_distance := INF
	for i in baits.size():
		var distance := boar_pos.distance_to(Vector2(baits[i].x, baits[i].y))
		if distance <= baits[i].z and distance < best_distance:
			best = i
			best_distance = distance
	return best


## Fear spreads through a herd (M009): a calm boar near a fleeing or panicking herd mate flees too.
static func hear_herd(boar: Boar, boar_pos: Vector2, scared_mates: Array[Vector2], radius: float) -> void:
	for mate in scared_mates:
		if boar_pos.distance_to(mate) <= radius:
			boar.flee()
			return


## A calm herd boar that strays more than spread metres from the herd centre walks back; ZERO otherwise.
static func cohesion_heading(boar_pos: Vector2, centre: Vector2, spread: float) -> Vector2:
	if boar_pos.distance_to(centre) <= spread:
		return Vector2.ZERO
	return (centre - boar_pos).normalized()
