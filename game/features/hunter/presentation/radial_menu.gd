extends Control

## Ring of choices around the screen centre (owner, 2026-10-28): opened by holding the bait or trap key,
## the mouse points at a choice and letting the key go picks it.

const RADIUS := 150.0
## The mouse must be this far from the centre to point at a choice.
const DEAD_ZONE := 30.0

var _ids: Array = []
var _hovered := -1


## Shows labels[i] for ids[i] around the centre and frees the mouse to point.
func open(ids: Array, labels: Array) -> void:
	_ids = ids
	_hovered = -1
	for child in get_children():
		child.free()
	for i in ids.size():
		var label := Label.new()
		label.text = labels[i]
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().warp_mouse(get_viewport_rect().size / 2.0)


## Hides the ring, captures the mouse again and returns the picked id, or "" when none was pointed at.
func close() -> String:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return _ids[_hovered] if _hovered >= 0 else ""


func _process(_delta: float) -> void:
	if not visible:
		return
	var centre := get_viewport_rect().size / 2.0
	var pointer := get_viewport().get_mouse_position() - centre
	_hovered = choice_at(pointer, _ids.size())
	for i in get_child_count():
		var label: Label = get_child(i)
		var angle := TAU * i / _ids.size() - PI / 2.0
		label.position = centre + Vector2(cos(angle), sin(angle)) * RADIUS - label.size / 2.0
		label.modulate = Color.YELLOW if i == _hovered else Color.WHITE


## Index of the choice in the direction of pointer (from the centre; first choice at the top), or -1 near the centre.
static func choice_at(pointer: Vector2, count: int) -> int:
	if count == 0 or pointer.length() < DEAD_ZONE:
		return -1
	var angle := fposmod(pointer.angle() + PI / 2.0, TAU)
	return roundi(angle / (TAU / count)) % count
