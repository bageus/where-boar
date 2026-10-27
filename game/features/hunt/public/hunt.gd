class_name Hunt
extends RefCounted

## Results of one hunt (M007): outcome counts per boar type and when the hunt is over.

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")

## Tusks per boar type, GAME_SPEC section 15 (ASSUMPTION numbers, D013).
const REWARDS := {
	"common_brown": {"dead": 2, "captured": 4},
	"runner_grey": {"dead": 4, "captured": 7},
	"aggressive_red": {"dead": 6, "captured": 10},
	"armored_black": {"dead": 8, "captured": 14},
	"golden_tusk": {"dead": 10, "captured": 20},
}

## Boars on the map when the hunt started.
var total := 0
var returned := false
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
	return total - _resolved


## The hunt ends when the hunter returns to camp or no free boars are left (section 07).
func is_over() -> bool:
	return returned or remaining() <= 0


## rewards: type_id -> {"dead": int, "captured": int}. Missing types pay nothing.
func tusks(rewards: Dictionary = REWARDS) -> int:
	var total_tusks := 0
	for type_id in _counts:
		var reward: Dictionary = rewards.get(type_id, {})
		total_tusks += count(type_id, BoarOutcome.Kind.DEAD) * reward.get("dead", 0)
		total_tusks += count(type_id, BoarOutcome.Kind.CAPTURED) * reward.get("captured", 0)
	return total_tusks
