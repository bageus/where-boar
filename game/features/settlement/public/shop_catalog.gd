extends RefCounted

## What camp shops sell and for how many tusks (section 13; ASSUMPTION prices, D013).
## unique items (weapons) are bought once; others stack, up to max when given; pack is how many one
## purchase adds (default 1).
## requires_caught names a boar type that must be in the pens.

## shortcut: everything in camp is free and unlocked while the owner tests the slice (2026-10-27);
## set to false (or delete) before balancing prices.
static var free_for_testing := true

const ITEMS := {
	"item_club": {"name": "Club", "shop": "weapon_shop", "price": 30, "unique": true},
	"item_sling": {"name": "Sling", "shop": "weapon_shop", "price": 25, "unique": true},
	"item_bow": {"name": "Bow", "shop": "weapon_shop", "price": 50, "unique": true},
	# Ammo is stock that is lost when left on the map (owner, 2026-10-27); prices ASSUMPTION (D013).
	"item_spear": {"name": "Spear", "shop": "weapon_shop", "price": 15, "unique": false, "max": 3},
	"item_net": {"name": "Net", "shop": "weapon_shop", "price": 10, "unique": false, "max": 5},
	"item_arrow": {"name": "Arrows (x6)", "shop": "weapon_shop", "price": 6, "unique": false, "max": 24, "pack": 6},
	"item_stone": {"name": "Sling stones (x5)", "shop": "weapon_shop", "price": 2, "unique": false, "max": 20, "pack": 5},
	"item_acorns": {"name": "Acorns (bait)", "shop": "hunting_hut", "price": 5, "unique": false, "icon": "res://assets/icon/bait/acorns.png"},
	"item_red_berries": {"name": "Red berries (bait)", "shop": "hunting_hut", "price": 6, "unique": false, "icon": "res://assets/icon/bait/red_berries.png"},
	"item_blueberries": {"name": "Blueberries (bait)", "shop": "hunting_hut", "price": 6, "unique": false, "icon": "res://assets/icon/bait/blueberries.png"},
	"item_apple": {"name": "Apple (bait)", "shop": "hunting_hut", "price": 8, "unique": false, "icon": "res://assets/icon/bait/apple.png"},
	"item_pear": {"name": "Pear (bait)", "shop": "hunting_hut", "price": 8, "unique": false, "icon": "res://assets/icon/bait/pear.png"},
	"item_bananas": {"name": "Bananas (bait)", "shop": "hunting_hut", "price": 10, "unique": false, "icon": "res://assets/icon/bait/bananas.png"},
	"item_mandarin": {"name": "Mandarin (bait)", "shop": "hunting_hut", "price": 10, "unique": false, "icon": "res://assets/icon/bait/mandarin.png"},
	"item_mango": {"name": "Mango (bait)", "shop": "hunting_hut", "price": 12, "unique": false, "icon": "res://assets/icon/bait/mango.png"},
	"item_mixed_berries": {"name": "Mixed berries (bait)", "shop": "hunting_hut", "price": 14, "unique": false, "icon": "res://assets/icon/bait/mixed_berries.png"},
	"item_pit": {"name": "Leaf pit (trap)", "shop": "hunting_hut", "price": 40, "unique": false},
	"item_snare": {"name": "Snare (trap)", "shop": "hunting_hut", "price": 30, "unique": false},
	"item_tripwire": {"name": "Tripwire (trap)", "shop": "hunting_hut", "price": 30, "unique": false},
	"item_cage": {"name": "Stake cage (trap)", "shop": "hunting_hut", "price": 60, "unique": false},
	"item_fence": {"name": "Fence (trap)", "shop": "hunting_hut", "price": 35, "unique": false},
	"item_water_bag": {"name": "Water bag", "shop": "hunting_hut", "price": 25, "unique": true},
	"item_water": {"name": "Water (3 sips, needs the bag)", "shop": "well", "price": 0, "unique": false, "max": 3, "pack": 3},
	"item_stew": {"name": "Herb stew (+20 stamina)", "shop": "campfire", "price": 10, "unique": false},
	"item_roast": {"name": "Roast (+35 stamina)", "shop": "campfire", "price": 18, "unique": false},
	"item_feast": {"name": "Feast (+50 stamina)", "shop": "campfire", "price": 25, "unique": false},
	"item_porter": {"name": "Porter (carries +2 nets, +6 arrows)", "shop": "tavern", "price": 60, "unique": true},
	"item_trap_setter": {"name": "Trap setter (sets 2 traps at escape zones)", "shop": "tavern", "price": 80, "unique": true},
	# Pick which helper animal goes on the next hunt (owner, 2026-10-27); free, needs one in the pen.
	"item_take_rooster": {"name": "Take the rooster on the hunt", "shop": "cages", "price": 0, "unique": true, "companion": "rooster"},
	"item_take_turkey": {"name": "Take the turkey on the hunt", "shop": "cages", "price": 0, "unique": true, "companion": "turkey"},
	"item_saddle_runner_grey": {"name": "Saddle a Runner (fast)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "runner_grey"},
	"item_saddle_aggressive_red": {"name": "Saddle an Angry boar (rams)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "aggressive_red"},
	"item_saddle_armored_black": {"name": "Saddle an Armored boar (steady)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "armored_black"},
}


## What a new game starts with in stock: one spear, three nets, five sling stones (owner, 2026-10-27).
const STARTER_KIT := {"item_spear": 1, "item_net": 3, "item_stone": 5}


## What item_id costs right now.
static func price(item_id: String) -> int:
	return 0 if free_for_testing else ITEMS[item_id]["price"]


## Item ids sold at shop_id, in catalog order.
static func for_shop(shop_id: String) -> Array[String]:
	var ids: Array[String] = []
	for item_id in ITEMS:
		if ITEMS[item_id]["shop"] == shop_id:
			ids.append(item_id)
	return ids
