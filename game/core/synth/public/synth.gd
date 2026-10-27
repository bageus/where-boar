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


## Low, rough grunt of a boar rooting for food.
static func grunt() -> AudioStreamWAV:
	return _cached("grunt", func(t: float) -> float:
		var buzz := signf(sin(TAU * (95.0 - 40.0 * t) * t)) * 0.5 + 0.3 * randf_range(-1.0, 1.0)
		return buzz * sin(PI * t / 0.25), 0.25)


## The hunter's shout: a short falling "hey!" with a rough edge.
static func shout() -> AudioStreamWAV:
	return _cached("shout", func(t: float) -> float:
		var pitch := 320.0 - 300.0 * t
		var voice := sin(TAU * pitch * t) + 0.5 * sin(TAU * pitch * 2.0 * t) + 0.15 * randf_range(-1.0, 1.0)
		return 0.6 * voice * minf(1.0, t * 40.0) * (1.0 - t / 0.4), 0.4)


## Rooster's alarmed crow: two quick rising notes.
static func crow() -> AudioStreamWAV:
	return _cached("crow", func(t: float) -> float:
		var note := fmod(t, 0.15) / 0.15
		var pitch := 900.0 + 500.0 * note
		return sin(TAU * pitch * t) * sin(PI * note) * 0.7, 0.3)


## Turkey's gobble: a fast warble.
static func gobble() -> AudioStreamWAV:
	return _cached("gobble", func(t: float) -> float:
		var pitch := 450.0 + 120.0 * sin(TAU * 25.0 * t)
		return sin(TAU * pitch * t) * (1.0 - t / 0.35) * 0.7, 0.35)


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
