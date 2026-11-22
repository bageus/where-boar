extends SceneTree

const LevelLayout = preload("res://game/core/level_layout/public/level_layout.gd")
const STUMP := "res://assets/nature/meshes/peak/PeakStump1.res"


func _init() -> void:
	var failures := 0
	failures += _check(_transform_round_trip(), "a transform survives the 12-float form")
	failures += _check(_capture_then_apply(), "a captured layout moves, removes and adds the same on a fresh level")
	failures += _check(_nature_palette_loads(), "every nature palette entry makes an object")
	print("level layout tests: %d failure(s)" % failures)
	quit(1 if failures else 0)


func _check(ok: bool, name: String) -> int:
	if not ok:
		push_error("FAIL: " + name)
	return 0 if ok else 1


func _transform_round_trip() -> bool:
	var t := Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3.ONE * 1.3), Vector3(1, 2, 3))
	return LevelLayout.from_array(JSON.parse_string(JSON.stringify(LevelLayout.to_array(t)))).is_equal_approx(t)


## A level with Props/A and Props/B.
func _level() -> Node3D:
	var level := Node3D.new()
	var props := Node3D.new()
	props.name = "Props"
	level.add_child(props)
	for n in ["A", "B"]:
		var node := Node3D.new()
		node.name = n
		props.add_child(node)
		node.set_meta(LevelLayout.START_META, node.transform)
	return level


func _capture_then_apply() -> bool:
	var edited := _level()
	var props := edited.get_node("Props")
	props.get_node("A").position = Vector3(5, 0, 1)
	props.get_node("B").free()
	var stump := LevelLayout.make(STUMP, "box")
	stump.name = "Stump1"
	stump.position = Vector3(-2, 0, 4)
	props.add_child(stump)
	var data := LevelLayout.capture(edited, props.get_children(), ["Props/B"])
	data = JSON.parse_string(JSON.stringify(data))  # as saved
	var fresh := _level()
	LevelLayout.apply(fresh, data)
	var ok: bool = fresh.get_node("Props/A").position.is_equal_approx(Vector3(5, 0, 1)) \
			and not fresh.has_node("Props/B") \
			and fresh.get_node("Props/Stump1").position.is_equal_approx(Vector3(-2, 0, 4)) \
			and fresh.get_node("Props/Stump1").get_child_count() == 2
	edited.free()
	fresh.free()
	return ok


func _nature_palette_loads() -> bool:
	for entry in LevelLayout.nature_palette():
		var node := LevelLayout.make(entry["res"], entry["solid"])
		if node == null:
			push_error("cannot make " + entry["res"])
			return false
		node.free()
	return true
