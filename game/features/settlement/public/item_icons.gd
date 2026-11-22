extends RefCounted

## Inventory icons (owner atlases cut by tools/slice_icons.py). Baits use their catalog icon.

const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")

const DIR := "res://assets/icon/items/"
## item id (or animal id) -> file in DIR.
const FILES := {
	"item_spear": "spear", "item_spear_bone": "spear", "item_spear_wood": "spear", "item_net": "net", "item_club": "club",
	"item_sling": "sling", "item_bow": "bow", "item_knife": "knife", "item_arrow": "arrow", "item_stone": "stone",
	"rooster": "rooster", "turkey": "turkey", "tusk": "tusk",
	"item_metal_tusk": "metal_tusk", "item_metal_plate": "metal_plate", "item_component": "component",
}


## The icon of item_id, or null when it has none (traps, water, food).
static func of(item_id: String) -> Texture2D:
	var path: String = ShopCatalog.ITEMS.get(item_id, {}).get("icon", "")
	if path == "" and FILES.has(item_id):
		path = DIR + FILES[item_id] + ".png"
	return load(path) if path != "" else null


## "[img]" for a RichTextLabel, empty when item_id has no icon.
static func bbcode(item_id: String, size := 28) -> String:
	var icon := of(item_id)
	return "[img=%d]%s[/img]" % [size, icon.resource_path] if icon else ""
