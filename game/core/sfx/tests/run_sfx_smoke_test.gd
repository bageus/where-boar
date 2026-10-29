extends SceneTree

## Needs the imported project (run after `godot --headless --editor --quit`).

const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const SfxLoop = preload("res://game/core/sfx/public/sfx_loop.gd")


func _init() -> void:
	var failures := 0
	var groups := Array(DirAccess.get_directories_at(Sfx.ROOT))
	failures += _check(groups.size() >= 30, "at least 30 sound groups")
	failures += _check(groups.all(func(g: String) -> bool: return Sfx.stream(g).streams_count > 0), "every group has takes")
	failures += _check(Sfx.stream("boar_cry") == Sfx.stream("boar_cry"), "a group is loaded once and shared")
	failures += _check(Sfx.stream("boar_panic").streams_count == 10, "panic has 5 takes and 5 reversed")
	var scene := Node3D.new()
	root.add_child(scene)
	await process_frame  # root children enter the tree after _init
	var one := Sfx.play(scene, "club", 0.0, 20.0)
	var loop := SfxLoop.new()
	scene.add_child(loop)
	await process_frame
	await process_frame
	failures += _check(one.playing and one.max_distance == 20.0, "a one-shot plays")
	var playing := loop.get_children().filter(func(p: AudioStreamPlayer3D) -> bool: return p.playing)
	failures += _check(playing.size() == 1, "the campfire loop starts one take")
	print("sfx smoke test: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1
