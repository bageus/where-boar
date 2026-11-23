extends RefCounted

## The tavern crew on a hunt (M013, issue #12): the trap setter builds every trap ghost, the warrior
## fights, the healer heals. Only one is hired at a time; the first found goes.

const HIRES := {
	"item_trap_setter": preload("res://game/features/hunter/presentation/trap_setter.gd"),
	"item_warrior": preload("res://game/features/hunter/presentation/warrior.gd"),
	"item_healer": preload("res://game/features/hunter/presentation/healer.gd"),
}


static func bring(hunter: CharacterBody3D, items: Dictionary) -> void:
	for item_id in HIRES:
		if items.get(item_id, 0) > 0:
			var mate: Node3D = HIRES[item_id].new()
			mate.hunter = hunter
			mate.top_level = true
			hunter.add_child(mate)
			mate.global_position = hunter.ground_at(hunter.global_position + hunter.global_basis.x * 2.0)
			return
