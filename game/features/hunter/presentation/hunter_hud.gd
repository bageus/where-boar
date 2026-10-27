extends CanvasLayer

## The hunter's HUD (section 16): health and stamina bars, weapon hotbar, bait, traps and water.

const Loadout = preload("res://game/features/hunter/domain/loadout.gd")

const WEAPON_NAMES := ["Spear", "Net", "Club", "Sling", "Bow"]


func _ready() -> void:
	for weapon_name in WEAPON_NAMES:
		var slot := Label.new()
		slot.add_theme_font_size_override("font_size", 22)
		$Hotbar.add_child(slot)


func show_health(value: int) -> void:
	$Health.value = value


func show_stamina(value: float, max_value: float) -> void:
	$Stamina.max_value = max_value
	$Stamina.value = value


func show_loadout(loadout: Loadout, weapon: Loadout.Weapon) -> void:
	var extras := [
		" (in hand)" if loadout.spear_in_hand else " (thrown)",
		" x%d" % loadout.nets,
		"",
		"",
		" x%d" % loadout.arrows,
	]
	for i in WEAPON_NAMES.size():
		var slot: Label = $Hotbar.get_child(i)
		slot.visible = loadout.has(i)
		slot.text = "[%d] %s%s" % [i + 1, WEAPON_NAMES[i], extras[i]]
		slot.modulate = Color.YELLOW if weapon == i else Color.WHITE
	var bait_counts := PackedStringArray()
	for item_id in Loadout.BAIT_IDS:
		bait_counts.append("%s %d" % [item_id.trim_prefix("item_"), loadout.baits.get(item_id, 0)])
	var trap_id := loadout.selected_trap()
	$Bait.text = "[F] Bait: %s    [R] Shout    [G/T] Trap: %s x%d    [Q] Water x%d" % [
		", ".join(bait_counts), trap_id.trim_prefix("item_"), loadout.traps.get(trap_id, 0), loadout.water_sips]
