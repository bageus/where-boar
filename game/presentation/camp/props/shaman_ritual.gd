extends Node3D

## The shaman's ritual round the shaman hut (issue #20): the hut's sign counts down to the next ritual; while
## it lasts a glowing circle and mist lie round the hut and the hunter standing in the circle is blessed.

const Shaman = preload("res://game/features/settlement/public/shaman.gd")

## Fact: the hunter was blessed (the camp saves).
signal blessed

## Injected before entering the tree.
var progress: RefCounted
var hunter: Node3D
var label: Label3D
var _circle := MeshInstance3D.new()
var _mist := MeshInstance3D.new()
var _wait := 0.0


func _ready() -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = Shaman.RADIUS
	ring.bottom_radius = Shaman.RADIUS
	ring.height = 0.04
	_circle.mesh = ring
	_circle.material_override = _glow(Color(0.55, 1.0, 0.75, 0.35))
	_circle.position.y = 0.03
	var mist := CylinderMesh.new()
	mist.top_radius = Shaman.RADIUS * 0.9
	mist.bottom_radius = Shaman.RADIUS
	mist.height = 1.6
	mist.cap_top = false
	mist.cap_bottom = false
	_mist.mesh = mist
	_mist.material_override = _glow(Color(0.85, 0.9, 1.0, 0.18))
	_mist.position.y = 0.8
	for node: MeshInstance3D in [_circle, _mist]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 0.5
	var now := int(Time.get_unix_time_from_system())
	var on := Shaman.active(now)
	_circle.visible = on
	_mist.visible = on
	var left := Shaman.seconds_left(now)
	var blessed_for: int = progress.blessed_until - now
	label.text = "Shaman hut\n%s %d:%02d%s" % ["Ritual!" if on else "Ritual in", left / 60, left % 60,
		"\nBlessed %d min" % (blessed_for / 60) if blessed_for > 0 else ""]
	var at := hunter.global_position - global_position
	if on and Vector2(at.x, at.z).length() <= Shaman.RADIUS and blessed_for < Shaman.BLESSING - 60:
		progress.blessed_until = now + Shaman.BLESSING
		blessed.emit()


static func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material
