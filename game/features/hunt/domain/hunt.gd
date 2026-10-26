class_name Hunt
extends RefCounted

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")

## type_id -> BoarOutcome.Kind -> count
var _counts: Dictionary = {}


## Callers pass the public outcome; NONE means the boar was never counted.
func record(type_id: String, kind: BoarOutcome.Kind) -> void:
	if kind == BoarOutcome.Kind.NONE:
		return
	var per_type: Dictionary = _counts.get(type_id, {})
	per_type[kind] = per_type.get(kind, 0) + 1
	_counts[type_id] = per_type


func count(type_id: String, kind: BoarOutcome.Kind) -> int:
	return _counts.get(type_id, {}).get(kind, 0)


## rewards: type_id -> {"dead": int, "captured": int}. Missing types pay nothing.
func tusks(rewards: Dictionary) -> int:
	var total := 0
	for type_id in _counts:
		var reward: Dictionary = rewards.get(type_id, {})
		total += count(type_id, BoarOutcome.Kind.DEAD) * reward.get("dead", 0)
		total += count(type_id, BoarOutcome.Kind.CAPTURED) * reward.get("captured", 0)
	return total
