extends PanelContainer

## Camp shop window: lists a shop's catalog items and buys them with tusks (M013).

const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopCatalog = preload("res://game/features/settlement/public/shop_catalog.gd")

## Fact: an item was bought; the camp passes it on so the game saves.
signal purchased(item_id: String)
signal closed

## Bait icons are 128 px wide; a third of that (owner, 2026-10-30).
const ICON_WIDTH := 43

var progress: Progress
var _shop_id := ""


func _ready() -> void:
	%Close.pressed.connect(close)
	hide()


func open(shop_id: String, title: String) -> void:
	_shop_id = shop_id
	%Title.text = title
	_refresh()
	show()


func close() -> void:
	hide()
	closed.emit()


func _refresh() -> void:
	for child in %Items.get_children():
		child.queue_free()
	for item_id in ShopCatalog.for_shop(_shop_id):
		var item: Dictionary = ShopCatalog.ITEMS[item_id]
		var button := Button.new()
		var owned: bool = progress.sold_out(item_id)
		var count: String = "" if item["unique"] else "  (have %d)" % progress.items.get(item_id, 0)
		var locked := "" if progress.unlocked(item_id) else "  (catch one first)"
		var taken := "taken" if item.has("companion") else ("owned" if item["unique"] else "max")
		var price_text: String = taken if owned else ("free" if ShopCatalog.price(item_id) == 0 else "%d tusks" % ShopCatalog.price(item_id))
		if item.has("icon"):
			button.icon = load(item["icon"])
			button.add_theme_constant_override("icon_max_width", ICON_WIDTH)
			button.text = "%s%s" % [price_text, count]
		else:
			button.text = "%s — %s%s%s" % [item["name"], price_text, count, locked]
		button.disabled = owned or progress.tusks < ShopCatalog.price(item_id) or locked != ""
		button.pressed.connect(_buy.bind(item_id))
		%Items.add_child(button)
	%Tusks.text = "Tusks: %d" % progress.tusks


func _buy(item_id: String) -> void:
	if progress.buy(item_id):
		purchased.emit(item_id)
	_refresh()
