extends RefCounted

## What the hunter carries: spear and nets always, plus weapons bought in camp (M003, M004, D022).

enum Weapon { SPEAR, NET, CLUB, SLING, BOW }

## ASSUMPTION: per hunt, balanced later (D013).
const START_NETS := 3
const START_ARROWS := 12

## Camp item id that unlocks each bought weapon.
const ITEM_IDS := {
	Weapon.CLUB: "item_club",
	Weapon.SLING: "item_sling",
	Weapon.BOW: "item_bow",
}

## Bait item ids, the strongest first: place_bait uses the first one left (ASSUMPTION).
const BAIT_IDS := ["item_apple", "item_carrot", "item_acorns"]

var spear_in_hand := true
var nets := START_NETS
var arrows := START_ARROWS
## item_id -> bait carried this hunt.
var baits: Dictionary = {}
## item_id -> consumables spent this hunt; camp takes them out of stock afterwards.
var used: Dictionary = {}
var _bought: Array[Weapon] = []


## Takes the bought weapons from camp gear (item_id -> count).
func equip(items: Dictionary) -> void:
	_bought.clear()
	for weapon in ITEM_IDS:
		if items.get(ITEM_IDS[weapon], 0) > 0:
			_bought.append(weapon)
	baits.clear()
	for item_id in BAIT_IDS:
		baits[item_id] = items.get(item_id, 0)


func has(weapon: Weapon) -> bool:
	return weapon in [Weapon.SPEAR, Weapon.NET] or weapon in _bought


func throw_spear() -> bool:
	if not spear_in_hand:
		return false
	spear_in_hand = false
	return true


func pick_spear() -> void:
	spear_in_hand = true


func throw_net() -> bool:
	if nets == 0:
		return false
	nets -= 1
	return true


## A net that missed can be picked up again (M004, ASSUMPTION).
func pick_net() -> void:
	nets += 1


## Arrows are spent on release and not picked up (ASSUMPTION); sling stones never run out.
func shoot_arrow() -> bool:
	if not has(Weapon.BOW) or arrows == 0:
		return false
	arrows -= 1
	return true


## Spends the strongest bait left; returns its item id, or "" when out of bait.
func place_bait() -> String:
	for item_id in BAIT_IDS:
		if baits.get(item_id, 0) > 0:
			baits[item_id] -= 1
			used[item_id] = used.get(item_id, 0) + 1
			return item_id
	return ""
