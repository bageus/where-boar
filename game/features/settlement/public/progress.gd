extends RefCounted

## Lasting progress between hunts (section 13): tusks to spend and animals caught alive.
## Plain data in and out (to_dict/from_dict) so the save adapter never sees this class.

const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const QuestBoard = preload("res://game/features/settlement/public/quest_board.gd")
const Clan = preload("res://game/features/settlement/public/clan.gd")
const Trophies = preload("res://game/features/settlement/public/trophies.gd")

const PEN_MAX := 5
const SADDLE := "item_saddle_"

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
## Saddled boar type ridden on the next hunt ("" for the first saddle bought; issue #16).
var mount := ""
## Slotted item_id -> count packed for the hunt (issue #15); the rest of items stays in the gear box.
var carried: Dictionary = {}
## material id -> forest finds carried to camp (sticks, feathers, berries...), sold at shops (issue #21).
var materials: Dictionary = {}
## The bought hut: its camp slot and its look (one of the five variants, kept for good; issue #22); -1 = none.
var hut_slot := -1
var hut_variant := -1
## Tusks given to building the forge (issue #11).
var forge := 0
## Daily quests on the camp board (issue #25).
var quests := QuestBoard.new()
## The hunter's clan, null until founded at the totem (issue #27).
var clan: Clan = null
## trophy id -> count won on hunts (issue #19); last_trophies are the last hunt's, for the results.
var trophies: Dictionary = {}
var last_trophies: Array[String] = []
## Unix time the shaman's blessing wears off (issue #20).
var blessed_until := 0
## Beauty hut (issue #18): paint target ("hut", "mount") -> colour id, and colour id -> units of paint bought.
var paint: Dictionary = {}
var paints: Dictionary = {}


## Adds a finished hunt's tusks, live catches and forest finds and takes spent consumables out of stock.
## rng rolls the hunt's trophies (issue #19). A gathering trip keeps its finds but is not counted as a hunt.
func add_hunt(hunt: Hunt, rng := RandomNumberGenerator.new()) -> void:
	hunts += 0 if hunt.gathering else 1
	var earned := hunt.count_all(BoarOutcome.Kind.DEAD) + hunt.count_all(BoarOutcome.Kind.CAPTURED) > 0
	last_trophies = Trophies.roll(earned, rng)
	for trophy_id in last_trophies:
		trophies[trophy_id] = trophies.get(trophy_id, 0) + 1
	tusks += hunt.tusks()
	for animal_id in hunt.helpers_caught:
		helpers[animal_id] = helpers.get(animal_id, 0) + hunt.helpers_caught[animal_id]
	for item_id in hunt.invasion.loot:  # metal from terminators (issue 8)
		items[item_id] = items.get(item_id, 0) + hunt.invasion.loot[item_id]
	for material_id in hunt.gathered:
		materials[material_id] = materials.get(material_id, 0) + hunt.gathered[material_id]
	for item_id in hunt.used_items:
		items[item_id] = maxi(0, items.get(item_id, 0) - hunt.used_items[item_id])
	_fit_carried()
	quests.add_hunt(hunt)
	if clan:
		clan.add_hunt(hunt)
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
	if item.has("companion") or item.has("mount"):
		if not unlocked(item_id):
			return false
		if item.has("mount"):
			mount = item["mount"]
		else:
			companion = item["companion"]
		return true
	if item.is_empty() or sold_out(item_id) or not unlocked(item_id) or (forge_built() and item.has("donate")) \
			or not has_parts(item_id) or not spend(ShopCatalog.price(item_id)):
		return false
	var parts := ShopCatalog.parts(item_id)
	for part_id in parts:
		items[part_id] -= parts[part_id]
	if item.has("donate"):
		forge += item["donate"]
		return true
	if item.get("crew", false):  # one crewman per hunt (issue #12)
		for other in ShopCatalog.ITEMS:
			if ShopCatalog.ITEMS[other].get("crew", false):
				items.erase(other)
	items[item_id] = mini(items.get(item_id, 0) + item.get("pack", 1), item.get("max", 1 << 30))
	if item_id == "item_clan_tent":  # the hut became the tent: a clan leader owns no hut and cannot buy one
		items.erase("item_hut")
		hut_slot = -1
		hut_variant = -1
	carry(item_id)  # new gear goes straight into the pack while it fits
	return true


## True when no more of item_id can be bought: a unique item owned, or a stack at its max.
func sold_out(item_id: String) -> bool:
	var item: Dictionary = ShopCatalog.ITEMS.get(item_id, {})
	if item.has("companion"):
		return companion == item["companion"]
	if item.has("mount"):
		return riding() == item["mount"]
	var have: int = items.get(item_id, 0)
	return (item.get("unique", false) and have > 0) or have >= item.get("max", 1 << 30)


## Buys a pack of a paid colour (issue #18); white and black are free and never run out.
func buy_paint(color_id: String) -> bool:
	if not ShopCatalog.PAINTS.has(color_id) or ShopCatalog.PAINTS[color_id]["price"] == 0 \
			or not spend(ShopCatalog.price_of_paint(color_id)):
		return false
	paints[color_id] = paints.get(color_id, 0) + ShopCatalog.PAINT_PACK
	return true


