extends PanelContainer

## Camp shop window: lists a shop's catalog items and buys them with tusks (M013). Shops that buy forest
## finds have a Sell resources button in the same place (issues #18, #21, #28); the quest board lists its
## quests here too (issue #25).

const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## Fact: an item was bought (or resources sold, a quest claimed); the camp passes it on so the game saves.
signal purchased(item_id: String)
signal closed

## Bait icons are 128 px wide; a third of that (owner, 2026-10-30).
const ICON_WIDTH := 43

var progress: Progress
## Extra line under the tusks: the forge's build, a hut's state.
var info := ""
var _shop_id := ""
var _selling := false
## The forge's open recipe tab (issue #11).
var _tab: String = ShopCatalog.FORGE_TABS[0]


func _ready() -> void:
	%Close.pressed.connect(close)
	%Sell.pressed.connect(func() -> void:
		_selling = not _selling
		_refresh())
	hide()


func open(shop_id: String, title: String) -> void:
	_shop_id = shop_id
	_selling = false
	%Title.text = title
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _process(_delta: float) -> void:
	if visible and _shop_id == "quests":
		%Info.text = "New quests in %s" % _clock(progress.quests.renews_at - int(Time.get_unix_time_from_system()))


func _refresh() -> void:
	for child in %Items.get_children():
		child.queue_free()
	%Tusks.text = "Tusks: %d" % progress.tusks
	if _shop_id == "forge":
		_forge_header()
	if _shop_id == "tavern":
		var team := progress.team()
		info = "In your team: %s" % (", ".join(team) if not team.is_empty() else "nobody yet")
	%Info.text = info
	%Info.visible = info != "" or _shop_id == "quests"
	%Sell.visible = ShopCatalog.SELL.has(_shop_id)
	%Sell.text = "Back to the shop" if _selling else "Sell resources"
	if _selling:
		_sell_rows()
	elif _shop_id == "quests":
		_quest_rows()
	else:
		_item_rows()


## The building site shows its bar and givers (one player for now, so just you); the built forge its recipe
## tabs and the metal in stock (issue #11).
func _forge_header() -> void:
	if not progress.forge_built():
		info = "Built: %d / %d tusks\nGivers:\n  You — %d tusks" % [progress.forge, ShopCatalog.FORGE_COST, progress.forge]
		var bar := ProgressBar.new()
		bar.max_value = ShopCatalog.FORGE_COST
		bar.value = progress.forge
		%Items.add_child(bar)
		return
	var stock := PackedStringArray()
	for part_id in ShopCatalog.PART_NAMES:
		stock.append("%d %s" % [progress.items.get(part_id, 0), ShopCatalog.PART_NAMES[part_id]])
	info = "In stock: " + ", ".join(stock)
	var tabs := HBoxContainer.new()
	for tab in ShopCatalog.FORGE_TABS:
		var button := Button.new()
		button.text = tab
		button.toggle_mode = true
		button.button_pressed = tab == _tab
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_tab = tab
			_refresh())
		tabs.add_child(button)
	%Items.add_child(tabs)


func _item_rows() -> void:
	for item_id in ShopCatalog.for_shop(_shop_id):
		var item: Dictionary = ShopCatalog.ITEMS[item_id]
		if _shop_id == "forge" and (item.get("tab", "") != _tab if progress.forge_built() else not item.has("donate")):
			continue
		var button := Button.new()
		var owned: bool = progress.sold_out(item_id)
		var count: String = "" if item["unique"] or item.has("donate") else "  (have %d)" % progress.items.get(item_id, 0)
		var locked := "" if progress.unlocked(item_id) else "  (catch one first)"
		var taken := "taken" if item.has("companion") else ("owned" if item["unique"] else "max")
		var price_text: String = taken if owned else ("free" if ShopCatalog.price(item_id) == 0 else "%d tusks" % ShopCatalog.price(item_id))
		var short := "" if owned or progress.tusks >= ShopCatalog.price(item_id) else "  (not enough tusks)"
		if short == "" and not owned and not progress.has_parts(item_id):
			short = "  (not enough metal)"
		var parts := ShopCatalog.parts(item_id)
		for part_id in parts:
			price_text += ", %d %s" % [parts[part_id], ShopCatalog.PART_NAMES[part_id]]
		if item.has("donate"):
			price_text = "%d tusks" % item["donate"]
		if item.has("icon"):
			button.icon = load(item["icon"])
			button.add_theme_constant_override("icon_max_width", ICON_WIDTH)
			button.text = "%s%s" % [price_text, count]
		else:
			button.text = "%s — %s%s%s%s" % [item["name"], price_text, count, locked, short]
		button.disabled = owned or short != "" or locked != "" or (item.has("donate") and progress.forge_built())
		button.pressed.connect(_buy.bind(item_id))
		%Items.add_child(button)


