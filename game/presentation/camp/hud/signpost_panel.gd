extends PanelContainer

## The signpost's window (issue #24): first hunt or gather, then where to hunt, with whom (public, clan,
## private tabs) and after how many seconds. Built in code; the camp opens it and runs the countdown.

const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const HuntLobby = preload("res://game/features/settlement/public/hunt_lobby.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## Fact: the player started a hunt countdown.
signal launched(mode: String, seconds: int, invited: PackedStringArray)
## Fact: the team pass was bought; the game saves.
signal purchased(item_id: String)
signal closed

## One location for now; more come later (owner).
const LOCATIONS := [{"name": "Green Valley", "preview": preload("res://assets/ui/hunt_preview_green_valley.jpg"),
	"text": "Hills, a river and cliffs around a valley of grass. Herds of boars, wild roosters and turkeys; after many hunts the terminators come."}]
const TABS := {"public": "Public hunt", "clan": "Clan hunt", "private": "Private hunt"}
const TAB_TEXT := {
	"public": "Everyone standing in the circle around the signpost goes on the hunt.",
	"clan": "Only your clan mates in the circle go. You are in no clan yet: clans come with the clan totem.",
	"private": "Only the players you invite go, and each of them needs a team pass.",
}

var progress: Progress
var _mode := "public"
var _seconds := HuntLobby.TIMER_DEFAULT
var _invited := PackedStringArray()
var _body := VBoxContainer.new()


func _init() -> void:
	hide()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(760, 0)
	add_child(_body)


func open() -> void:
	_invited.clear()
	_choice_page()
	show()


func close() -> void:
	hide()
	closed.emit()


## The first overlay: hunt or gather.
func _choice_page() -> void:
	_clear()
	_label("Signpost", 28)
	var row := HBoxContainer.new()
	_body.add_child(row)
	_button(row, "Hunt", _hunt_page)
	_button(row, "Gather (comes later)", Callable()).disabled = true
	_button(row, "Close", close)


func _hunt_page() -> void:
	_clear()
	var tabs := HBoxContainer.new()
	_body.add_child(tabs)
	for mode: String in TABS:
		var tab := _button(tabs, TABS[mode], func() -> void:
			_mode = mode
			_hunt_page())
		tab.toggle_mode = true
		tab.button_pressed = mode == _mode
	var split := HBoxContainer.new()
	_body.add_child(split)
	var places := ItemList.new()
	places.custom_minimum_size = Vector2(180, 200)
	for place: Dictionary in LOCATIONS:
		places.add_item(place["name"])
	places.select(0)
	split.add_child(places)
	var about := VBoxContainer.new()
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(about)
	var preview := TextureRect.new()
	preview.texture = LOCATIONS[0]["preview"]
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(0, 180)
	about.add_child(preview)
	_label(LOCATIONS[0]["text"], 16, about)
	_label(TAB_TEXT[_mode], 18)
	if _mode == "private":
		_private_rows()
	var timer := HBoxContainer.new()
	_body.add_child(timer)
	var shown := _label("", 18, timer)
	var slider := HSlider.new()
	slider.min_value = HuntLobby.TIMER_DEFAULT
	slider.max_value = HuntLobby.TIMER_MAX
	slider.step = 5
	slider.value = _seconds
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var show_seconds := func(value: float) -> void:
		_seconds = HuntLobby.timer(int(value))
		shown.text = "Start in %d s" % _seconds
	show_seconds.call(slider.value)
	slider.value_changed.connect(show_seconds)
	timer.add_child(slider)
	var buttons := HBoxContainer.new()
	_body.add_child(buttons)
	var start := _button(buttons, "Start", func() -> void:
		hide()
		launched.emit(_mode, _seconds, _invited.duplicate()))
	start.disabled = _mode == "clan" or (_mode == "private" and not progress.owns(HuntLobby.PASS_ID))
	_button(buttons, "Back", _choice_page)
	_button(buttons, "Close", close)


## The pass to buy, or the names to invite once it is owned.
func _private_rows() -> void:
	if not progress.owns(HuntLobby.PASS_ID):
		var price := ShopCatalog.price(HuntLobby.PASS_ID)
		var buy := _button(_body, "Buy a team pass — %d tusks (you have %d)" % [price, progress.tusks], func() -> void:
			if progress.buy(HuntLobby.PASS_ID):
				Sfx.ui(self, "buying")
				purchased.emit(HuntLobby.PASS_ID)
			_hunt_page())
		buy.disabled = progress.tusks < price
		return
	var row := HBoxContainer.new()
	_body.add_child(row)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Player name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_edit)
	_button(row, "Invite", func() -> void:
		var player := name_edit.text.strip_edges()
		if player != "" and player not in _invited:
			_invited.append(player)
		_hunt_page())
	_label("Invited: %s" % (", ".join(_invited) if not _invited.is_empty() else "nobody yet"), 16)


func _clear() -> void:
	for child in _body.get_children():
		child.queue_free()


func _label(text: String, size: int, parent: Control = _body) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	if action.is_valid():
		button.pressed.connect(action)
	parent.add_child(button)
	return button
