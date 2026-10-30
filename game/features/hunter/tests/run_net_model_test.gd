extends SceneTree

## The rigged net headless: hangs and opens; on a boar it lies over the back, reaches the ground on both
## sides and follows the forward fall.

const NetModel = preload("res://game/features/hunter/presentation/net_model.tscn")
const BoarModel = preload("res://game/features/boar/public/boar_model.gd")
const BoarTypes = preload("res://game/features/boar/public/boar_types.gd")

var _boar: Node3D
var _net: Node3D
var _frames := 0
var _before: Array[Vector3] = []
var _failures := 0


func _initialize() -> void:
	_boar = Node3D.new()
	_boar.set_script(BoarModel)
	root.add_child(_boar)
	_boar.show_type(BoarTypes.find("common_brown"))
	_net = NetModel.instantiate()
	root.add_child(_net)


func _wrap() -> void:
	_net.open()
	_net.wrap(_boar)
	var top: float = _boar.top()
	var ys: Array[float] = []
	for b in _net._bones:
		ys.append(_bone(b).y)
	_check(ys.max() > top * 0.6 and ys.max() < top + 0.2, "net lies on the back (%.2f, back %.2f)" % [ys.max(), top])
	_check(ys.min() > -0.01 and ys.min() < 0.05, "net hangs to the ground (%.2f)" % ys.min())
	for b in _net._bones:
		_before.append(_bone(b))
	_boar.net_fall()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_wrap()
	if _frames < 90:
		return false
	var moved := 0.0
	for i in _before.size():
		moved = maxf(moved, _bone(_net._bones[i]).distance_to(_before[i]))
	_check(moved > 0.1, "net follows the boar's fall (%.2f)" % moved)
	print("net model test: %d failure(s)" % _failures)
	quit(1 if _failures else 0)
	return true


func _bone(b: int) -> Vector3:
	var skeleton: Skeleton3D = _net._skeleton
	return skeleton.global_transform * skeleton.get_bone_global_pose(b).origin


func _check(ok: bool, name: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL: " + name)
