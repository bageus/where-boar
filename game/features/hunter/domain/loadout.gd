extends RefCounted

## What the hunter carries: spear and nets always, plus weapons bought in camp (M003, M004, D022).

enum Weapon { SPEAR, NET, CLUB, SLING, BOW, KNIFE }

## ASSUMPTION: per hunt, balanced later (D013).
const START_NETS := 3
const START_ARROWS := 12
## Sling stones in the pouch at hunt start; more lie around the map (owner, 2026-10-27, ASSUMPTION count).
const START_STONES := 5
## Every hunter carries one spear; extra spears bought in the armory raise it to 3 at most (owner, 2026-10-27).
const SPEAR_ID := "item_spear"
const MAX_SPEARS := 3

## Camp item id that unlocks each bought weapon.
const ITEM_IDS := {
	Weapon.CLUB: "item_club",
	Weapon.SLING: "item_sling",
	Weapon.BOW: "item_bow",
}

## Bait item ids, the strongest first: place_bait uses the first one left (ASSUMPTION).
const BAIT_IDS := ["item_apple", "item_carrot", "item_acorns"]

## Trap item ids in the order G cycles through them (M015).
const TRAP_IDS := ["item_pit", "item_snare", "item_tripwire", "item_cage", "item_fence"]

## Camp meals and their stamina bonus; all carried meals are eaten at hunt start (M012, ASSUMPTION).
const MEALS := {"item_feast": 50.0, "item_roast": 35.0, "item_stew": 20.0}
const WATER_BAG_ID := "item_water_bag"
## Sips per hunt; the bag is refilled free in camp (ASSUMPTION).
const WATER_SIPS := 3
## A hired porter carries extra nets and arrows (M013, ASSUMPTION).
const PORTER_ID := "item_porter"
const PORTER_NETS := 2
const PORTER_ARROWS := 6
## Camp item "item_saddle_<boar type id>" puts a saddle on a caught boar of that type.
const SADDLE_PREFIX := "item_saddle_"

## Spears carried right now; thrown ones are picked up again.
var spears := 1
var max_spears := 1
var spear_in_hand: bool:
	get:
		return spears > 0
var nets := START_NETS
var arrows := START_ARROWS
var stones := START_STONES
## item_id -> bait carried this hunt.
var baits: Dictionary = {}
## item_id -> consumables spent this hunt; camp takes them out of stock afterwards.
var used: Dictionary = {}
## item_id -> traps carried this hunt.
var traps: Dictionary = {}
## Index into TRAP_IDS of the trap T places.
var trap_index := 0
var water_sips := 0
var _meals: Dictionary = {}
## Boar type ids with a saddle bought in camp (D021).
var saddled: Array[String] = []
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
	traps.clear()
	for item_id in TRAP_IDS:
		traps[item_id] = items.get(item_id, 0)
	_meals.clear()
	for item_id in MEALS:
		_meals[item_id] = items.get(item_id, 0)
	water_sips = WATER_SIPS if items.get(WATER_BAG_ID, 0) > 0 else 0
	saddled.clear()
	for item_id in items:
		if item_id.begins_with(SADDLE_PREFIX) and items[item_id] > 0:
			saddled.append(item_id.trim_prefix(SADDLE_PREFIX))
	max_spears = mini(1 + items.get(SPEAR_ID, 0), MAX_SPEARS)
	spears = max_spears
	var porter: bool = items.get(PORTER_ID, 0) > 0
	nets = START_NETS + (PORTER_NETS if porter else 0)
	# Every hunt starts fully armed again: whatever was thrown and left behind comes back in camp.
	arrows = START_ARROWS + (PORTER_ARROWS if porter else 0)
	stones = START_STONES


func has(weapon: Weapon) -> bool:
	# The knife is never lost: the one weapon left when everything else is thrown away (owner, 2026-10-27).
	return weapon in [Weapon.SPEAR, Weapon.NET, Weapon.KNIFE] or weapon in _bought


func throw_spear() -> bool:
	if spears == 0:
		return false
	spears -= 1
	return true


func pick_spear() -> void:
	spears = mini(spears + 1, max_spears)


func throw_net() -> bool:
	if nets == 0:
		return false
	nets -= 1
	return true


## A net that missed can be picked up again (M004, ASSUMPTION).
func pick_net() -> void:
	nets += 1


## An arrow that missed, or was taken out of a dead or caught boar.
func pick_arrow() -> void:
	arrows += 1


func pick_stones(count: int) -> void:
	stones += count


func sling_stone() -> bool:
	if not has(Weapon.SLING) or stones == 0:
		return false
	stones -= 1
	return true


## Arrows are spent on release and picked up again like spears.
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


## Selects the next trap type.
func cycle_trap() -> void:
	trap_index = (trap_index + 1) % TRAP_IDS.size()


func selected_trap() -> String:
	return TRAP_IDS[trap_index]


## Spends the selected trap; returns its item id, or "" when none is left.
func place_trap() -> String:
	return _spend_trap(selected_trap())


## Spends the first trap in stock, any type; for the trap setter (M013).
func place_any_trap() -> String:
	for item_id in TRAP_IDS:
		if traps.get(item_id, 0) > 0:
			return _spend_trap(item_id)
	return ""


func _spend_trap(item_id: String) -> String:
	if traps.get(item_id, 0) == 0:
		return ""
	traps[item_id] -= 1
	used[item_id] = used.get(item_id, 0) + 1
	return item_id


## Eats the best meal in stock before a hunt; returns its stamina bonus, 0 without one.
## Eats every camp meal carried; their bonuses stack for the whole hunt (owner, 2026-10-27).
func eat_meals() -> float:
	var bonus := 0.0
	for item_id in MEALS:
		bonus += MEALS[item_id] * _meals[item_id]
		if _meals[item_id] > 0:
			used[item_id] = used.get(item_id, 0) + _meals[item_id]
		_meals[item_id] = 0
	return bonus


func drink() -> bool:
	if water_sips == 0:
		return false
	water_sips -= 1
	return true
