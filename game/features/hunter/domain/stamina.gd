extends RefCounted

## Hunter stamina: sprint and lunge spend it, anything else restores it (M001).
## Numbers are ASSUMPTION (D013), balanced in phase 2.

const MAX := 100.0
const SPRINT_COST := 20.0
const LUNGE_COST := 25.0
const REGEN := 15.0
## After running dry, sprint stays locked until stamina is back to this value.
const RECOVER_AT := 20.0

## MAX plus the meal eaten before the hunt (M012).
var max_value := MAX
var value := MAX
var _exhausted := false


## Advances stamina by delta seconds and returns whether the hunter sprints this tick.
func tick(delta: float, wants_sprint: bool) -> bool:
	if wants_sprint and not _exhausted:
		value = maxf(0.0, value - SPRINT_COST * delta)
		_exhausted = value == 0.0
		return true
	value = minf(max_value, value + REGEN * delta)
	if value >= RECOVER_AT:
		_exhausted = false
	return false


## Spends stamina for a lunge; false when there is not enough.
func try_lunge() -> bool:
	if _exhausted or value < LUNGE_COST:
		return false
	value -= LUNGE_COST
	return true


## A camp meal raises the maximum for this hunt and starts it full (M012).
func eat(bonus: float) -> void:
	max_value = MAX + bonus
	value = max_value


## A sip from the water bag restores stamina at once, even mid-sprint (M012).
func drink(amount: float) -> void:
	value = minf(max_value, value + amount)
	if value >= RECOVER_AT:
		_exhausted = false
