extends RefCounted

## Daily quests on the camp board (issue #25): every player gets a random pool (repeats between players are
## fine), renewed every 12 hours. A quest is accepted, then done when its condition holds, then claimed for
## tusks. Hunt quests count hunts finished after accepting; gathering quests are met by the materials carried.
## Plain data in and out (to_dict/from_dict) so the save adapter never sees this class.

const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")

const RENEW_SECONDS := 12 * 3600
const POOL_SIZE := 5
## kind -> text (with %d for the amount), amounts to pick from, reward in tusks for each amount.
## ASSUMPTION rewards (D013): a little more than selling the same finds (issue #25).
const KINDS := {
	"catch": {"text": "Catch %d boars alive", "amounts": [2, 4], "rewards": [20, 45]},
	"kill": {"text": "Kill %d boars", "amounts": [3, 6], "rewards": [15, 35]},
	"tusks": {"text": "Earn %d tusks in one hunt", "amounts": [60, 120], "rewards": [20, 40]},
	"bird": {"text": "Catch %d bird", "amounts": [1], "rewards": [15]},
	"stick": {"text": "Bring %d sticks for the fire", "amounts": [24], "rewards": [3]},
	"grass": {"text": "Bring %d grass for the boars", "amounts": [24], "rewards": [3]},
	"stone": {"text": "Bring %d stones for slings", "amounts": [24], "rewards": [3]},
	"feather": {"text": "Bring %d feathers for arrows", "amounts": [24], "rewards": [3]},
	"berry": {"text": "Bring %d berries for paint", "amounts": [20], "rewards": [3]},
	"daisy": {"text": "Bring %d daisies for paint", "amounts": [20], "rewards": [3]},
	"larva": {"text": "Bring %d larvae for the shaman", "amounts": [8], "rewards": [3]},
	"frog": {"text": "Bring %d frogs", "amounts": [12], "rewards": [3]},
	"poison_berry": {"text": "Bring %d poisonous berries", "amounts": [12], "rewards": [3]},
}
const HUNT_KINDS := ["catch", "kill", "tusks", "bird"]

## Each: {"kind", "amount", "reward", "have" (hunt quests), "state": "open" | "accepted" | "claimed"}.
var quests: Array[Dictionary] = []
## Unix time when the pool is drawn again.
var renews_at := 0


## Draws a new pool when the old one has run out (or there is none yet).
func renew_if_due(now: int, rng := RandomNumberGenerator.new()) -> void:
	if now < renews_at and not quests.is_empty():
		return
	quests.clear()
	var kinds := KINDS.keys()
	for i in POOL_SIZE:
		var kind: String = kinds.pop_at(rng.randi() % kinds.size())
		var pick: int = rng.randi() % KINDS[kind]["amounts"].size()
		quests.append({"kind": kind, "amount": KINDS[kind]["amounts"][pick], "reward": KINDS[kind]["rewards"][pick],
			"have": 0, "state": "open"})
	renews_at = now + RENEW_SECONDS


func text(index: int) -> String:
	return KINDS[quests[index]["kind"]]["text"] % quests[index]["amount"]


func accept(index: int) -> void:
	if quests[index]["state"] == "open":
		quests[index]["state"] = "accepted"


## How far an accepted quest has got: hunt progress, or the materials carried for a gathering quest.
func have(index: int, materials: Dictionary) -> int:
	var quest := quests[index]
	return quest["have"] if quest["kind"] in HUNT_KINDS else materials.get(quest["kind"], 0)


func can_claim(index: int, materials: Dictionary) -> bool:
	return quests[index]["state"] == "accepted" and have(index, materials) >= quests[index]["amount"]


## Marks the quest claimed and returns its reward (0 when it cannot be claimed); takes gathered materials.
func claim(index: int, materials: Dictionary) -> int:
	if not can_claim(index, materials):
		return 0
	var quest := quests[index]
	if not quest["kind"] in HUNT_KINDS:
		materials[quest["kind"]] -= quest["amount"]
	quest["state"] = "claimed"
	return quest["reward"]


func claimed_count() -> int:
	return quests.filter(func(q: Dictionary) -> bool: return q["state"] == "claimed").size()


## Counts a finished hunt towards the accepted hunt quests.
func add_hunt(hunt: RefCounted) -> void:
	for quest in quests:
		if quest["state"] != "accepted":
			continue
		match quest["kind"]:
			"catch":
				quest["have"] += hunt.count_all(BoarOutcome.Kind.CAPTURED)
			"kill":
				quest["have"] += hunt.count_all(BoarOutcome.Kind.DEAD)
			"tusks":
				quest["have"] = maxi(quest["have"], hunt.tusks())
			"bird":
				for animal_id in hunt.helpers_caught:
					quest["have"] += hunt.helpers_caught[animal_id]


func to_dict() -> Dictionary:
	return {"quests": quests.duplicate(true), "renews_at": renews_at}


## Unknown kinds and malformed entries are dropped instead of failing the load.
static func from_dict(data: Dictionary) -> RefCounted:
	var board := new()
	board.renews_at = int(data.get("renews_at", 0))
	var saved: Variant = data.get("quests", [])
	if saved is Array:
		for quest: Variant in saved:
			if quest is Dictionary and KINDS.has(quest.get("kind")):
				board.quests.append({"kind": quest["kind"], "amount": maxi(1, int(quest.get("amount", 1))),
					"reward": maxi(0, int(quest.get("reward", 0))), "have": maxi(0, int(quest.get("have", 0))),
					"state": str(quest.get("state", "open"))})
	return board
