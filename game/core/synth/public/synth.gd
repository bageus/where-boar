extends RefCounted

## Placeholder sound effects synthesized at startup (sections 16, 17); the owner's recordings (core.sfx) replaced
## all but the thud of a ram.
## shortcut: synthesized thud, swap when a recording comes.

const RATE := 22050

static var _cache: Dictionary = {}


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
