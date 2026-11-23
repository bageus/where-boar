extends SceneTree

## Loads the animation viewer headless: the rigged hunters have every animation and the lanky caveman his own,
## every weapon goes into a hand bone and attack clips pick a weapon made for them, the boar shows only for
## riding, every boar type and bird has its animations, and Back reports that the viewer closed.

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
		if model_name != "Lanky":
			_check(viewer.animations == viewer.ANIMATIONS, "%s has every animation" % model_name)
		for weapon_name: String in viewer.WEAPONS:
			viewer.show_weapon(weapon_name)
			_check(viewer._held.get_parent() is BoneAttachment3D, "%s holds the %s" % [model_name, weapon_name])
		for anim: String in viewer.animations:
			viewer.play(anim)
			_check(viewer.weapon in viewer.CLIP_WEAPONS.get(anim, [viewer.weapon]), "%s fits %s" % [viewer.weapon, anim])
			_check(viewer.player.current_animation == anim, "%s plays %s" % [model_name, anim])
			_check(viewer.get_node("%Boar").visible == (anim == "ride"), "boar only for ride (%s)" % anim)
		viewer.play("ride")
		_check(viewer.character.position.y > 0.3, "%s sits on the boar" % model_name)
	for boar_type: Resource in viewer.BoarTypes.ALL:
		viewer.show_boar(boar_type.id)
		for anim: String in viewer.BOAR_ANIMATIONS:
			viewer.play(anim)
			_check(viewer.player.current_animation == anim, "%s plays %s" % [boar_type.id, anim])
		_check(not viewer.get_node("%Boar").visible, "no saddle boar under " + boar_type.id)
	for bird_name: String in viewer.BIRDS:
		viewer.show_bird(bird_name)
		for anim: String in viewer.BIRD_ANIMATIONS:
			viewer.play(anim)
			_check(viewer.player.current_animation == anim, "%s plays %s" % [bird_name, anim])
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