## Paints a target, spending one unit of a paid colour; false when out of it.
func paint_target(target: String, color_id: String) -> bool:
	if target not in ShopCatalog.PAINT_TARGETS or not ShopCatalog.PAINTS.has(color_id):
		return false
	if ShopCatalog.PAINTS[color_id]["price"] > 0:
		if paints.get(color_id, 0) <= 0:
			return false
		paints[color_id] -= 1
	paint[target] = color_id
	return true


## Founding a clan takes the hut and its clan tent upgrade and a name (issue #27); false and no clan otherwise.
func found_clan(clan_name: String) -> bool:
	if clan or clan_name.strip_edges() == "" or not owns("item_clan_tent"):
		return false
	clan = Clan.new()
	clan.name = clan_name.strip_edges()
	return true


## True when the stock holds every part a forge recipe takes.
func has_parts(item_id: String) -> bool:
	var parts := ShopCatalog.parts(item_id)
	for part_id in parts:
		if items.get(part_id, 0) < parts[part_id]:
			return false
	return true


## A saddle needs a caught boar of its type in the pens (D021); a forge recipe needs the forge built.
func unlocked(item_id: String) -> bool:
	if item_id == "item_hut" and owns("item_clan_tent"):
		return false
	if ShopCatalog.ITEMS.get(item_id, {}).has("parts"):
		return forge_built()
	if ShopCatalog.ITEMS.get(item_id, {}).has("requires_item"):
		return owns(ShopCatalog.ITEMS[item_id]["requires_item"])
	var animal: String = ShopCatalog.ITEMS.get(item_id, {}).get("companion", "")
	if animal != "":
		return helpers.get(animal, 0) > 0
	var ride: String = ShopCatalog.ITEMS.get(item_id, {}).get("mount", "")
	if ride != "":
		return owns(SADDLE + ride)
	var needs: String = ShopCatalog.ITEMS.get(item_id, {}).get("requires_caught", "")
	return needs == "" or caught.get(needs, 0) > 0 or ShopCatalog.free_for_testing


func forge_built() -> bool:
	return forge >= ShopCatalog.FORGE_COST


## Sells up to count of a material (or bird, or bait) for pay tusks per units; only whole lots go.
## Returns tusks earned.
@warning_ignore("integer_division")
func sell(material_id: String, count: int, units: int, pay := 1) -> int:
	var bin := stock(material_id)
	var sold := mini(count, bin.get(material_id, 0)) / units * units
	if sold <= 0:
		return 0
	bin[material_id] -= sold
	_fit_carried()
	tusks += sold / units * pay
	return sold / units * pay


## Where a sellable id is kept: caught birds in the cages, catalog items in gear, the rest in forest finds.
func stock(id: String) -> Dictionary:
	if id in ShopCatalog.BIRD_IDS:
		return helpers
	return items if ShopCatalog.ITEMS.has(id) else materials


## Boar type ridden on the next hunt: the picked one while its saddle is owned, else the first saddle.
func riding() -> String:
	if mount != "" and owns(SADDLE + mount):
		return mount
	for item_id in items:
		if item_id.begins_with(SADDLE) and items[item_id] > 0:
			return item_id.trim_prefix(SADDLE)
	return ""


## A hired helper (porter or any tavern crewman) doubles the baits and traps taken (issue #15).
func helped() -> bool:
	return owns("item_porter") or ShopCatalog.ITEMS.keys().any(func(id: String) -> bool: return ShopCatalog.ITEMS[id].get("crew", false) and owns(id))


func slot_cap(slot: String) -> int:
	return ShopCatalog.HELPER_SLOTS.get(slot, ShopCatalog.SLOTS[slot]) if helped() else ShopCatalog.SLOTS[slot]


## Room used in a slot: pieces for baits and traps, kinds for the rest (all spears are one kind).
func slot_used(slot: String) -> int:
	var kinds := {}
	var pieces := 0
	for item_id in carried:
		var item: Dictionary = ShopCatalog.ITEMS[item_id]
		if item["slot"] == slot:
			pieces += carried[item_id]
			kinds[item.get("group", item_id)] = true
	return pieces if slot in ["bait", "trap"] else kinds.size()


## Left in the gear box (owned, not packed).
func in_box(item_id: String) -> int:
	return items.get(item_id, 0) - carried.get(item_id, 0)


## Packs item_id from the box: one bait or trap, or the whole stack of a weapon. Returns how many moved.
func carry(item_id: String) -> int:
	var slot: String = ShopCatalog.ITEMS.get(item_id, {}).get("slot", "")
	if slot == "" or in_box(item_id) <= 0:
		return 0
	var item: Dictionary = ShopCatalog.ITEMS[item_id]
	var group: String = item.get("group", item_id)
	var kind_packed := carried.keys().any(func(id: String) -> bool: return ShopCatalog.ITEMS[id].get("group", id) == group)
	var moved := 0
	if slot in ["bait", "trap"]:
		moved = 1 if slot_used(slot) < slot_cap(slot) else 0
	elif kind_packed or slot_used(slot) < slot_cap(slot):
		moved = in_box(item_id)
	if moved > 0:
		carried[item_id] = carried.get(item_id, 0) + moved
	return moved


