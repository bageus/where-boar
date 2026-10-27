extends RefCounted

## Lasting progress between hunts (section 13): tusks to spend and animals caught alive.
## Plain data in and out (to_dict/from_dict) so the save adapter never sees this class.

const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")

var tusks := 0
## type_id -> animals caught alive and kept in camp.
var caught: Dictionary = {}
## item_id -> count of bought gear.
var items: Dictionary = {}


## Adds a finished hunt's tusks and live catches and takes spent consumables out of stock.
func add_hunt(hunt: Hunt) -> void:
	tusks += hunt.tusks()
	for item_id in hunt.used_items:
		items[item_id] = maxi(0, items.get(item_id, 0) - hunt.used_items[item_id])
	for type_id in hunt.type_ids():
		var alive := hunt.count(type_id, BoarOutcome.Kind.CAPTURED)
		if alive > 0:
			caught[type_id] = caught.get(type_id, 0) + alive


## Pays cost tusks; false and no change when there are not enough.
func spend(cost: int) -> bool:
	if cost < 0 or cost > tusks:
		return false
	tusks -= cost
	return true


## Buys one catalog item; false when unknown, already owned (unique) or too expensive.
func buy(item_id: String) -> bool:
	var item: Dictionary = ShopCatalog.ITEMS.get(item_id, {})
	if item.is_empty() or (item["unique"] and owns(item_id)) or not spend(item["price"]):
		return false
	items[item_id] = items.get(item_id, 0) + 1
	return true


func owns(item_id: String) -> bool:
	return items.get(item_id, 0) > 0


func to_dict() -> Dictionary:
	return {"tusks": tusks, "caught": caught.duplicate(), "items": items.duplicate()}


## Unknown or malformed fields fall back to defaults instead of failing the load.
static func from_dict(data: Dictionary) -> RefCounted:
	var progress := new()
	progress.tusks = maxi(0, int(data.get("tusks", 0)))
	progress.caught = _counts(data.get("caught", {}))
	progress.items = _counts(data.get("items", {}))
	return progress


static func _counts(saved: Variant) -> Dictionary:
	var counts := {}
	if saved is Dictionary:
		for key in saved:
			counts[str(key)] = maxi(0, int(saved[key]))
	return counts
