extends RefCounted

## Lasting progress between hunts (section 13): tusks to spend and animals caught alive.
## Plain data in and out (to_dict/from_dict) so the save adapter never sees this class.

const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")

var tusks := 0
## type_id -> animals caught alive and kept in camp.
var caught: Dictionary = {}


## Adds a finished hunt's tusks and live catches.
func add_hunt(hunt: Hunt) -> void:
	tusks += hunt.tusks()
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


func to_dict() -> Dictionary:
	return {"tusks": tusks, "caught": caught.duplicate()}


## Unknown or malformed fields fall back to defaults instead of failing the load.
static func from_dict(data: Dictionary) -> RefCounted:
	var progress := new()
	progress.tusks = maxi(0, int(data.get("tusks", 0)))
	var saved = data.get("caught", {})
	if saved is Dictionary:
		for type_id in saved:
			progress.caught[str(type_id)] = maxi(0, int(saved[type_id]))
	return progress
