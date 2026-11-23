extends PanelContainer

## Gear box window (issue #15): the hunter's pack on the left, the camp gear box on the right. A row
## moves with the arrow buttons between the lists or by dragging it across; baits and traps go one at
## a time, a weapon with its whole stack. The pack's room per slot and the tusks show below.

const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const ItemIcons = preload("res://game/features/settlement/public/item_icons.gd")

## Fact: the pack changed; the camp re-equips the hunter and saves.
signal changed
signal closed

const SLOT_NAMES := {"main": "Main weapon", "weapon": "Weapons", "bait": "Baits", "trap": "Traps", "armor": "Armor", "tool": "Tools"}

var progress: Progress
var _pack: ItemList
var _box: ItemList
var _tusks := Label.new()
var _room := Label.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(760, 540)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var title := Label.new()
	title.text = "Gear box"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_tusks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_tusks)
	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(lists)
	_pack = _list(lists, "Your pack")
	var arrows := VBoxContainer.new()
	arrows.alignment = BoxContainer.ALIGNMENT_CENTER
	lists.add_child(arrows)
	_box = _list(lists, "Gear box")
	for arrow: Array in [["→", _pack, false], ["←", _box, true]]:
		var button := Button.new()
		button.text = arrow[0]
		button.custom_minimum_size = Vector2(48, 40)
		button.pressed.connect(func() -> void:
			var picked: PackedInt32Array = arrow[1].get_selected_items()
			if not picked.is_empty():
				_move(arrow[1].get_item_metadata(picked[0]), arrow[2]))
		arrows.add_child(button)
	_room.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(_room)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	column.add_child(close_button)
	hide()


func open() -> void:
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _list(parent: Container, heading: String) -> ItemList:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(side)
	var label := Label.new()
	label.text = heading
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(label)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(28, 28)
	side.add_child(list)
	list.item_activated.connect(func(index: int) -> void: _move(list.get_item_metadata(index), list == _box))
	list.set_drag_forwarding(
		func(at: Vector2) -> Variant:
			var index := list.get_item_at_position(at, true)
			return null if index < 0 else {"from": list, "id": list.get_item_metadata(index)},
		func(_at: Vector2, data: Variant) -> bool: return data is Dictionary and data.get("from") != list,
		func(_at: Vector2, data: Variant) -> void: _move(data["id"], data["from"] == _box))
	return list


## Packs item_id from the box (to_pack) or puts it back.
func _move(item_id: String, to_pack: bool) -> void:
	if to_pack:
		progress.carry(item_id)
	else:
		progress.store(item_id)
	_refresh()
	changed.emit()


func _refresh() -> void:
	_tusks.text = "Tusks: %d" % progress.tusks
	_pack.clear()
	_box.clear()
	for item_id: String in ShopCatalog.ITEMS:
		if not ShopCatalog.ITEMS[item_id].has("slot"):
			continue
		for side: Array in [[_pack, progress.carried.get(item_id, 0)], [_box, progress.in_box(item_id)]]:
			if side[1] > 0:
				var index: int = side[0].add_item("%s  x%d" % [ShopCatalog.ITEMS[item_id]["name"], side[1]], ItemIcons.of(item_id))
				side[0].set_item_metadata(index, item_id)
	var room := PackedStringArray(["Knife: always"])
	for slot: String in ShopCatalog.SLOTS:
		room.append("%s: %d / %d" % [SLOT_NAMES[slot], progress.slot_used(slot), progress.slot_cap(slot)])
	_room.text = "   ".join(room)
