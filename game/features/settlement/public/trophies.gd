extends RefCounted

## Trophies a hunt may bring home (issue #19): kept for good, shown in the clan tent and on the results,
## used as decoration later. Chances are per finished hunt; the issue gives 0.5% for the first four,
## the rest are ASSUMPTION (rarer).

const TROPHIES := {
	"camo_helmet": {"name": "Camouflage helmet", "chance": 0.005},
	"camo_cloak": {"name": "Camouflage cloak", "chance": 0.005},
	"rabbit_foot": {"name": "Rabbit's foot (for the spear)", "chance": 0.005},
	"cinnabon_hat": {"name": "Cinnabon hat", "chance": 0.005},
	"shaggy_cloak": {"name": "Shaggy cloak", "chance": 0.003},
	"golden_cloak": {"name": "Golden cloak", "chance": 0.001},
	"lucky_coin": {"name": "Golden lucky coin (necklace)", "chance": 0.001},
}


## Trophy ids won on one hunt; a hunt with no boar killed or caught brings none.
static func roll(earned_any: bool, rng: RandomNumberGenerator) -> Array[String]:
	var won: Array[String] = []
	if not earned_any:
		return won
	for trophy_id in TROPHIES:
		if rng.randf() < TROPHIES[trophy_id]["chance"]:
			won.append(trophy_id)
	return won


static func names(trophy_ids: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for trophy_id in trophy_ids:
		out.append(TROPHIES.get(trophy_id, {}).get("name", trophy_id))
	return out
