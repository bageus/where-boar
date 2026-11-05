extends Node3D

## The hunter's body and gear sounds (owner, 2026-11-05), read from the hunter's state each frame:
## a grunt when hurt, a heartbeat at low health, gasping when stamina runs low or out, a sip of water,
## landing after a jump, a rustle on crouching (reversed on standing up), a swipe on changing weapons,
## and the "no supplies" click when water, bait or traps are out.

const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## The heartbeat sounds at or below this health. The owner asked for 10, but every ram takes at least 20 of 100,
## so 20 (one ram from going down) is the lowest value the hunter can stand at.
const LOW_HEALTH := 20
## Below this share of max stamina the short gasp loops; at zero one deep gasp.
const LOW_STAMINA_SHARE := 0.1
## Landing counts after at least this long in the air (a jump, not a step down).
const LANDING_AIR_SECONDS := 0.35

var _health := -1
var _weapon := -1
var _crouching := false
var _sips := -1
var _air := 0.0
var _out_of_breath := false
var _heartbeat: AudioStreamPlayer3D
var _gasp: AudioStreamPlayer3D

@onready var _hunter: CharacterBody3D = get_parent()


func _physics_process(delta: float) -> void:
	var health: int = _hunter.health.value
	if _health >= 0 and health < _health:
		Sfx.play(self, "man_damage")
	_health = health
	if health <= LOW_HEALTH and health > 0 and not is_instance_valid(_heartbeat):
		_heartbeat = Sfx.play(self, "heartbeat")
	_breathe()
	if _weapon >= 0 and _hunter.weapon != _weapon:
		Sfx.play(self, "swipe", -4.0)
	_weapon = _hunter.weapon
	if _hunter.crouching != _crouching:
		Sfx.play(self, "rustle" if _hunter.crouching else "rustle_up", -6.0)
	_crouching = _hunter.crouching
	var sips: int = _hunter.loadout.water_sips
	if _sips >= 0 and sips < _sips:
		Sfx.play(self, "sip_water")
	_sips = sips
	if _hunter.is_on_floor():
		if _air >= LANDING_AIR_SECONDS and not _hunter.ride.is_riding():
			Sfx.play(self, "landing", -2.0)
		_air = 0.0
	else:
		_air += delta


## Short gasps loop while stamina is low; running dry gives one deep gasp (owner, 2026-11-05).
func _breathe() -> void:
	var stamina = _hunter.stamina
	if stamina.value <= 0.0:
		if not _out_of_breath:
			_out_of_breath = true
			if is_instance_valid(_gasp):
				_gasp.stop()
			_gasp = Sfx.play(self, "breath_out")
		return
	_out_of_breath = false
	if stamina.value < stamina.max_value * LOW_STAMINA_SHARE and not is_instance_valid(_gasp):
		_gasp = Sfx.play(self, "breath_low", -2.0)


## Runs before the hunter handles the key, so the stock seen here is what the key will find.
func _unhandled_input(event: InputEvent) -> void:
	var loadout = _hunter.loadout
	var out := false
	if event.is_action_pressed("drink"):
		out = loadout.water_sips == 0
	elif _hunter.get_node("Hud").menu_open():
		return
	elif event.is_action_released("bait"):
		out = loadout.baits.values().all(func(n: int) -> bool: return n == 0)
	elif event.is_action_released("trap_place") and _hunter.get("_laying_wire") == null and _hunter.get("_placement") == null:
		out = loadout.active_trap() == ""
	if out:
		Sfx.play(self, "no_ammo", -3.0)
