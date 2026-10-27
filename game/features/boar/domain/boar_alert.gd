extends RefCounted

## How alarmed a calm boar is (playtest 2026-10-27): 1 heard something, 2 wary, 3 alarmed (flees or attacks).
## Noticing the hunter raises the level, faster the closer he is; each level fades after a quiet cooldown.

## ASSUMPTION numbers (D013), tuned by playtest.
const STAGE_SECONDS := 1.0
const COOLDOWN_SECONDS := 3.0
const MAX_LEVEL := 3
## Closeness (perception radius / distance) is capped so a stage never passes in under STAGE_SECONDS / 4.
const MAX_CLOSENESS := 4.0

var progress := 0.0
var _quiet := 0.0


func level() -> int:
	return mini(int(progress), MAX_LEVEL)


## noticed: the boar senses the hunter this tick; closeness: perception radius / distance.
func tick(delta: float, noticed: bool, closeness: float) -> void:
	if noticed:
		_quiet = 0.0
		progress = minf(MAX_LEVEL, progress + delta / STAGE_SECONDS * clampf(closeness, 1.0, MAX_CLOSENESS))
		return
	_quiet += delta
	if _quiet >= COOLDOWN_SECONDS and progress > 0.0:
		_quiet = 0.0
		progress = maxf(0.0, level() - 1.0)


func alarmed() -> bool:
	return level() >= MAX_LEVEL


## Hit, shout or a scared herd mate: straight to alarmed.
func alarm() -> void:
	progress = MAX_LEVEL
	_quiet = 0.0


## A herd mate was quietly caught nearby (owner, 2026-10-27): the first time the boar turns wary,
## a second time while its alert has not faded out yet it is alarmed. Returns true when it should run.
func witness_capture() -> bool:
	if level() >= 1:
		alarm()
		return true
	progress = MAX_LEVEL - 1.0
	_quiet = 0.0
	return false


## After a flight ends the boar stays wary for a while.
func settle() -> void:
	progress = MAX_LEVEL - 1.0
	_quiet = 0.0
