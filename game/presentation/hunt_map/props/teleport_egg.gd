extends Node3D

## Terminator teleport sphere (issue 8): a glowing blue egg swells on the ground, crackles, opens
## (opened: the terminator steps out here) and fades away.

signal opened

const RADIUS := 1.3
const GROW_SECONDS := 0.35
const CRACKLES := 5
const CRACKLE_SECONDS := 0.12
const FADE_SECONDS := 0.6


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.65, 0.88, 1.0, 0.85)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.material = material
	var shell := MeshInstance3D.new()
	shell.mesh = sphere
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.8, 1.0)
	light.omni_range = 9.0
	add_child(light)
	scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, GROW_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for n in CRACKLES:
		tween.tween_property(light, "light_energy", 6.0 if n % 2 == 0 else 1.5, CRACKLE_SECONDS)
	tween.tween_callback(opened.emit)
	tween.set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, FADE_SECONDS)
	tween.tween_property(light, "light_energy", 0.0, FADE_SECONDS)
	tween.chain().tween_callback(queue_free)
