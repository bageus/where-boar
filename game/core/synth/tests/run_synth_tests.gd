extends SceneTree

const Synth = preload("res://game/core/synth/public/synth.gd")


func _init() -> void:
	var failures := 0
	var squeal := Synth.squeal()
	failures += _check(squeal.data.size() == int(0.35 * Synth.RATE) * 2, "squeal has 0.35 s of 16-bit samples")
	failures += _check(Synth.squeal() == squeal, "sounds are made once and reused")
	failures += _check(Synth.stomp().get_length() > 0.1 and Synth.thud().get_length() > 0.3, "stomp and thud have length")
	print("synth tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1