## One row per material the shop buys: a slider in whole tusks' worth, and a sell button showing the pay.
func _sell_rows() -> void:
	var total := 0
	var prices: Dictionary = ShopCatalog.SELL[_shop_id]
	for material_id: String in prices:
		var units: int = prices[material_id]
		var have: int = progress.materials.get(material_id, 0)
		total += have / units
		var label := Label.new()
		label.text = "%s: %d  (%d for 1 tusk)" % [ShopCatalog.MATERIAL_NAMES[material_id], have, units]
		var row := HBoxContainer.new()
		var slider := HSlider.new()
		slider.step = units
		slider.max_value = have / units * units
		slider.value = slider.max_value
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		var show_pay := func(value: float) -> void:
			button.text = "Sell %d — %d tusks" % [int(value), int(value) / units]
			button.disabled = value < units
		show_pay.call(slider.value)
		slider.value_changed.connect(show_pay)
		button.pressed.connect(func() -> void: _sell({material_id: int(slider.value)}))
		row.add_child(slider)
		row.add_child(button)
		%Items.add_child(label)
		%Items.add_child(row)
	var all := Button.new()
	all.text = "Sell all — %d tusks" % total
	all.disabled = total == 0
	var everything := {}
	for material_id: String in prices:
		everything[material_id] = progress.materials.get(material_id, 0)
	all.pressed.connect(_sell.bind(everything))
	%Items.add_child(all)


func _quest_rows() -> void:
	var board := progress.quests
	board.renew_if_due(int(Time.get_unix_time_from_system()))
	for i in board.quests.size():
		var quest: Dictionary = board.quests[i]
		var button := Button.new()
		var line := "%s (%d tusks)" % [board.text(i), quest["reward"]]
		match quest["state"]:
			"open":
				button.text = "%s — accept" % line
				button.pressed.connect(func() -> void:
					board.accept(i)
					purchased.emit("quest")
					_refresh())
			"accepted":
				var claimable := board.can_claim(i, progress.materials)
				button.text = "%s — %s" % [line, "claim" if claimable else "%d / %d" % [mini(board.have(i, progress.materials), quest["amount"]), quest["amount"]]]
				button.disabled = not claimable
				button.pressed.connect(func() -> void:
					if progress.claim_quest(i):
						Sfx.ui(self, "tusk")
						purchased.emit("quest")
					_refresh())
			_:
				button.text = "%s — done" % line
				button.disabled = true
		%Items.add_child(button)


func _sell(counts: Dictionary) -> void:
	var earned := 0
	for material_id: String in counts:
		earned += progress.sell(material_id, counts[material_id], ShopCatalog.SELL[_shop_id][material_id])
	if earned > 0:
		Sfx.ui(self, "tusk")
		purchased.emit("sell")
	_refresh()


func _buy(item_id: String) -> void:
	if progress.buy(item_id):
		Sfx.ui(self, "buying")
		purchased.emit(item_id)
	_refresh()


static func _clock(seconds: int) -> String:
	seconds = maxi(seconds, 0)
	return "%d:%02d:%02d" % [seconds / 3600, seconds / 60 % 60, seconds % 60]
