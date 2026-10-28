extends RefCounted

## The five MVP boar types (D022), the owner's rare variants (P3-025) and rarity-weighted picks.

const BoarType = preload("res://game/features/boar/public/boar_type.gd")

const ALL: Array[BoarType] = [
	preload("res://game/features/boar/content/boar_common_brown.tres"),
	preload("res://game/features/boar/content/boar_runner_grey.tres"),
	preload("res://game/features/boar/content/boar_aggressive_red.tres"),
	preload("res://game/features/boar/content/boar_armored_black.tres"),
	preload("res://game/features/boar/content/boar_bone.tres"),
	preload("res://game/features/boar/content/boar_bun.tres"),
	preload("res://game/features/boar/content/boar_bubble.tres"),
	preload("res://game/features/boar/content/boar_mohawk.tres"),
	preload("res://game/features/boar/content/boar_dachshund.tres"),
	preload("res://game/features/boar/content/boar_camo.tres"),
	preload("res://game/features/boar/content/boar_hairy.tres"),
	preload("res://game/features/boar/content/boar_tiny.tres"),
	preload("res://game/features/boar/content/boar_golden_tusk.tres"),
]


## Picks a type by spawn weight; roll is uniform in [0, 1).
static func pick(roll: float) -> BoarType:
	var total := 0.0
	for type in ALL:
		total += type.spawn_weight
	var left := roll * total
	for type in ALL:
		left -= type.spawn_weight
		if left < 0.0:
			return type
	return ALL[-1]


static func find(id: String) -> BoarType:
	for type in ALL:
		if type.id == id:
			return type
	push_error("Unknown boar type: " + id)
	return null


## type id -> {"dead": tusks, "captured": tusks}, the shape Hunt.tusks expects.
static func rewards() -> Dictionary:
	var table := {}
	for type in ALL:
		# A wounded boar caught alive pays halfway between killed and whole (playtest 2026-10-27).
		table[type.id] = {"dead": type.reward_dead, "captured": type.reward_captured,
				"wounded": (type.reward_dead + type.reward_captured) / 2}
	return table
