class_name DayNight
extends Node

## Day, evening and night in the camp and the gather map (the hunt is always day and never adds this). Add as a child of a
## scene with a WorldEnvironment "Environment" (ProceduralSkyMaterial sky) and a DirectionalLight3D "Sun" (+ optional
## "Sun/SunDisc"); the scene's own values are "day". The time is a setting (pause menu): DayNight.set_time(...).
## The sun stays where it is (baked shadows), only its colour and strength change, so night is moonlight.

const GROUP := "day_night"
const TIMES: Array[String] = ["day", "evening", "night"]
const SPEED := 0.7  # keyframes per second

## 0 = day, 1 = night: read by AmbientFx (fire light, fireflies, leaf shade).
static var dark := 0.0
static var time := "day"

# Evening and night looks, as (sky top, horizon, ground horizon, ambient, fog, sun colour, sun energy factor, ground bottom).
const LOOKS := [
	[Color(0.3, 0.24, 0.5), Color(1.0, 0.58, 0.32), Color(0.6, 0.4, 0.35), Color(0.62, 0.45, 0.42), Color(0.95, 0.6, 0.45), Color(1.0, 0.55, 0.3), 0.7, Color(0.3, 0.2, 0.2)],
	[Color(0.02, 0.03, 0.1), Color(0.07, 0.1, 0.22), Color(0.03, 0.04, 0.08), Color(0.13, 0.16, 0.32), Color(0.04, 0.06, 0.14), Color(0.45, 0.55, 0.95), 0.18, Color(0.02, 0.03, 0.06)],
]

var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _disc: DirectionalLight3D
var _day: Array = []  # the scene's own values, in LOOKS order
var _sun_energy: float
var _disc_energy := 0.0
var _at := 0.0  # current keyframe, 0..2
var _target := 0.0


static func set_time(value: String, tree: SceneTree = null) -> void:
	time = value if value in TIMES else "day"
	if tree:
		tree.call_group(GROUP, "retarget")


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS  # the change shows behind the pause menu
	_env = (get_parent().get_node("Environment") as WorldEnvironment).environment
	_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_sun = get_parent().get_node("Sun")
	_disc = _sun.get_node_or_null("SunDisc")
	_day = [_sky.sky_top_color, _sky.sky_horizon_color, _sky.ground_horizon_color, _env.ambient_light_color, _env.fog_light_color, _sun.light_color, 1.0, _sky.ground_bottom_color]
	_sun_energy = _sun.light_energy
	_disc_energy = _disc.light_energy if _disc else 0.0
	_at = TIMES.find(time)
	retarget()
	_apply()


func retarget() -> void:
	_target = TIMES.find(time)


func _process(delta: float) -> void:
	dark = _at / 2.0
	if not is_equal_approx(_at, _target):
		_at = move_toward(_at, _target, SPEED * delta)
		_apply()


func _apply() -> void:
	var i := mini(int(_at), 1)  # from the look i-1 (day when 0) to look i
	var k := _at - i
	var from: Array = _day if i == 0 else LOOKS[0]
	var to: Array = LOOKS[i]
	var mix := func(n: int) -> Color: return from[n].lerp(to[n], k)
	_sky.sky_top_color = mix.call(0)
	_sky.sky_horizon_color = mix.call(1)
	_sky.ground_horizon_color = mix.call(2)
	_sky.ground_bottom_color = mix.call(7)
	_env.ambient_light_color = mix.call(3)
	_env.fog_light_color = mix.call(4)
	_sun.light_color = mix.call(5)
	_sun.light_energy = _sun_energy * lerpf(from[6], to[6], k)
	var daylight := 1.0 - clampf(_at - 1.0, 0.0, 1.0)  # the sun disc and light shafts are gone by night
	if _disc:
		_disc.light_energy = _disc_energy * daylight
	get_tree().call_group(SunFx.GROUP, "set_daylight", daylight)
