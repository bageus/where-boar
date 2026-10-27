extends CenterContainer

## Hunt results (M007): boars killed, caught and escaped per type, and the tusks earned.

const Hunt = preload("res://game/features/hunt/public/hunt.gd")
const BoarOutcome = preload("res://game/features/boar/public/boar_outcome.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")


func show_results(hunt: Hunt, total_tusks: int) -> void:
	var lines: PackedStringArray = []
	for type_id in hunt.type_ids():
		var type := BoarTypes.find(type_id)
		lines.append("%s: killed %d, caught %d, escaped %d" % [
			type.display_name if type else type_id,
			hunt.count(type_id, BoarOutcome.Kind.DEAD),
			hunt.count(type_id, BoarOutcome.Kind.CAPTURED),
			hunt.count(type_id, BoarOutcome.Kind.ESCAPED),
		])
	if lines.is_empty():
		lines.append("No boars this time.")
	lines.append("")
	lines.append("Tusks earned: %d   (tribe total: %d)" % [hunt.tusks(), total_tusks])
	%Summary.text = "\n".join(lines)
