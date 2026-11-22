extends Node3D

## A frog: waits, then makes 1-3 hops of random length in random directions (owner 2026-11-22), staying on the grass.

const WAIT := Vector2(1.0, 6.0)
const HOP_ANIM_SECONDS := 1.5  # length of the imported Jump clip

var terrain: Node3D
var anim: AnimationPlayer
var anim_name := ""
var _wait := randf_range(0.0, 4.0)
var _hops_left := 0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _hop_seconds := 0.0


func _process(delta: float) -> void:
	if _hop_seconds <= 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_hops_left = [1, 1, 2, 3].pick_random()
			_hop()
		return
	_t += delta
	var k := minf(_t / _hop_seconds, 1.0)
	var at := _from.lerp(_to, k)
	position = Vector3(at.x, terrain.height_at(at.x, at.y), at.y)
	if k >= 1.0:
		_hop_seconds = 0.0
		_hops_left -= 1
		if _hops_left > 0:
			_hop()
		else:
			_wait = randf_range(WAIT.x, WAIT.y)


func _hop() -> void:
	var length := randf_range(0.3, 0.7) if randf() < 0.5 else randf_range(1.2, 2.2)
	var yaw := rotation.y + randf_range(-1.0, 1.0)
	var heading := Vector2(-sin(yaw), -cos(yaw))
	_from = Vector2(position.x, position.z)
	_to = _from + heading * length
	if not terrain.grassy_at(_to.x, _to.y):  # water, sand or a cliff ahead: turn back
		yaw += PI
		_to = _from - heading * length
		if not terrain.grassy_at(_to.x, _to.y):
			_wait = 1.0
			_hops_left = 0
			return
	rotation.y = yaw
	_hop_seconds = 0.45 + length * 0.2
	_t = 0.0
	anim.speed_scale = HOP_ANIM_SECONDS / _hop_seconds
	anim.play(anim_name)
