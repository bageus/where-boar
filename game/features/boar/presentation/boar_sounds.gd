extends Node3D

## A boar's sounds (section 16): a squeal when hit and hoof stomps while it runs.

const Synth = preload("res://game/core/synth/public/synth.gd")

const STOMP_SECONDS := 0.28

## Set by the boar: true while fleeing, panicking or charging.
var running := false

var _stomp_left := 0.0

@onready var _voice: AudioStreamPlayer3D = $Voice
@onready var _hooves: AudioStreamPlayer3D = $Hooves


func _ready() -> void:
	_voice.stream = Synth.squeal()
	_hooves.stream = Synth.stomp()


func squeal() -> void:
	_voice.pitch_scale = randf_range(0.85, 1.2)
	_voice.play()


func _process(delta: float) -> void:
	if not running:
		return
	_stomp_left -= delta
	if _stomp_left <= 0.0:
		_stomp_left = STOMP_SECONDS
		_hooves.pitch_scale = randf_range(0.8, 1.1)
		_hooves.play()
