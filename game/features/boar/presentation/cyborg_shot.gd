extends Node3D

## A cyborg's round (owner, 2026-11-22): flies straight and fast enough to hit, slow enough to dodge or duck
## behind something. Hurts the hunter it touches; anything else solid stops it.

## How long a round flies before it fades out, seconds.
const LIFE := 3.0

var direction := Vector3.FORWARD
var speed := 16.0
var damage := 0
## Push given to the hunter on a hit, m/s.
var impulse := 2.0
var hunter: Node3D
## The shooter's own body, which the round must not hit as it leaves the barrel.
var exclude: Array[RID] = []
var _life := LIFE


## A glowing blob (cannon) or a thin streak (machinegun); call before add_child.
func setup(radius: float, length: float, colour: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(length, radius * 2.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	mesh.material = material
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.rotation.x = PI / 2.0  # capsule along the flight
	add_child(view)


func _ready() -> void:
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var step := direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position += step
		return
	if hit.collider == hunter and is_instance_valid(hunter):
		hunter.knock(Vector3(direction.x, 0.2, direction.z).normalized() * impulse, damage)
	queue_free()
