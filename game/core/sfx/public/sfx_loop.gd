extends Node3D

## An endless ambient bed made of a group's long takes (owner, 2026-10-29): campfire, jungle, river, cliff wind.
## Each take enters at a random point, swells in, plays a while and fades out at another random point; the
## next one starts before the last has faded, so takes overlap and blend and no seam is heard.
## Takes shorter than LONG_SECONDS (the jungle's chirps) are dropped in now and then on top.

const Sfx = preload("res://game/core/sfx/public/sfx.gd")

const SILENT_DB := -40.0
const LONG_SECONDS := 4.0
## Each take fades in and out over this many seconds.
const FADE_SECONDS := Vector2(1.5, 3.0)
## Share of a take that may be skipped at its start or end.
const TRIM_SHARE := 0.25
const ACCENT_SECONDS := Vector2(4.0, 10.0)

@export var group := "campfire"
@export var volume_db := 0.0
## Heard up to this far, metres; 0 is heard everywhere at the same level (not placed in the world).
@export var max_distance := 10.0
## Loop one take picked at random instead of all of them (the cliff wind).
@export var single_take := false

var _long: Array[AudioStream] = []
var _short: Array[AudioStream] = []
var _next_left := 0.0
var _accent_left := 0.0


func _ready() -> void:
	var takes := Sfx.stream(group)
	for i in takes.streams_count:
		var take := takes.get_stream(i)
		(_long if take.get_length() >= LONG_SECONDS else _short).append(take)
	if single_take:
		_long = [_long.pick_random()]
	_accent_left = randf_range(ACCENT_SECONDS.x, ACCENT_SECONDS.y)


func _process(delta: float) -> void:
	_next_left -= delta
	if _next_left <= 0.0:
		_next_left = _play_take()
	if _short.is_empty():
		return
	_accent_left -= delta
	if _accent_left <= 0.0:
		_accent_left = randf_range(ACCENT_SECONDS.x, ACCENT_SECONDS.y)
		var accent := _player(_short.pick_random())
		accent.volume_db = volume_db - randf_range(3.0, 9.0)
		accent.finished.connect(accent.queue_free)
		accent.play()


## Starts one take and returns the seconds until the next should start.
func _play_take() -> float:
	var take: AudioStream = _long.pick_random()
	var length := take.get_length()
	var from := randf() * length * TRIM_SHARE
	var span := length * (1.0 - TRIM_SHARE) - from + randf() * length * TRIM_SHARE  # from..to, at least half the take
	var fade_in := randf_range(FADE_SECONDS.x, FADE_SECONDS.y)
	var fade_out := randf_range(FADE_SECONDS.x, FADE_SECONDS.y)
	var player := _player(take)
	player.volume_db = SILENT_DB
	player.play(from)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", volume_db, fade_in).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(maxf(0.0, span - fade_in - fade_out))
	tween.tween_property(player, "volume_db", SILENT_DB, fade_out).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(player.queue_free)
	# The next take swells in while this one is still at full level.
	return maxf(1.0, span - fade_out - randf_range(FADE_SECONDS.x, FADE_SECONDS.y))


func _player(take: AudioStream) -> Node:
	var player: Node
	if max_distance > 0.0:
		player = AudioStreamPlayer3D.new()
		player.max_distance = max_distance
		player.unit_size = max_distance / 4.0
	else:
		player = AudioStreamPlayer.new()
	player.stream = take
	add_child(player)
	return player
