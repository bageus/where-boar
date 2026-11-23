extends RefCounted

## Terminator invasion (owner, issue 8): from the 11th hunt on, killing the herd leader or 30-40 boars
## calls 2-30 terminators down in teleport eggs; catching the leader alive calls them off for the hunt.
## Each terminator killed drops metal tusks, plates and components (kept as camp items).

const MIN_HUNTS := 10
const KILLS_MIN := 30
const KILLS_MAX := 40
const COUNT_MIN := 2
const COUNT_MAX := 30
## ASSUMPTION: the most terminators grows by this many per hunt past the 10th, up to COUNT_MAX.
const COUNT_STEP := 2
## ASSUMPTION: loot per terminator killed.
const LOOT := {"item_metal_tusk": 2, "item_metal_plate": 2, "item_component": 1}

## False before the 11th hunt: no terminators at all.
var allowed := false
var kill_target := 0
## Terminators that come when the invasion starts.
var size := 0
var started := false
var leader_caught := false
var kills := 0
## Terminators still on the map.
var left := 0
## Terminators killed this hunt (clan rating, issue #27).
var killed := 0
## item_id -> count dropped by killed terminators.
var loot: Dictionary = {}


## hunts_done: hunts finished before this one. Rolls are uniform in [0, 1).
func _init(hunts_done: int = 0, kills_roll: float = 0.0, size_roll: float = 0.0) -> void:
	allowed = hunts_done >= MIN_HUNTS
	kill_target = KILLS_MIN + mini(int(kills_roll * (KILLS_MAX - KILLS_MIN + 1)), KILLS_MAX - KILLS_MIN)
	var most := mini(COUNT_MAX, COUNT_MIN + (hunts_done - MIN_HUNTS + 1) * COUNT_STEP)
	size = COUNT_MIN + mini(int(size_roll * (most - COUNT_MIN + 1)), most - COUNT_MIN) if allowed else 0


## A boar's hunt ended (kind: BoarOutcome.Kind). True when this starts the invasion.
func record_boar(dead: bool, captured: bool, leader: bool) -> bool:
	if leader and captured:
		leader_caught = true
	if dead:
		kills += 1
	if started or not allowed or leader_caught or not dead or not (leader or kills >= kill_target):
		return false
	started = true
	left = size
	return true


## A terminator is gone; killed ones drop their loot.
func record_terminator(was_killed: bool) -> void:
	left = maxi(0, left - 1)
	if was_killed:
		self.killed += 1
		for item_id in LOOT:
			loot[item_id] = loot.get(item_id, 0) + LOOT[item_id]
