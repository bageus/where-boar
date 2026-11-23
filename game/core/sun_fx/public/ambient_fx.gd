class_name AmbientFx
extends Node

## Ambient effects of a scene (camp, hunt, gather): trees and bushes swaying (Wind), leaves drifting on the wind past the
## camera, glints on the water (water_glint.gdshaderinc), and, when `campfire` is set, its light and fireflies that
## come out at night (DayNight.dark). Add as a child; quality follows SunFx.quality (low: none of it but the fire light).

const GROUP := "ambient_fx"
const LEAVES := {"low": 0, "medium": 24, "high": 60}
const FIREFLIES := {"low": 0, "medium": 12, "high": 28}

## Set before adding to the tree: the campfire station of the camp.
var campfire: Node3D

var _leaves: CPUParticles3D
var _leaf_material: StandardMaterial3D
var _fireflies: CPUParticles3D
var _light: OmniLight3D
var _time := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_leaves = _make_leaves()
	add_child(_leaves)
	if campfire:
		_fireflies = _make_fireflies()
		_fireflies.position = campfire.global_position + Vector3(0.0, 1.6, 0.0)
		add_child(_fireflies)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.6, 0.28)
		_light.omni_range = 16.0
		_light.light_energy = 0.0
		_light.shadow_enabled = false
		_light.position = campfire.global_position + Vector3(0.0, 1.2, 0.0)
		add_child(_light)
	restyle()


func restyle() -> void:
	var quality := SunFx.quality
	Wind.apply(0.0 if quality == "low" else 1.0)
	RenderingServer.global_shader_parameter_set("glint_strength", {"low": 0.0, "medium": 0.6, "high": 1.0}[quality])
	_leaves.amount = maxi(LEAVES[quality], 1)
	_leaves.emitting = LEAVES[quality] > 0
	if _fireflies:
		_fireflies.amount = maxi(FIREFLIES[quality], 1)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("glint_strength", 0.0)


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_3d()
	if camera:  # upwind and above, so the wind carries the leaves across the view
		_leaves.global_position = camera.global_position + Vector3(-12.0, 7.0, 0.0)
	var dark := DayNight.dark if get_tree().has_group(DayNight.GROUP) else 0.0
	_leaf_material.albedo_color = Color.WHITE.lerp(Color(0.25, 0.28, 0.4), dark)
	if _fireflies:
		_fireflies.visible = dark > 0.6 and FIREFLIES[SunFx.quality] > 0
		_fireflies.emitting = _fireflies.visible
		var flicker := 0.85 + 0.15 * sin(_time * 13.0) * sin(_time * 7.3)
		_light.light_energy = dark * 3.0 * flicker


func _make_leaves() -> CPUParticles3D:
	var texture := GradientTexture2D.new()  # a soft ellipse; alpha scissor cuts it into a leaf shape
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = Gradient.new()
	texture.gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	texture.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	_leaf_material = StandardMaterial3D.new()
	_leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_leaf_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_leaf_material.vertex_color_use_as_albedo = true
	_leaf_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_leaf_material.albedo_texture = texture
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.17)
	quad.material = _leaf_material
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray([Color(0.35, 0.65, 0.15), Color(0.8, 0.75, 0.2), Color(0.85, 0.45, 0.12)])
	var p := CPUParticles3D.new()
	p.mesh = quad
	p.local_coords = false
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(10.0, 2.0, 16.0)
	p.direction = Vector3(1.0, -0.35, 0.15)
	p.spread = 25.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.2, -0.15, 0.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.color_initial_ramp = ramp
	return p


func _make_fireflies() -> CPUParticles3D:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 1.0, 0.4)
	glow.emission_enabled = true
	glow.emission = Color(0.9, 1.0, 0.35)
	glow.emission_energy_multiplier = 4.0
	var bead := SphereMesh.new()
	bead.radius = 0.035
	bead.height = 0.07
	bead.radial_segments = 6
	bead.rings = 3
	bead.material = glow
	var blink := Curve.new()  # fades in and out, twice per life
	for point: Vector2 in [Vector2(0, 0), Vector2(0.15, 1), Vector2(0.3, 0.1), Vector2(0.5, 1), Vector2(0.7, 0.1), Vector2(0.85, 1), Vector2(1, 0)]:
		blink.add_point(point)
	var p := CPUParticles3D.new()
	p.mesh = bead
	p.local_coords = false
	p.lifetime = 6.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.0, 1.4, 7.0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.scale_amount_curve = blink
	p.emitting = false
	return p
