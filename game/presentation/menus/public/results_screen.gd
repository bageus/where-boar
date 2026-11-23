extends CenterContainer

## Hunt results (M007): boars killed, caught and escaped per type, and the tusks earned.

const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")
const ItemIcons = preload("res://game/features/settlement/public/item_icons.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")


## One of the hunt's closing tunes plays while the results are counted (owner, 2026-11-05).
func show_results(hunt: Hunt, total_tusks: int) -> void:
	Sfx.ui(self, "music_hunt_end", -6.0)
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
	var loot := hunt.invasion.loot
	if not loot.is_empty():
		lines.append("Terminator loot: %s metal tusks %d, %s metal plates %d, %s components %d" % [
			ItemIcons.bbcode("item_metal_tusk"), loot.get("item_metal_tusk", 0), ItemIcons.bbcode("item_metal_plate"),
			loot.get("item_metal_plate", 0), ItemIcons.bbcode("item_component"), loot.get("item_component", 0)])
	var finds := PackedStringArray()
	for material_id: String in hunt.gathered:
		finds.append("%s %d" % [ItemIcons.bbcode(material_id), hunt.gathered[material_id]])
	if not finds.is_empty():
		lines.append("Gathered: " + "   ".join(finds))
	lines.append("")
	lines.append("%sTusks earned: %d   (tribe total: %d)" % [ItemIcons.bbcode("tusk"), hunt.tusks(), total_tusks])
	%Summary.text = "[center]%s[/center]" % "\n".join(lines)
