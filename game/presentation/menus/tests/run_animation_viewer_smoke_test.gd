extends SceneTree

## Loads the animation viewer headless: both cavemen have every animation, the boar shows only for
## riding, and Back reports that the viewer closed.

const Viewer = preload("res://game/presentation/menus/public/animation_viewer.tscn")

var _failures := 0
var _viewer: Node3D


func _initialize() -> void:
	_viewer = Viewer.instantiate()
	root.add_child(_viewer)


func _process(_delta: float) -> bool:
	var viewer := _viewer
	for model_name: String in viewer.MODELS:
		viewer.show_model(model_name)
		for anim: String in viewer.ANIMATIONS:
			_check(viewer.player.has_animation(anim), "%s has %s" % [model_name, anim])
			viewer.play(anim)
			_check(viewer.player.current_animation == anim, "%s plays %s" % [model_name, anim])
			_check(viewer.get_node("%Boar").visible == (anim == "ride"), "boar only for ride (%s)" % anim)
		viewer.play("ride")
		_check(viewer.character.position.y > 0.3, "%s sits on the boar" % model_name)
	var closed := [false]
	viewer.closed.connect(func() -> void: closed[0] = true)
	viewer.get_node("%Back").pressed.emit()
	_check(closed[0], "Back closes the viewer")
	print("animation viewer smoke: %d failures" % _failures)
	quit(1 if _failures else 0)
	return true


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAILED: " + what)
