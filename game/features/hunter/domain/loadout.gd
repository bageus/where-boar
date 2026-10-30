extends RefCounted

## What the hunter carries: the knife always, plus weapons and ammo from camp stock (M003, M004, D022).

enum Weapon { SPEAR, NET, CLUB, SLING, BOW, KNIFE }

# Ammo is camp stock (owner, 2026-10-27): the hunter takes up to the carry cap, and whatever is
# left on the map is gone; camp buys more. Caps are ASSUMPTION (D013).
const SPEAR_ID := "item_spear"
const NET_ID := "item_net"
const ARROW_ID := "item_arrow"
const STONE_ID := "item_stone"
const WATER_ID := "item_water"
const MAX_SPEARS := 3
const NET_CAP := 3
const ARROW_CAP := 12
const STONE_CAP := 10

## Camp item id that unlocks each bought weapon.
const ITEM_IDS := {
	Weapon.CLUB: "item_club",
	Weapon.SLING: "item_sling",
	Weapon.BOW: "item_bow",
}

## Bait item ids, the strongest first; the first one in stock starts active (ASSUMPTION).
const BAIT_IDS := ["item_mixed_berries", "item_mango", "item_bananas", "item_mandarin", "item_pear", "item_apple", "item_blueberries", "item_red_berries", "item_acorns"]

## Trap item ids in the order the trap menu shows them (M015).
const TRAP_IDS := ["item_pit", "item_snare", "item_tripwire", "item_cage", "item_fence"]

## Camp meals and their stamina bonus; one of each kind is eaten at hunt start (M012, ASSUMPTION).
const MEALS := {"item_feast": 50.0, "item_roast": 35.0, "item_stew": 20.0}
const WATER_BAG_ID := "item_water_bag"
## Sips the bag holds; unused water stays in camp stock (owner, 2026-10-27).
const WATER_SIPS := 3
## A hired porter carries more nets and arrows (M013, ASSUMPTION).
const PORTER_ID := "item_porter"
const PORTER_NETS := 2
const PORTER_ARROWS := 6
## Camp item "item_saddle_<boar type id>" puts a saddle on a caught boar of that type.
const SADDLE_PREFIX := "item_saddle_"

## Spears carried right now; thrown ones are picked up again.
var spears := 1
var max_spears := MAX_SPEARS
var spear_in_hand: bool:
	get:
		return spears > 0
var nets := 0
var arrows := 0
var stones := 0
## Carry caps this hunt (the porter raises nets and arrows).
var net_cap := NET_CAP
var arrow_cap := ARROW_CAP
var stone_cap := STONE_CAP
## item_id -> bait carried this hunt.
var baits: Dictionary = {}
## item_id -> consumables spent this hunt; camp takes them out of stock afterwards.
var used: Dictionary = {}
## item_id -> traps carried this hunt.
var traps: Dictionary = {}
## Active bait and trap (F and T place them; holding the key opens a menu to pick another).
var bait_id: String = BAIT_IDS[0]
var trap_id: String = TRAP_IDS[0]
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
	bait_id = _first_in_stock(BAIT_IDS, baits)
	trap_id = _first_in_stock(TRAP_IDS, traps)
	_meals.clear()
	for item_id in MEALS:
		_meals[item_id] = items.get(item_id, 0)
	water_sips = mini(items.get(WATER_ID, 0), WATER_SIPS) if items.get(WATER_BAG_ID, 0) > 0 else 0
	saddled.clear()
	for item_id in items:
		if item_id.begins_with(SADDLE_PREFIX) and items[item_id] > 0:
			saddled.append(item_id.trim_prefix(SADDLE_PREFIX))
	var porter: bool = items.get(PORTER_ID, 0) > 0
	net_cap = NET_CAP + (PORTER_NETS if porter else 0)
	arrow_cap = ARROW_CAP + (PORTER_ARROWS if porter else 0)
	spears = mini(items.get(SPEAR_ID, 0), MAX_SPEARS)
	nets = mini(items.get(NET_ID, 0), net_cap)
	arrows = mini(items.get(ARROW_ID, 0), arrow_cap)
	stones = mini(items.get(STONE_ID, 0), stone_cap)


func has(weapon: Weapon) -> bool:
	# The knife is never lost: the one weapon left when everything else is thrown away (owner, 2026-10-27).
	return weapon in [Weapon.SPEAR, Weapon.NET, Weapon.KNIFE] or weapon in _bought


func throw_spear() -> bool:
	if spears == 0:
		return false
	spears -= 1
	_count(SPEAR_ID, 1)
	return true


func pick_spear() -> void:
	var gain := mini(1, MAX_SPEARS - spears)
	spears += gain
	_count(SPEAR_ID, -gain)


func throw_net() -> bool:
	if nets == 0:
		return false
	nets -= 1
	_count(NET_ID, 1)
	return true


## A net that missed, or was taken off a caught boar (M004).
func pick_net() -> void:
	var gain := mini(1, net_cap - nets)
	nets += gain
	_count(NET_ID, -gain)


## An arrow that missed, or was taken out of a dead or caught boar.
func pick_arrow() -> void:
	var gain := mini(1, arrow_cap - arrows)
	arrows += gain
	_count(ARROW_ID, -gain)


## Stones picked up; found ones add to camp stock after the hunt, up to the pouch cap.
func pick_stones(count: int) -> void:
	var gain := mini(count, stone_cap - stones)
	stones += gain
	_count(STONE_ID, -gain)


func sling_stone() -> bool:
	if not has(Weapon.SLING) or stones == 0:
		return false
	stones -= 1
	_count(STONE_ID, 1)
	return true


## Net change of camp stock: spent counts up, recovered or found counts down (below 0 adds to stock).
func _count(item_id: String, spent: int) -> void:
	used[item_id] = used.get(item_id, 0) + spent
	if used[item_id] == 0:
		used.erase(item_id)


## Arrows are spent on release and picked up again like spears.
func shoot_arrow() -> bool:
	if not has(Weapon.BOW) or arrows == 0:
		return false
	arrows -= 1
	_count(ARROW_ID, 1)
	return true


## Spends the active bait, or the strongest one left when it ran out (and makes that one active);
## returns its item id, or "" when out of bait.
func place_bait() -> String:
	if baits.get(bait_id, 0) == 0:
		bait_id = _first_in_stock(BAIT_IDS, baits)
	if baits.get(bait_id, 0) == 0:
		return ""
	baits[bait_id] -= 1
	used[bait_id] = used.get(bait_id, 0) + 1
	return bait_id


## Spends the active trap, or the first one left when it ran out; returns its item id, or "" when none is left.
func place_trap() -> String:
	if traps.get(trap_id, 0) == 0:
		trap_id = _first_in_stock(TRAP_IDS, traps)
	return _spend_trap(trap_id)


## The first id with stock, else the first id.
static func _first_in_stock(ids: Array, stock: Dictionary) -> String:
	for item_id in ids:
		if stock.get(item_id, 0) > 0:
			return item_id
	return ids[0]


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


## Eats one of each meal kind carried; different meals stack, the same one does not (owner, 2026-10-27).
func eat_meals() -> float:
	var bonus := 0.0
	for item_id in MEALS:
		if _meals[item_id] > 0:
			bonus += MEALS[item_id]
			used[item_id] = used.get(item_id, 0) + 1
		_meals[item_id] = 0
	return bonus


func drink() -> bool:
	if water_sips == 0:
		return false
	water_sips -= 1
	_count(WATER_ID, 1)
	return true
