class_name BoarSenses
extends RefCounted

const Boar = preload("res://game/features/boar/domain/boar.gd")

## Shout deflection from the straight-away direction, degrees (D018, ASSUMPTION, tune in phase 1).
const SHOUT_ANGLE_DEG := 30.0


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
