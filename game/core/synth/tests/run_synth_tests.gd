extends SceneTree

const Synth = preload("res://game/core/synth/public/synth.gd")


func _init() -> void:
	var failures := 0
	var thud := Synth.thud()
	failures += _check(thud.data.size() == int(0.4 * Synth.RATE) * 2, "thud has 0.4 s of 16-bit samples")
	failures += _check(Synth.thud() == thud, "sounds are made once and reused")
	print("synth tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1
