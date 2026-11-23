extends RefCounted

## Group hunts from the signpost (issue #24): who of those standing in its circle goes, and how a crowd
## splits into several hunts. A player is {"name": String, "clan": String, "pass": bool}; one player
## for now (co-op after MVP, GAME_SPEC 19), so the circle holds only you.

const MODES: Array[String] = ["public", "clan", "private"]
## Hunters per hunt after MVP (GAME_SPEC 19).
const PARTY_MAX := 4
const TIMER_DEFAULT := 10
const TIMER_MAX := 60
## Every player of a private hunt needs one (owner: 2000), bought on the private tab.
const PASS_ID := "item_team_pass"


static func timer(seconds: int) -> int:
	return clampi(seconds, TIMER_DEFAULT, TIMER_MAX)


## Who goes: everyone in the circle (public), the starter's clan mates (clan), or the starter and the
## invited names, each with a pass (private).
static func entrants(mode: String, starter: Dictionary, in_circle: Array, invited: PackedStringArray) -> Array:
	match mode:
		"public":
			return in_circle.duplicate()
		"clan":
			return in_circle.filter(func(p: Dictionary) -> bool: return starter["clan"] != "" and p["clan"] == starter["clan"])
		"private":
			if not starter["pass"]:
				return []
			return in_circle.filter(func(p: Dictionary) -> bool:
				return p["pass"] and (p["name"] == starter["name"] or p["name"] in invited))
	return []


## More entrants than one hunt holds start several hunts at once, as even as possible.
static func split(players: Array, party_max := PARTY_MAX) -> Array[Array]:
	var groups: Array[Array] = []
	var count := ceili(players.size() / float(party_max))
	for i in count:
		groups.append([])
	for i in players.size():
		groups[i % count].append(players[i])
	return groups
