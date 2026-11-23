extends SkeletonModifier3D

## Idle head play for a standing boar (owner, 2026-11-23): the head turns a little left or right, now and then
## dips or lifts, and sometimes sniffs (quick small nods). Added on top of the playing clip's pose.

const BONES: Array[String] = ["neck", "Neck", "head", "Head"]
const MAX_YAW := 18.0  # degrees (ASSUMPTION)
const MAX_PITCH := 12.0
const HOLD_SECONDS := Vector2(1.2, 3.5)
const SNIFF_SECONDS := 1.0
const SNIFF_CHANCE := 0.3
const EASE := 4.0

var _yaw := 0.0
var _pitch := 0.0
var _target := Vector2.ZERO  # yaw, pitch in degrees
var _hold := 0.0
var _sniff := 0.0
var _time := randf() * 10.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var delta := get_process_delta_time()
	_time += delta
	_hold -= delta
	if _hold <= 0.0:
		_hold = randf_range(HOLD_SECONDS.x, HOLD_SECONDS.y)
		_target = Vector2(randf_range(-MAX_YAW, MAX_YAW), randf_range(-MAX_PITCH, MAX_PITCH))
		if randf() < SNIFF_CHANCE:
			_sniff = SNIFF_SECONDS
			_target.y = MAX_PITCH * 0.5
	_sniff = maxf(_sniff - delta, 0.0)
	_yaw = lerpf(_yaw, _target.x, minf(EASE * delta, 1.0))
	_pitch = lerpf(_pitch, _target.y, minf(EASE * delta, 1.0))
	var nod := sin(_time * 22.0) * 4.0 * (_sniff / SNIFF_SECONDS)
	var turn := Quaternion(Vector3.UP, deg_to_rad(_yaw)) * Quaternion(Vector3.RIGHT, deg_to_rad(_pitch + nod))
	for bone in BONES:
		var i := skeleton.find_bone(bone)
		if i < 0:
			continue
		var global := skeleton.get_bone_global_rest(i).basis.get_rotation_quaternion()
		var part := Quaternion.IDENTITY.slerp(turn, 0.5)  # neck and head each take half
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * (global.inverse() * part * global))
