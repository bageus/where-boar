extends RefCounted

## The owner's recorded sounds (2026-10-29): every folder assets/sfx/<group>/ is one group of takes.
## A group plays a random take, never the same one twice in a row, with a little random pitch and volume,
## so repeated sounds (steps, grunts, cries) never sound alike.

const ROOT := "res://assets/sfx/"
const PITCH_SPREAD := 1.12
const VOLUME_SPREAD_DB := 2.0

static var _groups: Dictionary = {}


## All takes of group as one random stream, made once and shared.
static func stream(group: String) -> AudioStreamRandomizer:
	if not _groups.has(group):
		var randomizer := AudioStreamRandomizer.new()
		randomizer.random_pitch = PITCH_SPREAD
		randomizer.random_volume_offset_db = VOLUME_SPREAD_DB
		for file in ResourceLoader.list_directory(ROOT + group):
			if file.get_extension() == "wav":
				randomizer.add_stream(-1, load(ROOT + group + "/" + file))
		assert(randomizer.streams_count > 0, "no sounds in " + ROOT + group)
		_groups[group] = randomizer
	return _groups[group]


## Loads every group now, so the first sound of a kind in play doesn't stall the frame decoding its files.
static func preload_all() -> void:
	for group in ResourceLoader.list_directory(ROOT):
		stream(group.trim_suffix("/"))


## One take of group heard at parent and moving with it, after delay seconds; heard up to max_distance metres.
## The player frees itself when done (or with parent).
static func play(parent: Node3D, group: String, volume_db := 0.0, max_distance := 30.0, delay := 0.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(group)
	player.volume_db = volume_db
	player.max_distance = max_distance
	player.unit_size = max_distance / 4.0
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	if delay > 0.0:
		player.get_tree().create_timer(delay).timeout.connect(player.play)
	else:
		player.play()
	return player
