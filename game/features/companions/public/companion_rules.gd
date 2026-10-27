extends RefCounted

## Pure rules for helper animals (M016, M017).

const ROOSTER := "rooster"
const TURKEY := "turkey"
## How far behind the herd, seen from the hunter, the rooster lands; ASSUMPTION (D013).
const DRIVE_DISTANCE := 8.0
## How long the turkey's marks stay on the minimap, seconds; ASSUMPTION (D013).
const SCOUT_SECONDS := 20.0


## Where the rooster lands: on the far side of the herd from the hunter, so its crow drives the herd at the hunter.
static func drive_point(herd_centre: Vector2, hunter_pos: Vector2) -> Vector2:
	var behind := herd_centre - hunter_pos
	if behind == Vector2.ZERO:
		behind = Vector2.UP
	return herd_centre + behind.normalized() * DRIVE_DISTANCE


## Centre of the free boars nearest to the hunter's chosen spot: the group within radius of the closest boar.
static func target_group_centre(boars: Array[Vector2], hunter_pos: Vector2, radius: float) -> Vector2:
	if boars.is_empty():
		return hunter_pos
	var nearest := boars[0]
	for spot in boars:
		if spot.distance_to(hunter_pos) < nearest.distance_to(hunter_pos):
			nearest = spot
	var sum := Vector2.ZERO
	var n := 0
	for spot in boars:
		if spot.distance_to(nearest) <= radius:
			sum += spot
			n += 1
	return sum / n