## Puts item_id back into the box: one bait or trap, or the whole stack of a weapon.
func store(item_id: String) -> void:
	var have: int = carried.get(item_id, 0)
	if have <= 0:
		return
	var slot: String = ShopCatalog.ITEMS[item_id]["slot"]
	carried[item_id] = have - 1 if slot in ["bait", "trap"] else 0
	if carried[item_id] == 0:
		carried.erase(item_id)


## Gear the next hunt takes: slotted items only as packed, and only the ridden boar's saddle.
func hunt_items() -> Dictionary:
	var taken := {}
	for item_id in items:
		if ShopCatalog.ITEMS.get(item_id, {}).has("slot"):
			taken[item_id] = carried.get(item_id, 0)
		elif not item_id.begins_with(SADDLE) or item_id == SADDLE + riding():
			taken[item_id] = items[item_id]
	return taken


## Packs everything that fits, in catalog order (new games and saves from before the gear box).
func pack_all() -> void:
	for item_id in ShopCatalog.ITEMS:
		while carry(item_id) > 0:
			pass


## Spent or sold gear leaves the pack too.
func _fit_carried() -> void:
	for item_id in carried.keys():
		carried[item_id] = mini(carried[item_id], items.get(item_id, 0))
		if carried[item_id] <= 0:
			carried.erase(item_id)


## Pays a claimed quest's reward; gathering quests hand their materials over (issue #25).
func claim_quest(index: int) -> bool:
	var reward := quests.claim(index, materials)
	tusks += reward
	return reward > 0


## Names of the hired tavern team (porter and crewman), shown at the bottom of the tavern (issue #12).
func team() -> PackedStringArray:
	var names := PackedStringArray()
	for item_id in ShopCatalog.for_shop("tavern"):
		if owns(item_id):
			names.append(ShopCatalog.ITEMS[item_id]["name"].get_slice(" (", 0))
	return names


func owns(item_id: String) -> bool:
	return items.get(item_id, 0) > 0


func to_dict() -> Dictionary:
	return {"tusks": tusks, "caught": caught.duplicate(), "items": items.duplicate(), "helpers": helpers.duplicate(),
		"pen": pen.duplicate(), "hunts": hunts, "kit": true, "companion": companion, "mount": mount,
		"carried": carried.duplicate(), "materials": materials.duplicate(),
		"hut_slot": hut_slot, "hut_variant": hut_variant, "forge": forge, "quests": quests.to_dict(),
		"clan": clan.to_dict() if clan else {}, "trophies": trophies.duplicate(), "blessed_until": blessed_until,
		"paint": paint.duplicate(), "paints": paints.duplicate()}


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
	progress.mount = str(data.get("mount", ""))
	progress.materials = _counts(data.get("materials", {}))
	var slot := int(data.get("hut_slot", -1))
	var variant := int(data.get("hut_variant", -1))
	if slot >= 0 and slot < 6 and variant >= 0 and variant < 5:
		progress.hut_slot = slot
		progress.hut_variant = variant
	progress.forge = maxi(0, int(data.get("forge", 0)))
	var saved_quests: Variant = data.get("quests")
	progress.quests = QuestBoard.from_dict(saved_quests if saved_quests is Dictionary else {})
	var saved_clan: Variant = data.get("clan")
	progress.clan = Clan.from_dict(saved_clan if saved_clan is Dictionary else {})
	progress.trophies = _counts(data.get("trophies", {}))
	progress.blessed_until = maxi(0, int(data.get("blessed_until", 0)))
	progress.paints = _counts(data.get("paints", {}))
	var saved_paint: Variant = data.get("paint")
	if saved_paint is Dictionary:
		for target in saved_paint:
			if ShopCatalog.PAINTS.has(str(saved_paint[target])):
				progress.paint[str(target)] = str(saved_paint[target])
	# New games, and saves from before ammo became stock, get the starter kit once.
	if not data.get("kit", false):
		for item_id in ShopCatalog.STARTER_KIT:
			progress.items[item_id] = maxi(progress.items.get(item_id, 0), ShopCatalog.STARTER_KIT[item_id])
	if data.get("carried") is Dictionary:
		var saved := _counts(data["carried"])
		for item_id in saved:
			if ShopCatalog.ITEMS.get(item_id, {}).has("slot"):
				progress.carried[item_id] = saved[item_id]
		progress._fit_carried()
	else:
		progress.pack_all()
	return progress


static func _counts(saved: Variant) -> Dictionary:
	var counts := {}
	if saved is Dictionary:
		for key in saved:
			counts[str(key)] = maxi(0, int(saved[key]))
	return counts
