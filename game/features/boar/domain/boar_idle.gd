extends RefCounted

## A calm boar's idle routine (owner, 2026-11-01): mostly stands and grazes or rests,
## sometimes walks over to stand beside a herd mate, and only now and then roams.

enum Activity { GRAZE, STAND, JOIN, ROAM }

# ASSUMPTION numbers (D013): [min, max] seconds per activity and how often each is picked.
const SECONDS := {
	Activity.GRAZE: [5.0, 12.0],
	Activity.STAND: [3.0, 7.0],
	Activity.JOIN: [10.0, 10.0],
	Activity.ROAM: [3.0, 7.0],
}
const WEIGHTS := [0.45, 0.2, 0.15, 0.2]
## A joining boar stops this close to its mate, metres.
const MATE_DISTANCE := 1.8

var activity := Activity.GRAZE
var time_left := 0.0


## Starts at a random point of a random activity, so a herd does not move in step.
func _init(roll := randf()) -> void:
	start(pick(roll, false), roll)
	time_left *= roll


## Activity for a roll in [0, 1); JOIN needs a mate, otherwise the boar just stands.
static func pick(roll: float, has_mate: bool) -> Activity:
	var sum := 0.0
	var chosen := Activity.ROAM
	for i in WEIGHTS.size():
		sum += WEIGHTS[i]
		if roll < sum:
			chosen = i as Activity
			break
	if chosen == Activity.JOIN and not has_mate:
		return Activity.STAND
	return chosen


func start(next: Activity, length_roll := randf()) -> void:
	activity = next
	var span: Array = SECONDS[next]
	time_left = lerpf(span[0], span[1], length_roll)


## Counts the current activity down and picks the next one when it runs out; true when it changed.
func tick(delta: float, has_mate: bool, roll := randf()) -> bool:
	time_left -= delta
	if time_left > 0.0:
		return false
	start(pick(roll, has_mate))
	return true


## A joining boar reached its mate: it grazes or stands there for a while.
func arrived(roll := randf()) -> void:
	start(Activity.GRAZE if roll < 0.6 else Activity.STAND)


## Whether the boar stays on the spot in this activity.
func standing() -> bool:
	return activity in [Activity.GRAZE, Activity.STAND]
