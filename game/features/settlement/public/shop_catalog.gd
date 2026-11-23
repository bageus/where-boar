extends RefCounted

## What camp shops sell and for how many tusks (section 13; ASSUMPTION prices, D013).
## unique items (weapons) are bought once; others stack, up to max when given; pack is how many one
## purchase adds (default 1).
## requires_caught names a boar type that must be in the pens; requires_item an item that must be owned.

## shortcut: everything in camp is free and unlocked while the owner tests the slice (2026-10-27);
## set to false (or delete) before balancing prices.
static var free_for_testing := true

const ITEMS := {
	"item_club": {"name": "Club", "shop": "weapon_shop", "price": 30, "unique": true, "slot": "main"},
	"item_sling": {"name": "Sling", "shop": "weapon_shop", "price": 25, "unique": true, "slot": "weapon"},
	"item_bow": {"name": "Bow", "shop": "weapon_shop", "price": 50, "unique": true, "slot": "weapon"},
	# Ammo is stock that is lost when left on the map (owner, 2026-10-27); prices ASSUMPTION (D013).
	"item_spear": {"name": "Spear", "shop": "weapon_shop", "price": 15, "unique": false, "max": 3, "slot": "weapon", "group": "spear"},
	"item_spear_bone": {"name": "Bone spear", "shop": "weapon_shop", "price": 10, "unique": false, "max": 3, "slot": "weapon", "group": "spear"},
	"item_spear_wood": {"name": "Wooden spear", "shop": "weapon_shop", "price": 4, "unique": false, "max": 3, "slot": "weapon", "group": "spear"},
	"item_net": {"name": "Net", "shop": "weapon_shop", "price": 10, "unique": false, "max": 5, "slot": "weapon"},
	"item_arrow": {"name": "Arrows (x6)", "shop": "weapon_shop", "price": 6, "unique": false, "max": 24, "pack": 6},
	"item_stone": {"name": "Sling stones (x5)", "shop": "weapon_shop", "price": 2, "unique": false, "max": 20, "pack": 5},
	"item_acorns": {"name": "Acorns (bait)", "shop": "hunting_hut", "price": 5, "unique": false, "icon": "res://assets/icon/bait/acorns.png", "slot": "bait", "tab": "Baits"},
	"item_red_berries": {"name": "Red berries (bait)", "shop": "hunting_hut", "price": 6, "unique": false, "icon": "res://assets/icon/bait/red_berries.png", "slot": "bait", "tab": "Baits"},
	"item_blueberries": {"name": "Blueberries (bait)", "shop": "hunting_hut", "price": 6, "unique": false, "icon": "res://assets/icon/bait/blueberries.png", "slot": "bait", "tab": "Baits"},
	"item_apple": {"name": "Apple (bait)", "shop": "hunting_hut", "price": 8, "unique": false, "icon": "res://assets/icon/bait/apple.png", "slot": "bait", "tab": "Baits"},
	"item_pear": {"name": "Pear (bait)", "shop": "hunting_hut", "price": 8, "unique": false, "icon": "res://assets/icon/bait/pear.png", "slot": "bait", "tab": "Baits"},
	"item_bananas": {"name": "Bananas (bait)", "shop": "hunting_hut", "price": 10, "unique": false, "icon": "res://assets/icon/bait/bananas.png", "slot": "bait", "tab": "Baits"},
	"item_mandarin": {"name": "Mandarin (bait)", "shop": "hunting_hut", "price": 10, "unique": false, "icon": "res://assets/icon/bait/mandarin.png", "slot": "bait", "tab": "Baits"},
	"item_mango": {"name": "Mango (bait)", "shop": "hunting_hut", "price": 12, "unique": false, "icon": "res://assets/icon/bait/mango.png", "slot": "bait", "tab": "Baits"},
	"item_mixed_berries": {"name": "Mixed berries (bait)", "shop": "hunting_hut", "price": 14, "unique": false, "icon": "res://assets/icon/bait/mixed_berries.png", "slot": "bait", "tab": "Baits"},
	"item_pit": {"name": "Leaf pit (trap)", "shop": "hunting_hut", "price": 40, "unique": false, "slot": "trap", "tab": "Traps"},
	"item_snare": {"name": "Snare (trap)", "shop": "hunting_hut", "price": 30, "unique": false, "slot": "trap", "tab": "Traps"},
	"item_tripwire": {"name": "Tripwire (trap)", "shop": "hunting_hut", "price": 30, "unique": false, "slot": "trap", "tab": "Traps"},
	"item_cage": {"name": "Stake cage (trap)", "shop": "hunting_hut", "price": 60, "unique": false, "slot": "trap", "tab": "Traps"},
	"item_fence": {"name": "Fence (trap)", "shop": "hunting_hut", "price": 35, "unique": false, "slot": "trap", "tab": "Traps"},
	"item_water_bag": {"name": "Water bag", "shop": "hunting_hut", "price": 25, "unique": true, "tab": "Other"},
	"item_water": {"name": "Water (3 sips, needs the bag)", "shop": "well", "price": 0, "unique": false, "max": 3, "pack": 3},
	"item_stew": {"name": "Herb stew (+20 stamina, +10 health)", "shop": "campfire", "price": 10, "unique": false},
	"item_roast": {"name": "Roast (+35 stamina, +20 health)", "shop": "campfire", "price": 18, "unique": false},
	"item_feast": {"name": "Feast (+50 stamina, +30 health)", "shop": "campfire", "price": 25, "unique": false},
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
	# Which saddled boar is ridden on the next hunt (issue #16); free, needs its saddle.
	"item_ride_runner_grey": {"name": "Ride the Runner", "shop": "pens", "price": 0, "unique": true, "mount": "runner_grey"},
	"item_ride_aggressive_red": {"name": "Ride the Angry boar", "shop": "pens", "price": 0, "unique": true, "mount": "aggressive_red"},
	"item_ride_armored_black": {"name": "Ride the Armored boar", "shop": "pens", "price": 0, "unique": true, "mount": "armored_black"},
	# Private hunts from the signpost need it, for every player (issue #24); bought on its private tab.
	"item_team_pass": {"name": "Team pass", "shop": "signpost", "price": 2000, "unique": true},
	# A hut of one's own (issue #22); its clan tent upgrade lets the owner found a clan (issue #27).
	"item_hut": {"name": "Buy this hut", "shop": "hut", "price": 3000, "unique": true},
	"item_clan_tent": {"name": "Upgrade the hut: clan tent", "shop": "hut", "price": 5000, "unique": true, "requires_item": "item_hut"},
	# The forge is built from everyone's gifts (issue #11): each purchase gives its price to the build.
	"item_forge_100": {"name": "Give to the forge", "shop": "forge", "price": 100, "unique": false, "donate": 100},
	"item_forge_1000": {"name": "Give to the forge", "shop": "forge", "price": 1000, "unique": false, "donate": 1000},
	"item_forge_10000": {"name": "Give to the forge", "shop": "forge", "price": 10000, "unique": false, "donate": 10000},
	# Forge recipes (issue #11): open once the forge is built; parts are terminator metal (issue 8).
	# Costs ASSUMPTION (D013): a terminator drops 2 metal tusks, 2 plates and 1 component.
	"item_armor": {"slot": "armor", "name": "Armor (takes 200 damage)", "shop": "forge", "tab": "Armor", "price": 2000, "unique": true,
		"parts": {"item_metal_plate": 20, "item_component": 5, "item_metal_tusk": 10}},
	"item_armor_shock": {"slot": "armor", "name": "Shock armor (takes 300 damage, no knockback)", "shop": "forge", "tab": "Armor", "price": 5000,
		"unique": true, "parts": {"item_metal_plate": 40, "item_component": 15, "item_metal_tusk": 20}},
	"item_stun_sling": {"slot": "weapon", "name": "Stun sling (a spark stuns for 5 s)", "shop": "forge", "tab": "Weapons", "price": 4000, "unique": true,
		"parts": {"item_metal_plate": 10, "item_component": 20, "item_metal_tusk": 10}},
	"item_spear_thrower": {"slot": "weapon", "name": "Spear thrower (shoots spears)", "shop": "forge", "tab": "Weapons", "price": 6000, "unique": true,
		"parts": {"item_metal_plate": 30, "item_component": 20, "item_metal_tusk": 30}},
	"item_booster": {"slot": "tool", "name": "Booster (speed builds up while running)", "shop": "forge", "tab": "Upgrades", "price": 3000, "unique": true,
		"parts": {"item_metal_plate": 10, "item_component": 15, "item_metal_tusk": 10}},
	"item_jump": {"slot": "tool", "name": "Jumper (long jumps)", "shop": "forge", "tab": "Upgrades", "price": 3000, "unique": true,
		"parts": {"item_metal_plate": 10, "item_component": 15, "item_metal_tusk": 10}},
	"item_war_cry": {"slot": "tool", "name": "War cry (boars stand stunned 10 s, terminators up to 3 s)", "shop": "forge", "tab": "Upgrades",
		"price": 5000, "unique": true, "parts": {"item_metal_plate": 10, "item_component": 25, "item_metal_tusk": 20}},
	"item_ram_shield": {"slot": "tool", "name": "Ram shield (run into boars to knock them back)", "shop": "forge", "tab": "Upgrades", "price": 5000,
		"unique": true, "parts": {"item_metal_plate": 30, "item_component": 10, "item_metal_tusk": 20}},
}

