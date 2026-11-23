extends Control

## Active quests in the top-left corner of the hunt and gathering maps (owner, 2026-11-23): the map's own kind
## of quest first. A quest that just got done flashes a banner in the centre; the reward waits at the board.

const QuestBoard = preload("res://game/features/settlement/public/quest_board.gd")

## Set before the node enters the tree.
var board: QuestBoard
var materials: Dictionary = {}
var hunting := true
## The map, which owns `hunt` (the hunt map replaces it when the boars are spawned).
var map: Node

var _list := Label.new()
var _banner := VBoxContainer.new()
var _done: Dictionary = {}
var _left := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.position = Vector2(20, 20)
	_list.add_theme_font_size_override("font_size", 20)
	_list.add_theme_constant_override("outline_size", 6)
	_list.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_list)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	_banner.add_child(_line("Quest complete!", 64, Color(1.0, 0.85, 0.2)))
	_banner.add_child(_line("Congratulations, great job!", 30, Color(0.5, 1.0, 0.6)))
	_banner.add_child(_line("Collect your reward at the quest board", 24, Color.WHITE))
	for entry in _entries():
		_done[entry["text"]] = entry["have"] >= entry["amount"]  # already met on entry: no banner
	_refresh()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = 0.5
		_refresh()


func _entries() -> Array[Dictionary]:
	return board.active(materials, map.hunt, hunting)


func _refresh() -> void:
	var lines := PackedStringArray()
	for entry in _entries():
		var met: bool = entry["have"] >= entry["amount"]
		if met and not _done.get(entry["text"], false):
			_celebrate()
		_done[entry["text"]] = met
		lines.append("%s %s (%d/%d)" % ["✔" if met else "•", entry["text"], entry["have"], entry["amount"]])
	_list.text = "Quests\n" + "\n".join(lines) if lines.size() > 0 else ""


func _line(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 12)
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.0))
	return label


func _celebrate() -> void:
	_banner.pivot_offset = _banner.size / 2.0
	var tween := create_tween()
	tween.tween_property(_banner, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.parallel().tween_property(_banner, "scale", Vector2(1.15, 1.15), 0.2).from(Vector2(0.6, 0.6))
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.2)
	tween.tween_property(_banner, "modulate", Color(1.4, 1.2, 0.6, 1), 0.4)
	tween.tween_property(_banner, "modulate", Color(1, 1, 1, 1), 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.6)
