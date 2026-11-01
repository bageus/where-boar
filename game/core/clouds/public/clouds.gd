extends Node3D

## Toy clouds (owner, 2026-10-29): a few flattened white balls each, high above the scene, drifting along +x.
## Shared by the camp vista and the hunt map. One shared sphere mesh and material, no shadows, so it is cheap.

const COUNT := 14
const DRIFT := 1.2  # metres per second, along +x
const SPAN := 900.0

var _clouds: Array[Node3D] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1)
	material.emission_enabled = true
	material.emission = Color(0.85, 0.88, 0.95)
	material.emission_energy_multiplier = 0.45
	material.roughness = 1.0
	var ball := SphereMesh.new()
	ball.radial_segments = 16
	ball.rings = 8
	ball.material = material
	for n in COUNT:
		var cloud := Node3D.new()
		var angle := rng.randf() * TAU
		var far := rng.randf_range(140.0, 380.0)
		cloud.position = Vector3(cos(angle) * far, rng.randf_range(55.0, 95.0), sin(angle) * far)
		var size := rng.randf_range(6.0, 11.0)
		for b in rng.randi_range(4, 7):
			var puff := MeshInstance3D.new()
			puff.mesh = ball
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var r := size * rng.randf_range(0.7, 1.3) * (1.3 if b == 0 else 1.0)
			puff.scale = Vector3(r * 2.0, r * 1.3, r * 1.6)
			puff.position = Vector3(rng.randf_range(-1.6, 1.6) * size, rng.randf_range(0.0, 0.5) * size, rng.randf_range(-0.7, 0.7) * size)
			cloud.add_child(puff)
		add_child(cloud)
		_clouds.append(cloud)


func _process(delta: float) -> void:
	for cloud in _clouds:
		cloud.position.x += DRIFT * delta
		if cloud.position.x > SPAN * 0.5:
			cloud.position.x -= SPAN
