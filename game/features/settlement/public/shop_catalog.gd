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
	"item_spear_bone": {"name": "Bone spear", "shop": "weapon_shop", "price": 10, "unique": false, "max": 3},
	"item_spear_wood": {"name": "Wooden spear", "shop": "weapon_shop", "price": 4, "unique": false, "max": 3},
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
	# Only one of the crew goes on a hunt (issue #12): hiring one sends the other home.
	"item_trap_setter": {"name": "Trap setter (sets 2 traps at escape zones)", "shop": "tavern", "price": 80, "unique": true, "crew": true},
	"item_warrior": {"name": "Warrior (attacks boars with you)", "shop": "tavern", "price": 100, "unique": true, "crew": true},
	"item_healer": {"name": "Healer (heals you when you walk up to him)", "shop": "tavern", "price": 90, "unique": true, "crew": true},
	# Pick which helper animal goes on the next hunt (owner, 2026-10-27); free, needs one in the pen.
	"item_take_rooster": {"name": "Take the rooster on the hunt", "shop": "cages", "price": 0, "unique": true, "companion": "rooster"},
	"item_take_turkey": {"name": "Take the turkey on the hunt", "shop": "cages", "price": 0, "unique": true, "companion": "turkey"},
	"item_saddle_runner_grey": {"name": "Saddle a Runner (fast)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "runner_grey"},
	"item_saddle_aggressive_red": {"name": "Saddle an Angry boar (rams)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "aggressive_red"},
	"item_saddle_armored_black": {"name": "Saddle an Armored boar (steady)", "shop": "pens", "price": 50, "unique": true, "requires_caught": "armored_black"},
	# A hut of one's own (issue #22); the clan tent upgrade comes with clans.
	"item_hut": {"name": "Buy this hut", "shop": "hut", "price": 3000, "unique": true},
	# The forge is built from everyone's gifts (issue #11): each purchase gives its price to the build.
	"item_forge_100": {"name": "Give to the forge", "shop": "forge", "price": 100, "unique": false, "donate": 100},
	"item_forge_1000": {"name": "Give to the forge", "shop": "forge", "price": 1000, "unique": false, "donate": 1000},
	"item_forge_10000": {"name": "Give to the forge", "shop": "forge", "price": 10000, "unique": false, "donate": 10000},
	# Forge recipes (issue #11): open once the forge is built; parts are terminator metal (issue 8).
	# Costs ASSUMPTION (D013): a terminator drops 2 metal tusks, 2 plates and 1 component.
	"item_armor": {"name": "Armor (takes 200 damage)", "shop": "forge", "tab": "Armor", "price": 2000, "unique": true,
		"parts": {"item_metal_plate": 20, "item_component": 5, "item_metal_tusk": 10}},
	"item_armor_shock": {"name": "Shock armor (takes 300 damage, no knockback)", "shop": "forge", "tab": "Armor", "price": 5000,
		"unique": true, "parts": {"item_metal_plate": 40, "item_component": 15, "item_metal_tusk": 20}},
	"item_stun_sling": {"name": "Stun sling (a spark stuns for 5 s)", "shop": "forge", "tab": "Weapons", "price": 4000, "unique": true,
		"parts": {"item_metal_plate": 10, "item_component": 20, "item_metal_tusk": 10}},
	"item_spear_thrower": {"name": "Spear thrower (shoots spears)", "shop": "forge", "tab": "Weapons", "price": 6000, "unique": true,
		"parts": {"item_metal_plate": 30, "item_component": 20, "item_metal_tusk": 30}},
	"item_booster": {"name": "Booster (speed builds up while running)", "shop": "forge", "tab": "Upgrades", "price": 3000, "unique": true,
		"parts": {"item_metal_plate": 10, "item_component": 15, "item_metal_tusk": 10}},
	"item_jump": {"name": "Jumper (long jumps)", "shop": "forge", "tab": "Upgrades", "price": 3000, "unique": true,
		"parts": {"item_metal_plate": 10, "item_component": 15, "item_metal_tusk": 10}},
	"item_war_cry": {"name": "War cry (boars stand stunned 10 s, terminators up to 3 s)", "shop": "forge", "tab": "Upgrades",
		"price": 5000, "unique": true, "parts": {"item_metal_plate": 10, "item_component": 25, "item_metal_tusk": 20}},
	"item_ram_shield": {"name": "Ram shield (run into boars to knock them back)", "shop": "forge", "tab": "Upgrades", "price": 5000,
		"unique": true, "parts": {"item_metal_plate": 30, "item_component": 10, "item_metal_tusk": 20}},
}

## Forge recipe tabs, in order (issue #11).
const FORGE_TABS: Array[String] = ["Armor", "Weapons", "Upgrades"]
const PART_NAMES := {"item_metal_tusk": "metal tusks", "item_metal_plate": "metal plates", "item_component": "components"}

## Tusks the forge needs before it opens (issue #11).
const FORGE_COST := 100000

## What each camp shop buys from the forest (issues #18, #21, #28): material id -> units for one tusk.
const SELL := {
	"weapon_shop": {"stone": 12, "feather": 12},
	"campfire": {"stick": 12, "mushroom": 10},
	"beauty_hut": {"berry": 10, "daisy": 10},
	"shaman_hut": {"poison_berry": 6, "larva": 4, "frog": 6},
	"pens": {"grass": 12, "mushroom": 10},
}
const MATERIAL_NAMES := {
	"stone": "Stones", "feather": "Feathers", "stick": "Sticks", "mushroom": "Mushrooms", "berry": "Berries",
	"daisy": "Daisies", "poison_berry": "Poisonous berries", "larva": "Larvae", "frog": "Frogs", "grass": "Grass",
}


## What a new game starts with in stock: one spear, three nets, five sling stones (owner, 2026-10-27).
const STARTER_KIT := {"item_spear": 1, "item_net": 3, "item_stone": 5}


## What item_id costs right now.
static func price(item_id: String) -> int:
	return 0 if free_for_testing else ITEMS[item_id]["price"]


## Parts item_id takes right now (nothing while testing, like the price).
static func parts(item_id: String) -> Dictionary:
	return {} if free_for_testing else ITEMS[item_id].get("parts", {})


## Item ids sold at shop_id, in catalog order.
static func for_shop(shop_id: String) -> Array[String]:
	var ids: Array[String] = []
	for item_id in ITEMS:
		if ITEMS[item_id]["shop"] == shop_id:
			ids.append(item_id)
	return ids
