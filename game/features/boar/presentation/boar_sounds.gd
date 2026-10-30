extends Node3D

## A boar's sounds (owner's recordings, 2026-10-29), all heard where the boar is: a call when it starts
## to run so the others know (each boar picks another take, a little later than the last), squeals
## layered and some reversed while it panics, a squeal when hit, a grunt at the ram, hooves while it runs
## (splashes in a river, also at a walk), and quiet grunts now and then while it roams or eats.

const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const Footsteps = preload("res://game/core/sfx/public/footsteps.gd")

const VOICE_MIN_SECONDS := 5.0
const VOICE_MAX_SECONDS := 15.0
const PANIC_MIN_SECONDS := 0.4
const PANIC_MAX_SECONDS := 1.0
## Chance a panic squeal gets a second take over it.
const PANIC_LAYER_CHANCE := 0.4
## A call starts up to this late, so a herd's calls overlap without all starting at once.
const CRY_DELAY_SECONDS := 0.5
const CRY_DISTANCE := 50.0

## Set by the boar: true while fleeing, panicking or charging; panicking only in panic.
var running := false:
	set(value):
		running = value
		if _steps:
			_steps.active = value
var panicking := false

var _voice_left := randf_range(0.0, VOICE_MAX_SECONDS)
var _panic_left := 0.0
var _steps: Footsteps


func _ready() -> void:
	_steps = Footsteps.new()
	_steps.ground = "boar_step"
	_steps.stride = 2.5
	_steps.volume_db = -6.0
	_steps.max_distance = 30.0
	_steps.active = running
	add_child(_steps)


## Hit by a weapon.
func squeal() -> void:
	Sfx.play(self, "boar_panic", 0.0, 40.0)


## Started to run: the call that warns the herd.
func cry() -> void:
	Sfx.play(self, "boar_cry", 0.0, CRY_DISTANCE, randf() * CRY_DELAY_SECONDS)


## Locked on to ram the hunter.
func attack() -> void:
	Sfx.play(self, "boar_attack", 0.0, 30.0)


func _process(delta: float) -> void:
	if panicking:
		_panic_left -= delta
		if _panic_left <= 0.0:
			_panic_left = randf_range(PANIC_MIN_SECONDS, PANIC_MAX_SECONDS)
			Sfx.play(self, "boar_panic", -3.0, 40.0)
			if randf() < PANIC_LAYER_CHANCE:
				Sfx.play(self, "boar_panic", -6.0, 40.0, randf_range(0.1, 0.3))
	elif not running:
		_voice_left -= delta
		if _voice_left <= 0.0:
			_voice_left = randf_range(VOICE_MIN_SECONDS, VOICE_MAX_SECONDS)
			Sfx.play(self, "boar_voice", -4.0, 40.0)
