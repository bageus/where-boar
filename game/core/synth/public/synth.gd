extends RefCounted

## Placeholder sound effects synthesized at startup (sections 16, 17). Replace with recorded assets later.
## shortcut: synthesized blips, swap for licensed recordings in phase 5.

const RATE := 22050

static var _cache: Dictionary = {}


## Rising, wobbling squeal of a hit boar.
static func squeal() -> AudioStreamWAV:
	return _cached("squeal", func(t: float) -> float:
		var pitch := 700.0 + 900.0 * t / 0.35 + 60.0 * sin(TAU * 18.0 * t)
		return sin(TAU * pitch * t) * (1.0 - t / 0.35), 0.35)


## Short low thump of a hoof; played over and over by running boars.
static func stomp() -> AudioStreamWAV:
	return _cached("stomp", func(t: float) -> float:
		return (sin(TAU * 70.0 * t) + 0.4 * randf_range(-1.0, 1.0)) * exp(-t * 40.0), 0.12)


## Heavy body hit when a boar rams the hunter.
static func thud() -> AudioStreamWAV:
	return _cached("thud", func(t: float) -> float:
		return (sin(TAU * 55.0 * t) + 0.6 * randf_range(-1.0, 1.0)) * exp(-t * 12.0), 0.4)


static func _cached(key: String, wave: Callable, seconds: float) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = _render(wave, seconds)
	return _cache[key]


## 16-bit mono PCM of wave(t) in [-1, 1] over seconds.
static func _render(wave: Callable, seconds: float) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(wave.call(float(i) / RATE), -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
