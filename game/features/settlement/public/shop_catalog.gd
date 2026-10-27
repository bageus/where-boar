extends RefCounted

## What camp shops sell and for how many tusks (section 13; ASSUMPTION prices, D013).
## unique items (weapons) are bought once; others stack. requires_caught names a boar type that must be in the pens.

const ITEMS := {
	"item_club": {"name": "Club", "shop": "weapon_shop", "price": 30, "unique": true},
	"item_sling": {"name": "Sling", "shop": "weapon_shop", "price": 25, "unique": true},
	"item_bow": {"name": "Bow", "shop": "weapon_shop", "price": 50, "unique": true},
	"item_acorns": {"name": "Acorns (bait)", "shop": "hunting_hut", "price": 5, "unique": false},
	"item_carrot": {"name": "Carrot (bait)", "shop": "hunting_hut", "price": 8, "unique": false},
	"item_apple": {"name": "Apple (bait)", "shop": "hunting_hut", "price": 8, "unique": false},
	"item_pit": {"name": "Leaf pit (trap)", "shop": "hunting_hut", "price": 40, "unique": false},
	"item_snare": {"name": "Snare (trap)", "shop": "hunting_hut", "price": 30, "unique": false},
	"item_tripwire": {"name": "Tripwire (trap)", "shop": "hunting_hut", "price": 30, "unique": false},
	"item_cage": {"name": "Stake cage (trap)", "shop": "hunting_hut", "price": 60, "unique": false},
	"item_fence": {"name": "Fence (trap)", "shop": "hunting_hut", "price": 35, "unique": false},
	"item_water_bag": {"name": "Water bag", "shop": "hunting_hut", "price": 25, "unique": true},
	"item_stew": {"name": "Herb stew (+20 stamina)", "shop": "campfire", "price": 10, "unique": false},
	"item_roast": {"name": "Roast (+35 stamina)", "shop": "campfire", "price": 18, "unique": false},
	"item_feast": {"name": "Feast (+50 stamina)", "shop": "campfire", "price": 25, "unique": false},
	"item_porter": {"name": "Porter (+2 nets, +6 arrows)", "shop": "tavern", "price": 60, "unique": true},
	"item_trap_setter": {"name": "Trap setter (sets 2 traps at escape zones)", "shop": "tavern", "price": 80, "unique": true},
	"item_saddle_runner_grey": {"name": "Saddle a Runner (fast)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "runner_grey"},
	"item_saddle_aggressive_red": {"name": "Saddle an Angry boar (rams)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "aggressive_red"},
	"item_saddle_armored_black": {"name": "Saddle an Armored boar (steady)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "armored_black"},
}


## Item ids sold at shop_id, in catalog order.
static func for_shop(shop_id: String) -> Array[String]:
	var ids: Array[String] = []
	for item_id in ITEMS:
		if ITEMS[item_id]["shop"] == shop_id:
			ids.append(item_id)
	return ids
