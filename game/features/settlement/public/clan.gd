extends RefCounted

## The hunter's clan (issues #27, #23), founded at the totem once the hut and its clan tent are bought.
## Single player until co-op (GAME_SPEC 19), so the chief is the only member and the join rules are kept
## for later; the rating counts the clan's deeds since it was founded. Plain data in and out (to_dict/from_dict).


## Icons a chief can pick: file names in assets/icon/items/.
const ICONS: Array[String] = ["tusk", "spear", "bow", "club", "rooster", "turkey", "feather", "flower", "frog", "mushroom"]
## Join rules a chief can set (issue #27): rule id -> label; 0 means no such rule.
const RULES := {"fee": "Entry fee, tusks", "hunts": "Hunts done", "kills": "Boars killed", "captures": "Boars caught",
	"terminators": "Terminators killed"}
## Rating each deed brings (issue #23 asks for the maths; ASSUMPTION, D013). A hunt counts when a boar was
## killed or caught on it.
const POINTS := {"hunts": 100, "kills": 20, "captures": 50, "terminators": 200}
## Clan levels by rating, shown by the clan tent (issue #23).
const TIERS: Array[int] = [0, 10000, 100000, 1000000, 10000000, 100000000]
const TIER_NAMES: Array[String] = ["New", "Common", "Uncommon", "Rare", "Epic", "Legendary"]
## Places in a clan (ASSUMPTION): shown next to the members list.
const SLOTS := 10
## Deed id -> how many it takes, for the clan page's achievements (ASSUMPTION).
const ACHIEVEMENTS := [["hunts", 1, "First hunt"], ["hunts", 10, "10 hunts"], ["hunts", 100, "100 hunts"],
	["captures", 1, "First boar caught"], ["captures", 100, "100 boars caught"], ["kills", 100, "100 boars killed"],
	["terminators", 1, "First terminator"], ["terminators", 100, "100 terminators"]]

var name := ""
var icon: String = ICONS[0]
var motto := ""
## rule id -> amount a new member needs.
var rules: Dictionary = {}
## Deeds since founding: rule ids hunts, kills, captures, terminators -> count.
var deeds := {"hunts": 0, "kills": 0, "captures": 0, "terminators": 0}
## Unix time the clan stew's buff wears off (issue #23).
var stew_until := 0

## The free clan stew in the tent (issue #23): 2 h plus 1 h a level; each level adds to the buff (ASSUMPTION).
const STEW_HOURS := 2


## Shares added to stamina, damage and speed while the stew lasts.
func stew_bonus() -> Dictionary:
	var at := level()
	return {"stamina": 0.15 + 0.05 * at, "damage": 0.10 + 0.02 * at, "speed": 0.05 + 0.01 * at}


func stew_active(now: int) -> bool:
	return now < stew_until


## Eats the stew; false while the last bowl still works.
func eat_stew(now: int) -> bool:
	if stew_active(now):
		return false
	stew_until = now + (STEW_HOURS + level()) * 3600
	return true


## Counts a finished hunt's deeds.
func add_hunt(hunt: RefCounted) -> void:
	var kills: int = hunt.count_all(BoarOutcome.Kind.DEAD)
	var captures: int = hunt.count_all(BoarOutcome.Kind.CAPTURED)
	deeds["hunts"] += 1 if kills + captures > 0 else 0
	deeds["kills"] += kills
	deeds["captures"] += captures
	deeds["terminators"] += hunt.invasion.killed


func rating() -> int:
	var sum := 0
	for deed in POINTS:
		sum += deeds[deed] * POINTS[deed]
	return sum


## 0 (New) .. 5 (Legendary).
func level() -> int:
	var at := 0
	for i in TIERS.size():
		if rating() >= TIERS[i]:
			at = i
	return at


func tier_name() -> String:
	return TIER_NAMES[level()]


## Names of the achievements reached.
func achievements() -> Array[String]:
	var earned: Array[String] = []
	for entry: Array in ACHIEVEMENTS:
		if deeds[entry[0]] >= entry[1]:
			earned.append(entry[2])
	return earned


func to_dict() -> Dictionary:
	return {"name": name, "icon": icon, "motto": motto, "rules": rules.duplicate(), "deeds": deeds.duplicate(),
		"stew_until": stew_until}


## Malformed fields fall back to defaults; an empty name means no clan (null).
static func from_dict(data: Dictionary) -> RefCounted:
	if str(data.get("name", "")).strip_edges() == "":
		return null
	var clan := new()
	clan.name = str(data["name"])
	clan.icon = str(data.get("icon", "")) if str(data.get("icon", "")) in ICONS else ICONS[0]
	clan.motto = str(data.get("motto", ""))
	clan.rules = _counts(data.get("rules", {}), RULES)
	var saved := _counts(data.get("deeds", {}), POINTS)
	for deed in clan.deeds:
		clan.deeds[deed] = saved.get(deed, 0)
	clan.stew_until = maxi(0, int(data.get("stew_until", 0)))
	return clan


static func _counts(saved: Variant, known: Dictionary) -> Dictionary:
	var counts := {}
	if saved is Dictionary:
		for key in saved:
			if known.has(str(key)):
				counts[str(key)] = maxi(0, int(saved[key]))
	return counts
