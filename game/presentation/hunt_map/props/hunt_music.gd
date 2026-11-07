extends AudioStreamPlayer

## Hunt music (owner, 2026-11-07): once the hunter has hit a boar, one random 8-second take of music_hunt
## loops seamlessly while any boar still runs; when every boar has calmed down the
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


## One random take loops (sample-accurate OGG loop, no seam) until the herd calms down; the next
## attack picks another take.
func _pick_take() -> void:
	var takes := Sfx.stream("music_hunt")
	var next := randi() % takes.streams_count
	if takes.streams_count > 1 and takes.get_stream(next) == stream:
		next = (next + 1) % takes.streams_count
	var take: AudioStreamOggVorbis = takes.get_stream(next)
	take.loop = true
	stream = take


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
		_pick_take()
		play()
	_fade = create_tween()
	_fade.tween_property(self, "volume_db", volume, FADE_SECONDS if volume <= -60.0 else 0.5)
	if volume <= -60.0:
		_fade.tween_callback(stop)
