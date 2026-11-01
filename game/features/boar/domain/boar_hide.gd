extends RefCounted

## A fleeing boar may duck into tall grass (owner, 2026-11-01): it runs into a patch close by, stands
## there hidden for a while with no fear mark, then calms down and walks out to roam again.
## A hunter coming too close flushes it out and it runs on.

enum Phase { NONE, SEEK, HIDDEN }
enum Result { KEEP, CALMED, FLUSHED, GAVE_UP }

# ASSUMPTION numbers (D013).
## Share of flights in which the boar hides if it passes tall grass.
const CHANCE := 0.5
## Tall grass this close (to the patch edge) is worth running into, metres.
const SEEK_RADIUS := 12.0
## Deep enough once within this share of the patch radius from its centre.
const INSIDE_SHARE := 0.5
## Gives up and runs on if it has not got in by then.
const SEEK_SECONDS := 6.0
## [min, max] seconds it stays hidden before it calms down.
const HIDDEN_SECONDS := [8.0, 15.0]
## A hunter this close flushes a hidden boar out, metres.
const FLUSH_DISTANCE := 4.0

var phase := Phase.NONE
## Patch centre (XZ) and radius of the grass picked in this flight; radius 0 while none.
var spot := Vector2.ZERO
var radius := 0.0
var time_left := 0.0
var _wants := false


## A new flight starts: rolls whether the boar will hide this time.
func start_flight(roll := randf()) -> void:
	phase = Phase.NONE
	radius = 0.0
	_wants = roll < CHANCE


## The flight is over or broken (hit, shout): no hiding for the rest of it.
func stop() -> void:
	phase = Phase.NONE
	_wants = false


## Nearest tall grass as Vector3(x, z, radius), radius 0 when there is none; true when the boar heads for it.
func consider(pos: Vector2, patch: Vector3) -> bool:
	if not wants() or patch.z <= 0.0:
		return false
	if pos.distance_to(Vector2(patch.x, patch.y)) - patch.z > SEEK_RADIUS:
		return false
	phase = Phase.SEEK
	spot = Vector2(patch.x, patch.y)
	radius = patch.z
	time_left = SEEK_SECONDS
	return true


func tick(delta: float, pos: Vector2, hunter_distance: float, length_roll := randf()) -> Result:
	match phase:
		Phase.SEEK:
			if pos.distance_to(spot) <= radius * INSIDE_SHARE:
				phase = Phase.HIDDEN
				time_left = lerpf(HIDDEN_SECONDS[0], HIDDEN_SECONDS[1], length_roll)
				return Result.KEEP
			time_left -= delta
			if time_left <= 0.0:
				stop()
				return Result.GAVE_UP
		Phase.HIDDEN:
			if hunter_distance < FLUSH_DISTANCE:
				stop()
				return Result.FLUSHED
			time_left -= delta
			if time_left <= 0.0:
				stop()
				return Result.CALMED
	return Result.KEEP


## Still looking for tall grass in this flight.
func wants() -> bool:
	return _wants and phase == Phase.NONE


func active() -> bool:
	return phase != Phase.NONE


func hidden() -> bool:
	return phase == Phase.HIDDEN


## Where the boar runs while seeking; it stands still once hidden.
func heading(pos: Vector2) -> Vector2:
	return (spot - pos).normalized() if phase == Phase.SEEK else Vector2.ZERO