## Beauty hut colours (issue #18): white and black free, the rest bought in packs of PAINT_PACK coats.
## Prices ASSUMPTION (D013).
const PAINTS := {
	"white": {"name": "White", "color": "#f1ede2", "price": 0}, "black": {"name": "Black", "color": "#2a2622", "price": 0},
	"red": {"name": "Clay red", "color": "#b8442f", "price": 40}, "ochre": {"name": "Ochre", "color": "#d39a2c", "price": 40},
	"green": {"name": "Moss green", "color": "#5f8a3a", "price": 60}, "blue": {"name": "Berry blue", "color": "#3f5fa8", "price": 80},
	"purple": {"name": "Plum", "color": "#7a3f8f", "price": 100},
}
const PAINT_PACK := 5
## What can be painted: the hut and the ridden boar (hunter and gear come later, P3-117).
const PAINT_TARGETS: Array[String] = ["hut", "mount"]

## Forge recipe tabs, in order (issue #11).
const FORGE_TABS: Array[String] = ["Armor", "Weapons", "Upgrades"]
const PART_NAMES := {"item_metal_tusk": "metal tusks", "item_metal_plate": "metal plates", "item_component": "components"}

## Tusks the forge needs before it opens (issue #11).
const FORGE_COST := 100000

## Gear box (issue #15): how much of each slot the hunter takes on a hunt; a hired helper (porter or tavern
## crewman) doubles baits and traps. "weapon" counts kinds (all spears are one), "bait" and "trap" count
## pieces. The knife is always carried; "main" is the club; "tool" is one forge upgrade. Items with no slot
## always go along.
const SLOTS := {"main": 1, "weapon": 2, "bait": 3, "trap": 1, "armor": 1, "tool": 1}
const HELPER_SLOTS := {"bait": 6, "trap": 2}

