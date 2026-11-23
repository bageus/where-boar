class_name SunFx
extends Node

## Post-processing and sun effects for a scene that has a WorldEnvironment "Environment" and a DirectionalLight3D "Sun"
## as siblings (camp, hunt map, gather map). Add as a child; it styles the environment and draws a screen-space sun
## (disc, lens glow, soft light shafts). Cheap: one full-screen shader, no volumetrics (works on the Compatibility renderer).
## Quality is global: SunFx.set_quality("low" | "medium" | "high") re-styles every live SunFx.

const GROUP := "sun_fx"
const QUALITIES: Array[String] = ["low", "medium", "high"]
const SHAFTS := preload("res://game/core/sun_fx/public/sun_shafts.gdshader")

static var quality := "high"

var _env: Environment
var _sun: DirectionalLight3D
var _material: ShaderMaterial
var _layer: CanvasLayer
var _rect: ColorRect
var _daylight := 1.0  # 1 by day, 0 at night (DayNight): no light shafts, sun scatter or sun disc glow


## Sets the quality for the live scene and for those created later.
static func set_quality(level: String, tree: SceneTree = null) -> void:
	quality = level if level in QUALITIES else "high"
	if tree:
		tree.call_group(GROUP, "restyle")
		tree.call_group("ambient_fx", "restyle")


func _ready() -> void:
	add_to_group(GROUP)
	_env = (get_parent().get_node("Environment") as WorldEnvironment).environment
	_sun = get_parent().get_node("Sun")
	_sun.light_color = Color(1.0, 0.95, 0.84)  # warm; DayNight changes it later
	_material = ShaderMaterial.new()
	_material.shader = SHAFTS
	_layer = CanvasLayer.new()
	_layer.layer = -1  # under the HUD
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_layer.add_child(_rect)
	add_child(_layer)
	restyle()


## DayNight sets how much sun is left: 1 day, 0 night.
func set_daylight(value: float) -> void:
	_daylight = value
	if _material:
		restyle()


func restyle() -> void:
	var level := QUALITIES.find(quality)
	var viewport := get_viewport()
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][level]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if level == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	# Warm filmic look; the cartoon colours stay saturated.
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.05
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.12
	_env.adjustment_contrast = 1.06
	_env.glow_enabled = level >= 1
	_env.glow_intensity = 0.55
	_env.glow_strength = 0.9
	_env.glow_bloom = 0.08
	_env.glow_hdr_threshold = 0.85
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.fog_sun_scatter = (0.25 if level >= 1 else 0.0) * _daylight
	_material.set_shader_parameter("shafts", (1.0 if level >= 2 else 0.0) * _daylight)
	_rect.visible = _daylight > 0.0


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var toward_sun := _sun.global_basis.z  # light travels along -z, so the sun sits along +z
	var facing := toward_sun.dot(-camera.global_basis.z)
	var uv := camera.unproject_position(camera.global_position + toward_sun * 1000.0) / Vector2(get_viewport().get_visible_rect().size)
	_material.set_shader_parameter("sun_uv", uv)
	_material.set_shader_parameter("facing", clampf(facing * 3.0, 0.0, 1.0))
	_material.set_shader_parameter("aspect", get_viewport().get_visible_rect().size.aspect())
