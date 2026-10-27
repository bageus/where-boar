extends Node3D

## A boar's sounds (section 16): a squeal when hit or scared, hoof stomps while it runs,
## quiet grunts now and then while it roams for food.

const Synth = preload("res://game/core/synth/public/synth.gd")

const STOMP_SECONDS := 0.28
const GRUNT_MIN_SECONDS := 3.0
const GRUNT_MAX_SECONDS := 8.0

## Set by the boar: true while fleeing, panicking or charging.
var running := false

var _stomp_left := 0.0
var _grunt_left := randf_range(0.0, GRUNT_MAX_SECONDS)

@onready var _voice: AudioStreamPlayer3D = $Voice
@onready var _hooves: AudioStreamPlayer3D = $Hooves
@onready var _grunt: AudioStreamPlayer3D = $Grunt


func _ready() -> void:
	_voice.stream = Synth.squeal()
	_hooves.stream = Synth.stomp()
	_grunt.stream = Synth.grunt()


func squeal() -> void:
	_voice.pitch_scale = randf_range(0.85, 1.2)
	_voice.play()


func _process(delta: float) -> void:
	if not running:
		_grunt_left -= delta
		if _grunt_left <= 0.0:
			_grunt_left = randf_range(GRUNT_MIN_SECONDS, GRUNT_MAX_SECONDS)
			_grunt.pitch_scale = randf_range(0.85, 1.15)
			_grunt.play()
		return
	_stomp_left -= delta
	if _stomp_left <= 0.0:
		_stomp_left = STOMP_SECONDS
		_hooves.pitch_scale = randf_range(0.8, 1.1)
		_hooves.play()