## What each camp shop buys (issues #13, #16, #17, #18, #21, #28): id -> units for one tusk, or
## [units, tusks] for dearer goods. Birds come out of the cages, baits out of gear, the rest is forest finds.
const SELL := {
	"weapon_shop": {"stone": 12, "feather": 12},
	"campfire": {"stick": 12, "mushroom": 10},
	"beauty_hut": {"berry": 10, "daisy": 10},
	"shaman_hut": {"poison_berry": 6, "larva": 4, "frog": 6},
	"pens": {"grass": 12, "mushroom": 10},
	# ASSUMPTION (D013): a caught bird sells for a few tusks, a bait for half its price.
	"cages": {"rooster": [1, 10], "turkey": [1, 15]},
	"hunting_hut": {"item_acorns": [2, 5], "item_red_berries": [1, 3], "item_blueberries": [1, 3], "item_apple": [1, 4],
		"item_pear": [1, 4], "item_bananas": [1, 5], "item_mandarin": [1, 5], "item_mango": [1, 6], "item_mixed_berries": [1, 7]},
}
## Ids SELL takes out of the cages (Progress.helpers) rather than the forest finds.
const BIRD_IDS := ["rooster", "turkey"]
const MATERIAL_NAMES := {
	"stone": "Stones", "feather": "Feathers", "stick": "Sticks", "mushroom": "Mushrooms", "berry": "Berries",
	"daisy": "Daisies", "poison_berry": "Poisonous berries", "larva": "Larvae", "frog": "Frogs", "grass": "Grass",
	"rooster": "Roosters", "turkey": "Turkeys",
}


## What a new game starts with in stock: one spear, three nets, five sling stones (owner, 2026-10-27).
const STARTER_KIT := {"item_spear": 1, "item_net": 3, "item_stone": 5}


## What item_id costs right now.
static func price(item_id: String) -> int:
	return 0 if free_for_testing else ITEMS[item_id]["price"]


## What a pack of a paint costs right now (free while testing, like the shops).
static func price_of_paint(color_id: String) -> int:
	return 0 if free_for_testing else PAINTS[color_id]["price"]


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


## Units sold for how many tusks at shop_id: Vector2i(units, tusks).
static func sell_rate(shop_id: String, id: String) -> Vector2i:
	var rate: Variant = SELL[shop_id][id]
	return Vector2i(rate[0], rate[1]) if rate is Array else Vector2i(rate, 1)


## Shown name of a sellable id: a material, a bird or a catalog item.
static func sell_name(id: String) -> String:
	return ITEMS[id]["name"] if ITEMS.has(id) else MATERIAL_NAMES[id]
