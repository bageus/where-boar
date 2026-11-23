extends PanelContainer

## The clan window behind the totems (issue #27): the clans and their rating, what founding one takes (the
## hut and its clan tent), the founding / edit form and the clan's page. Single player until co-op, so the
## list holds only your clan and the members list only you.

const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const Clan = preload("res://game/features/settlement/public/clan.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## Fact: something was bought or the clan changed; the camp passes it on so the game saves.
signal purchased(item_id: String)
signal closed

const ICON_DIR := "res://assets/icon/items/"
const DONE_COLOR := Color(0.45, 1.0, 0.4)

var progress: Progress
var _box: VBoxContainer
var _title: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -280.0
	offset_right = 280.0
	offset_top = -320.0
	offset_bottom = 320.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	add_child(outer)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	outer.add_child(close_button)
	hide()


## Opens on the clan list; from a just-upgraded hut, on what founding takes.
func open(founding := false) -> void:
	if founding and not progress.clan:
		show_requirements()
	else:
		show_list()
	show()


func close() -> void:
	hide()
	closed.emit()


func show_list() -> void:
	_clear("Clans")
	if progress.clan:
		var row := _button("%s  —  %s, rating %d" % [progress.clan.name, progress.clan.tier_name(), progress.clan.rating()], show_page)
		row.icon = load(ICON_DIR + progress.clan.icon + ".png")
		row.expand_icon = false
		row.add_theme_constant_override("icon_max_width", 32)
	else:
		_label("No clans yet.")
		_button("Create clan", show_requirements)
	_label("Other hunters' clans come with co-op.")


## Two buttons on one row: buy a hut, upgrade it; both done shows the big Create clan button (issue #27).
func show_requirements() -> void:
	_clear("Create a clan")
	_label("A clan needs a hut of your own and its clan tent.")
	var row := HBoxContainer.new()
	_box.add_child(row)
	for item_id in ["item_hut", "item_clan_tent"]:
		var button := Button.new()
		var owned := progress.owns(item_id)
		var label := "Buy a hut" if item_id == "item_hut" else "Upgrade the hut"
		button.text = "%s\n%s" % [label, "done" if owned else "%d tusks" % ShopCatalog.price(item_id)]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = owned or not progress.unlocked(item_id) or progress.tusks < ShopCatalog.price(item_id)
		if owned:
			button.add_theme_color_override("font_disabled_color", DONE_COLOR)
		button.pressed.connect(func() -> void:
			if progress.buy(item_id):
				Sfx.ui(self, "buying")
				purchased.emit(item_id)
			show_requirements())
		row.add_child(button)
	if progress.owns("item_hut") and progress.owns("item_clan_tent"):
		var create := _button("Create clan", show_form)
		create.custom_minimum_size.y = 56
		create.add_theme_font_size_override("font_size", 24)
	_button("Back", show_list)


## Founding form, or the chief's edit form: the name is set once, icon, motto and join rules change later.
func show_form() -> void:
	var clan: Clan = progress.clan
	_clear("Clan settings" if clan else "New clan")
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Clan name"
	name_edit.max_length = 24
	if clan:
		_label("Name: %s (cannot be changed)" % clan.name)
	else:
		_box.add_child(name_edit)
	_label("Join rules (0 = none):")
	var spins := {}
	for rule_id in Clan.RULES:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = Clan.RULES[rule_id]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin := SpinBox.new()
		spin.max_value = 1000000
		spin.value = clan.rules.get(rule_id, 0) if clan else 0
		spins[rule_id] = spin
		row.add_child(label)
		row.add_child(spin)
		_box.add_child(row)
	_members()
	_label("Icon:")
	var icons := HFlowContainer.new()
	var picked := [clan.icon if clan else Clan.ICONS[0]]
	var group := ButtonGroup.new()
	for icon_id in Clan.ICONS:
		var button := Button.new()
		button.icon = load(ICON_DIR + icon_id + ".png")
		button.add_theme_constant_override("icon_max_width", 36)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = icon_id == picked[0]
		button.pressed.connect(func() -> void: picked[0] = icon_id)
		icons.add_child(button)
	_box.add_child(icons)
	var motto := LineEdit.new()
	motto.placeholder_text = "Clan motto"
	motto.max_length = 60
	motto.text = clan.motto if clan else ""
	_box.add_child(motto)
	_button("Save", func() -> void:
		if not clan and not progress.found_clan(name_edit.text):
			name_edit.placeholder_text = "Clan name — needed"
			return
		progress.clan.icon = picked[0]
		progress.clan.motto = motto.text.strip_edges()
		progress.clan.rules.clear()
		for rule_id in spins:
			if spins[rule_id].value > 0:
				progress.clan.rules[rule_id] = int(spins[rule_id].value)
		Sfx.ui(self, "buying")
		purchased.emit("clan")
		show_page())
	_button("Back", show_page if clan else show_requirements)


## Members, places, search and invites; invites wait for co-op.
func _members() -> void:
	var head := HBoxContainer.new()
	var count := Label.new()
	count.text = "Members 1 / %d" % Clan.SLOTS
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var search := LineEdit.new()
	search.placeholder_text = "Search"
	search.custom_minimum_size.x = 140
	var invite := Button.new()
	invite.text = "Add player"
	invite.disabled = true
	invite.tooltip_text = "Invites come with co-op."
	head.add_child(count)
	head.add_child(search)
	head.add_child(invite)
	_box.add_child(head)
	var you := _label("You (chief)")
	search.text_changed.connect(func(text: String) -> void: you.visible = text == "" or "you chief".contains(text.to_lower()))


func show_page() -> void:
	var clan: Clan = progress.clan
	_clear(clan.name)
	var head := TextureRect.new()
	head.texture = load(ICON_DIR + clan.icon + ".png")
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.custom_minimum_size = Vector2(64, 64)
	_box.add_child(head)
	if clan.motto != "":
		_label("\"%s\"" % clan.motto)
	_label("Status: %s  ·  rating %d" % [clan.tier_name(), clan.rating()])
	_label("Hunts: %d   Boars killed: %d   caught: %d   Terminators: %d" % [clan.deeds["hunts"], clan.deeds["kills"],
		clan.deeds["captures"], clan.deeds["terminators"]])
	var rules := PackedStringArray()
	for rule_id in clan.rules:
		rules.append("%s %d" % [Clan.RULES[rule_id], clan.rules[rule_id]])
	_label("Join rules: %s" % (", ".join(rules) if not rules.is_empty() else "none"))
	var earned := clan.achievements()
	_label("Achievements: %s" % (", ".join(earned) if not earned.is_empty() else "none yet"))
	_button("Edit clan", show_form)
	_button("All clans", show_list)


func _clear(title: String) -> void:
	_title.text = title
	for child in _box.get_children():
		child.queue_free()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(label)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	_box.add_child(button)
	return button
