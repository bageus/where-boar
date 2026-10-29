extends Node3D

## An endless 3D ambient loop made of a group's long takes (campfire, river): the next take fades in while
## the last one fades out, so the seam is not heard (owner, 2026-10-29).

const Sfx = preload("res://game/core/sfx/public/sfx.gd")

const FADE_SECONDS := 2.0
const SILENT_DB := -40.0

@export var group := "campfire"
@export var volume_db := 0.0
@export var max_distance := 10.0

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _left := 0.0
var _take_seconds := INF


func _ready() -> void:
	# Own copy without random pitch, so every take lasts as long as the file.
	var takes: AudioStreamRandomizer = Sfx.stream(group).duplicate()
	takes.random_pitch = 1.0
	for i in takes.streams_count:
		_take_seconds = minf(_take_seconds, takes.get_stream(i).get_length())
	for i in 2:
		var player := AudioStreamPlayer3D.new()
		player.stream = takes
		player.max_distance = max_distance
		player.unit_size = max_distance / 4.0
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	var incoming := _players[_next]
	var outgoing := _players[1 - _next]
	_next = 1 - _next
	incoming.play()  # the random stream picks another take each time
	_left = _take_seconds - FADE_SECONDS
	var fade := create_tween().set_parallel()
	fade.tween_property(incoming, "volume_db", volume_db, FADE_SECONDS)
	fade.tween_property(outgoing, "volume_db", SILENT_DB, FADE_SECONDS)
	fade.chain().tween_callback(outgoing.stop)
