extends RefCounted

## Lasting progress between hunts (section 13): tusks to spend and animals caught alive.
## Plain data in and out (to_dict/from_dict) so the save adapter never sees this class.

const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const QuestBoard = preload("res://game/features/settlement/public/quest_board.gd")

const PEN_MAX := 5

var tusks := 0
## type_id -> animals caught alive and kept in camp.
var caught: Dictionary = {}
## Boars standing in the camp pen, oldest first; a new catch pushes the oldest out (owner, 2026-10-29).
var pen: Array[String] = []
## item_id -> count of bought gear.
var items: Dictionary = {}
## animal_id -> helper animals (rooster, turkey) living in the camp pen (D024).
var helpers: Dictionary = {}
## Hunts finished; 0 means the next hunt is the first and shows hints (section 16).
var hunts := 0
## Helper animal taken on the next hunt ("rooster", "turkey" or "" for the first one in the pen).
var companion := ""
## material id -> forest finds carried to camp (sticks, feathers, berries...), sold at shops (issue #21).
var materials: Dictionary = {}
## The bought hut: its camp slot and its look (one of the five variants, kept for good; issue #22); -1 = none.
var hut_slot := -1
var hut_variant := -1
## Tusks given to building the forge (issue #11).
var forge := 0
## Daily quests on the camp board (issue #25).
var quests := QuestBoard.new()


## Adds a finished hunt's tusks and live catches and takes spent consumables out of stock.
func add_hunt(hunt: Hunt) -> void:
	hunts += 1
	tusks += hunt.tusks()
	for animal_id in hunt.helpers_caught:
		helpers[animal_id] = helpers.get(animal_id, 0) + hunt.helpers_caught[animal_id]
	for item_id in hunt.invasion.loot:  # metal from terminators (issue 8)
		items[item_id] = items.get(item_id, 0) + hunt.invasion.loot[item_id]
	for item_id in hunt.used_items:
		items[item_id] = maxi(0, items.get(item_id, 0) - hunt.used_items[item_id])
	quests.add_hunt(hunt)
	for type_id in hunt.type_ids():
		var alive := hunt.count(type_id, BoarOutcome.Kind.CAPTURED)
		if alive > 0:
			caught[type_id] = caught.get(type_id, 0) + alive
			for i in alive:
				pen.append(type_id)
	pen = pen.slice(maxi(0, pen.size() - PEN_MAX))


## Pays cost tusks; false and no change when there are not enough.
func spend(cost: int) -> bool:
	if cost < 0 or cost > tusks:
		return false
	tusks -= cost
	return true


## Buys one catalog item; false when unknown, already owned (unique), locked or too expensive.
func buy(item_id: String) -> bool:
	var item: Dictionary = ShopCatalog.ITEMS.get(item_id, {})
	if item.has("companion"):
		if not unlocked(item_id):
			return false
		companion = item["companion"]
		return true
	if item.is_empty() or sold_out(item_id) or not unlocked(item_id) or (forge_built() and item.has("donate")) \
			or not spend(ShopCatalog.price(item_id)):
		return false
	if item.has("donate"):
		forge += item["donate"]
		return true
	items[item_id] = mini(items.get(item_id, 0) + item.get("pack", 1), item.get("max", 1 << 30))
	return true


## True when no more of item_id can be bought: a unique item owned, or a stack at its max.
func sold_out(item_id: String) -> bool:
	var item: Dictionary = ShopCatalog.ITEMS.get(item_id, {})
	if item.has("companion"):
		return companion == item["companion"]
	var have: int = items.get(item_id, 0)
	return (item.get("unique", false) and have > 0) or have >= item.get("max", 1 << 30)


## A saddle needs a caught boar of its type in the pens (D021).
func unlocked(item_id: String) -> bool:
	var animal: String = ShopCatalog.ITEMS.get(item_id, {}).get("companion", "")
	if animal != "":
		return helpers.get(animal, 0) > 0
	var needs: String = ShopCatalog.ITEMS.get(item_id, {}).get("requires_caught", "")
	return needs == "" or caught.get(needs, 0) > 0 or ShopCatalog.free_for_testing


func forge_built() -> bool:
	return forge >= ShopCatalog.FORGE_COST


## Sells up to count of a material for 1 tusk per units; only whole tusks' worth goes. Returns tusks earned.
func sell(material_id: String, count: int, units: int) -> int:
	var sold := mini(count, materials.get(material_id, 0)) / units * units
	if sold <= 0:
		return 0
	materials[material_id] -= sold
	tusks += sold / units
	return sold / units


## Pays a claimed quest's reward; gathering quests hand their materials over (issue #25).
func claim_quest(index: int) -> bool:
	var reward := quests.claim(index, materials)
	tusks += reward
	return reward > 0


func owns(item_id: String) -> bool:
	return items.get(item_id, 0) > 0


func to_dict() -> Dictionary:
	return {"tusks": tusks, "caught": caught.duplicate(), "items": items.duplicate(), "helpers": helpers.duplicate(),
		"pen": pen.duplicate(), "hunts": hunts, "kit": true, "companion": companion, "materials": materials.duplicate(),
		"hut_slot": hut_slot, "hut_variant": hut_variant, "forge": forge, "quests": quests.to_dict()}


## Unknown or malformed fields fall back to defaults instead of failing the load.
static func from_dict(data: Dictionary) -> RefCounted:
	var progress := new()
	progress.tusks = maxi(0, int(data.get("tusks", 0)))
	progress.hunts = maxi(0, int(data.get("hunts", 0)))
	progress.caught = _counts(data.get("caught", {}))
	progress.items = _counts(data.get("items", {}))
	var saved_pen: Variant = data.get("pen")
	if saved_pen is Array:
		for type_id in saved_pen:
			progress.pen.append(str(type_id))
	else:  # saves from before the pen list: stand the old catches in it
		for type_id in progress.caught:
			for i in progress.caught[type_id]:
				progress.pen.append(type_id)
	progress.pen = progress.pen.slice(maxi(0, progress.pen.size() - PEN_MAX))
	progress.helpers = _counts(data.get("helpers", {}))
	progress.companion = str(data.get("companion", ""))
	progress.materials = _counts(data.get("materials", {}))
	var slot := int(data.get("hut_slot", -1))
	var variant := int(data.get("hut_variant", -1))
	if slot >= 0 and slot < 6 and variant >= 0 and variant < 5:
		progress.hut_slot = slot
		progress.hut_variant = variant
	progress.forge = maxi(0, int(data.get("forge", 0)))
	var saved_quests: Variant = data.get("quests")
	progress.quests = QuestBoard.from_dict(saved_quests if saved_quests is Dictionary else {})
	# New games, and saves from before ammo became stock, get the starter kit once.
	if not data.get("kit", false):
		for item_id in ShopCatalog.STARTER_KIT:
			progress.items[item_id] = maxi(progress.items.get(item_id, 0), ShopCatalog.STARTER_KIT[item_id])
	return progress


static func _counts(saved: Variant) -> Dictionary:
	var counts := {}
	if saved is Dictionary:
		for key in saved:
			counts[str(key)] = maxi(0, int(saved[key]))
	return counts
