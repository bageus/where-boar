class_name Hunt
extends RefCounted

## Results of one hunt (M007): outcome counts per boar type and when the hunt is over.

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")

## Boars on the map when the hunt started.
var total := 0
var returned := false
## item_id -> consumables (bait, traps) spent during the hunt.
var used_items: Dictionary = {}
## Boars held in traps right now; not free, counted as caught when the hunt ends (M007).
var held := 0
## animal_id -> wild helper animals (rooster, turkey) caught for the camp pen.
var helpers_caught: Dictionary = {}
## type_id -> BoarOutcome.Kind -> count
var _counts: Dictionary = {}
var _resolved := 0


func _init(p_total: int = 0) -> void:
	total = p_total


## Callers pass the public outcome; NONE means the boar was never counted.
func record(type_id: String, kind: BoarOutcome.Kind) -> void:
	if kind == BoarOutcome.Kind.NONE:
		return
	var per_type: Dictionary = _counts.get(type_id, {})
	per_type[kind] = per_type.get(kind, 0) + 1
	_counts[type_id] = per_type
	_resolved += 1


func count(type_id: String, kind: BoarOutcome.Kind) -> int:
	return _counts.get(type_id, {}).get(kind, 0)


## Sum of one outcome over all types.
func count_all(kind: BoarOutcome.Kind) -> int:
	var sum := 0
	for type_id in _counts:
		sum += count(type_id, kind)
	return sum


func type_ids() -> Array:
	return _counts.keys()


## Boars still free on the map.
func remaining() -> int:
	return total - _resolved - held


## Hunt end: every boar still in a trap counts as captured (M007).
func close_traps(held_type_ids: Array) -> void:
	for type_id in held_type_ids:
		held -= 1
		record(type_id, BoarOutcome.Kind.CAPTURED)


## The hunt ends when the hunter returns to camp or no free boars are left (section 07).
func is_over() -> bool:
	return returned or remaining() <= 0


## rewards: type_id -> {"dead": int, "captured": int}. Missing types pay nothing.
## Defaults to the authored boar types' rewards (section 15).
func tusks(rewards: Dictionary = BoarTypes.rewards()) -> int:
	var total_tusks := 0
	for type_id in _counts:
		var reward: Dictionary = rewards.get(type_id, {})
		total_tusks += count(type_id, BoarOutcome.Kind.DEAD) * reward.get("dead", 0)
		total_tusks += count(type_id, BoarOutcome.Kind.CAPTURED) * reward.get("captured", 0)
	return total_tusks
