extends PanelContainer

## Beauty hut window (issue #18): tabs for what to paint, the palette on the left (white and black free,
## other colours bought in packs, one coat used per paint), the chosen object's colour in the middle, and
## Sell resources on top (berries and flowers). Only the look changes.

const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## Fact: paint was bought or used; the camp repaints and saves.
signal painted
signal sell_requested
signal closed

const TABS := {"hunter": "Hunter", "mount": "Riding boar", "gear": "Gear", "hut": "Hut"}

var progress: Progress
var _tab := "mount"
var _color := "white"
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -300.0
	offset_right = 300.0
	offset_top = -280.0
	offset_bottom = 280.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	add_child(_body)
	hide()


func open() -> void:
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _refresh() -> void:
	for child in _body.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "Beauty hut"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(title)
	_add_button(_body, "Sell resources", sell_requested.emit)
	var tabs := HBoxContainer.new()
	for tab_id: String in TABS:
		var tab := _add_button(tabs, TABS[tab_id], func() -> void:
			_tab = tab_id
			_refresh())
		tab.toggle_mode = true
		tab.button_pressed = tab_id == _tab
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(tabs)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	row.add_child(_palette())
	row.add_child(_canvas())
	_add_button(_body, "Close", close)


## One row per colour: its swatch (picks it), coats in stock, and a buy button for paid ones.
func _palette() -> VBoxContainer:
	var list := VBoxContainer.new()
	for color_id: String in ShopCatalog.PAINTS:
		var paint: Dictionary = ShopCatalog.PAINTS[color_id]
		var line := HBoxContainer.new()
		var swatch := _add_button(line, "", func() -> void:
			_color = color_id
			_refresh())
		swatch.custom_minimum_size = Vector2(36, 28)
		swatch.toggle_mode = true
		swatch.button_pressed = color_id == _color
		swatch.add_theme_stylebox_override("normal", _flat(Color(paint["color"])))
		swatch.add_theme_stylebox_override("pressed", _flat(Color(paint["color"]), true))
		swatch.tooltip_text = paint["name"]
		var stock := Label.new()
		stock.text = "free" if paint["price"] == 0 else "x%d" % progress.paints.get(color_id, 0)
		stock.custom_minimum_size.x = 44
		line.add_child(stock)
		if paint["price"] > 0:
			var price := ShopCatalog.price_of_paint(color_id)
			var buy := _add_button(line, "+%d — %d tusks" % [ShopCatalog.PAINT_PACK, price], func() -> void:
				if progress.buy_paint(color_id):
					Sfx.ui(self, "buying")
					painted.emit()
				_refresh())
			buy.disabled = progress.tusks < price
		list.add_child(line)
	return list


## The chosen object's colour and the Paint button; hunter and gear wait for a later task.
func _canvas() -> VBoxContainer:
	var canvas := VBoxContainer.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(info)
	if _tab not in ShopCatalog.PAINT_TARGETS:
		info.text = "Painting the %s comes later." % TABS[_tab].to_lower()
		return canvas
	var current: String = progress.paint.get(_tab, "")
	info.text = "%s: %s" % [TABS[_tab], ShopCatalog.PAINTS[current]["name"] if current != "" else "own colours"]
	var sample := Panel.new()
	sample.custom_minimum_size = Vector2(0, 120)
	sample.add_theme_stylebox_override("panel", _flat(Color(ShopCatalog.PAINTS[current]["color"]) if current != "" else Color(0.5, 0.4, 0.3)))
	canvas.add_child(sample)
	var paid: bool = ShopCatalog.PAINTS[_color]["price"] > 0
	var paint := _add_button(canvas, "Paint %s (%s)" % [ShopCatalog.PAINTS[_color]["name"], "1 coat" if paid else "free"], func() -> void:
		if progress.paint_target(_tab, _color):
			Sfx.ui(self, "buying")
			painted.emit()
		_refresh())
	paint.disabled = paid and progress.paints.get(_color, 0) <= 0
	return canvas


static func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


static func _flat(color: Color, outlined := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	if outlined:
		box.set_border_width_all(3)
		box.border_color = Color.WHITE
	return box
