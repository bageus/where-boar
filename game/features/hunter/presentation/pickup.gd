extends RefCounted

## E takes back the thrown spears, nets, arrows and stones that landed within reach, and stones from piles.

const Landing = preload("res://game/features/hunter/presentation/landing.gd")


## Takes everything in reach (thrown is the hunter's list, emptied of what was taken); returns the
## "+N ..." text to show, "" when nothing was taken.
static func run(hunter: CharacterBody3D, thrown: Array[RigidBody3D]) -> String:
	var loadout = hunter.loadout
	var before := [loadout.spears, loadout.nets, loadout.arrows, loadout.stones]
	for item in thrown.duplicate():
		if item.global_position.distance_to(hunter.global_position) > hunter.PICKUP_RADIUS or not Landing.can_pick(item):
			continue
		match item.pickup_kind:
			"spear":
				loadout.pick_spear(item.kind)
			"net":
				loadout.pick_net()
			"arrow":
				loadout.pick_arrow()
			"stone":
				loadout.pick_stones(1)
		thrown.erase(item)
		item.queue_free()
	# Stone piles lying around the map (owner, 2026-10-27).
	for pile: Node3D in hunter.get_tree().get_nodes_in_group(hunter.GROUND_STONES_GROUP):
		if pile.global_position.distance_to(hunter.global_position) <= hunter.PICKUP_RADIUS:
			loadout.pick_stones(pile.get_meta("stones", 1))
			pile.queue_free()
	var gains := PackedStringArray()
	var after := [loadout.spears, loadout.nets, loadout.arrows, loadout.stones]
	for i in after.size():
		if after[i] > before[i]:
			gains.append("+%d %s" % [after[i] - before[i], ["spear", "net", "arrow", "stone"][i] + ("s" if after[i] - before[i] > 1 else "")])
	return ", ".join(gains)
