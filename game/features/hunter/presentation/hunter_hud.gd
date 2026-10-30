extends CanvasLayer

## The hunter's HUD (section 16): health and stamina bars, weapon hotbar; active bait on the left and trap on
## the right (hold the key for a ring menu), water under stamina, trap build bar and "+N" pickups (owner, 2026-10-28).

const Loadout = preload("res://game/features/hunter/domain/loadout.gd")
const BuildSite = preload("res://game/features/hunter/presentation/traps/build_site.gd")

const WEAPON_NAMES := ["Spear", "Net", "Club", "Sling", "Bow", "Knife"]

var _gain_fade: Tween
var _prompt_pulse: Tween


func _ready() -> void:
	for weapon_name in WEAPON_NAMES:
		var slot := Label.new()
		slot.add_theme_font_size_override("font_size", 22)
		$Hotbar.add_child(slot)


## The "E" keycap above the stamina bar pulses while something in reach can be used.
func show_interact(on: bool) -> void:
	var prompt: Control = $InteractPrompt
	if _prompt_pulse:
		_prompt_pulse.kill()
	prompt.visible = on
	if on:
		_prompt_pulse = create_tween().set_loops()
		_prompt_pulse.tween_property(prompt, "scale", Vector2.ONE * 1.18, 0.45).set_trans(Tween.TRANS_SINE)
		_prompt_pulse.tween_property(prompt, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func show_health(value: int) -> void:
	$Health.value = value


## Throw power bar under the crosshair, shown only while aiming (playtest 2026-10-27).
func show_throw_power(aiming: bool, power: float) -> void:
	$ThrowPower.visible = aiming
	$ThrowPower.value = power * 100.0


func show_stamina(value: float, max_value: float) -> void:
	# Meals raise the maximum above 100 (e.g. 120%); the label shows the real value.
	$Stamina.max_value = max_value
	$Stamina.value = value
	$Stamina/Value.text = "Stamina %d%%" % roundi(value)


func show_loadout(loadout: Loadout, weapon: Loadout.Weapon) -> void:
	# Ammo shows what is carried now / the carry cap (owner, 2026-10-27).
	var extras := [
		" %d/%d" % [loadout.spears, loadout.max_spears],
		" %d/%d" % [loadout.nets, loadout.net_cap],
		"",
		" %d/%d" % [loadout.stones, loadout.stone_cap],
		" %d/%d" % [loadout.arrows, loadout.arrow_cap],
		"",
	]
	for i in WEAPON_NAMES.size():
		var slot: Label = $Hotbar.get_child(i)
		slot.visible = loadout.has(i)
		slot.text = "[%d] %s%s" % [i + 1, WEAPON_NAMES[i], extras[i]]
		slot.modulate = Color.YELLOW if weapon == i else Color.WHITE
	$Bait.text = "[F] %s x%d" % [_name(loadout.bait_id), loadout.baits.get(loadout.bait_id, 0)]
	$Trap.text = "[T] %s x%d" % [_name(loadout.trap_id), loadout.traps.get(loadout.trap_id, 0)]
	$Water.text = "[Q] Water %d/%d" % [loadout.water_sips, Loadout.WATER_SIPS]


## Opens the bait ("bait") or trap ("trap") ring with what is carried of each.
func open_menu(loadout: Loadout, key: String) -> void:
	var ids: Array = Loadout.BAIT_IDS if key == "bait" else Loadout.TRAP_IDS
	var stock: Dictionary = loadout.baits if key == "bait" else loadout.traps
	$Menu.open(ids, ids.map(func(item_id: String) -> String: return "%s x%d" % [_name(item_id), stock.get(item_id, 0)]))


func menu_open() -> bool:
	return $Menu.visible


## Closes the ring; the picked item id or "".
func close_menu() -> String:
	return $Menu.close()


## Build bar for the trap ghost in reach (null hides it).
func show_build(site: Node3D) -> void:
	$Build.visible = site != null and BuildSite.is_ghost(site)
	if $Build.visible:
		$Build.value = BuildSite.progress(site) * 100.0
		$Build/Value.text = "Hold E: build %s %d%%" % [_name(site.get_meta("item_id", "")), roundi($Build.value)]


## "+N ..." in the middle of the screen, fading out.
func show_gain(text: String) -> void:
	$Gain.text = text
	$Gain.modulate.a = 1.0
	if _gain_fade:
		_gain_fade.kill()
	_gain_fade = create_tween()
	_gain_fade.tween_property($Gain, "modulate:a", 0.0, 1.0).set_delay(1.0)


func show_helper(text: String) -> void:
	$Helper.text = text


static func _name(item_id: String) -> String:
	return item_id.trim_prefix("item_").capitalize()
