extends AudioStreamPlayer

## Hunt music (owner, 2026-11-05): once the hunter has hit a boar, the 8-second loops of music_hunt play one
## after another in random order, seamlessly, while any boar still runs; when every boar has calmed down the
## music fades out and waits for the next hit.

const Sfx = preload("res://game/core/sfx/public/sfx.gd")

const VOLUME_DB := -8.0
const FADE_SECONDS := 2.0
const CHECK_SECONDS := 0.5
const RUNNING_STATES := ["FLEE", "PANIC", "CHARGE"]

## The map's boar container; injected before the node enters the tree.
var boars: Node

var _engaged := false
var _check_left := 0.0
var _fade: Tween


func _ready() -> void:
	var playlist := AudioStreamPlaylist.new()
	var takes := Sfx.stream("music_hunt")
	playlist.stream_count = takes.streams_count
	for i in takes.streams_count:
		playlist.set_list_stream(i, takes.get_stream(i))
	playlist.shuffle = true
	playlist.loop = true
	playlist.fade_time = 0.0  # each take is exactly one loop long, so they join without a seam
	stream = playlist


## A boar was hit: the music starts if it is not playing yet.
func engage() -> void:
	_engaged = true
	_check_left = 3.0  # give the herd a moment to start running
	if not playing or (_fade and _fade.is_running()):
		_to(VOLUME_DB)


func _process(delta: float) -> void:
	_check_left -= delta
	if not _engaged or _check_left > 0.0:
		return
	_check_left = CHECK_SECONDS
	if not boars.get_children().any(func(boar: Node) -> bool:
			return boar.state_name() in RUNNING_STATES and not boar.is_hiding()):
		_engaged = false
		_to(-60.0)


func _to(volume: float) -> void:
	if _fade:
		_fade.kill()
	if volume > -60.0 and not playing:
		volume_db = -40.0
		play()
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", volume, FADE_SECONDS if volume <= -60.0 else 0.5)
	if volume <= -60.0:
		_fade.tween_callback(stop)
