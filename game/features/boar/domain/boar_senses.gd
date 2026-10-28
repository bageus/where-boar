class_name BoarSenses
extends RefCounted

const Boar = preload("res://game/features/boar/domain/boar.gd")

## Shout deflection from the straight-away direction, degrees (D018, ASSUMPTION, tune in phase 1).
const SHOUT_ANGLE_DEG := 30.0
## How close a boar comes to bait before it stops to eat, metres.
const EAT_DISTANCE := 1.0


## Half-angle of a boar's sight; a sneaking hunter outside it (behind the boar) is not seen (ASSUMPTION).
const VIEW_HALF_ANGLE_DEG := 120.0
## A mounted hunter is noticed from further away and boars get alarmed faster, then flee without attacking
## (owner, 2026-10-28; ASSUMPTION).
const MOUNTED_RADIUS_SCALE := 1.5
const MOUNTED_ALARM_RATE_SCALE := 2.0
## A hunter standing this many metres or more above the boar is not noticed at all (owner, 2026-10-28; ASSUMPTION).
const UNNOTICED_HEIGHT := 3.0


## Whether a boar notices the hunter inside its perception radius (M002); BoarAlert turns that into flight.
## A walking hunter is heard anywhere in the radius; a sneaking one only when seen:
## in front of the boar (facing) and not behind cover (sight_clear). One far above it (height_above) goes unnoticed.
static func notices(boar_pos: Vector2, hunter_pos: Vector2, radius: float,
		facing := Vector2.ZERO, sneaking := false, sight_clear := true, height_above := 0.0) -> bool:
	if boar_pos.distance_to(hunter_pos) > radius or height_above >= UNNOTICED_HEIGHT:
		return false
	return not sneaking or (in_view(boar_pos, facing, hunter_pos) and sight_clear)


## True when target lies inside the boar's view cone; a boar with no facing sees all round.
static func in_view(boar_pos: Vector2, facing: Vector2, target: Vector2) -> bool:
	if facing == Vector2.ZERO:
		return true
	return facing.normalized().dot((target - boar_pos).normalized()) >= cos(deg_to_rad(VIEW_HALF_ANGLE_DEG))


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


## Share of a scared herd that breaks off alone; the rest splits into SCATTER_BRANCHES groups (ASSUMPTION).
const LONER_SHARE := 0.2
const SCATTER_BRANCHES := [-45.0, 0.0, 45.0]
const LONER_MIN_DEG := 40.0
const LONER_MAX_DEG := 100.0


## Deflection (radians) a scared boar adds to its flight, so a herd scatters (playtest 2026-10-27):
## boars that roll the same branch run together as a group, loners run off at a wide angle.
## Both rolls are in [0, 1).
static func scatter_angle(split_roll: float, angle_roll: float) -> float:
	if split_roll < LONER_SHARE:
		var side := -1.0 if angle_roll < 0.5 else 1.0
		var spread := fmod(angle_roll * 2.0, 1.0)
		return deg_to_rad(side * lerpf(LONER_MIN_DEG, LONER_MAX_DEG, spread))
	var branch := mini(int(angle_roll * SCATTER_BRANCHES.size()), SCATTER_BRANCHES.size() - 1)
	return deg_to_rad(SCATTER_BRANCHES[branch])


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
