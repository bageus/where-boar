extends Node3D

## Distant birds over the camp's vista: each sits on the valley floor, takes off, flies an arc to
## another perch and settles down again (owner, 2026-10-29). Pure decoration, no collision.

const COUNT := 12
## Where the birds perch, in the valley east and south-east of the drop-off.
const AREA_X := Vector2(70.0, 320.0)
const AREA_Z := Vector2(-160.0, 260.0)
const SIT_TIME := Vector2(3.0, 12.0)
const FLIGHT_SPEED := 14.0
const FLAP_HZ := 5.0

## Valley ground height at (x, z); set by the vista before the birds enter the tree.
var height_at: Callable

var _rng := RandomNumberGenerator.new()
var _birds: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = 33
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.1, 0.1)
	var body := CapsuleMesh.new()
	body.radius = 0.25
	body.height = 1.2
	body.material = material
	var wing := BoxMesh.new()
	wing.size = Vector3(1.3, 0.06, 0.55)
	wing.material = material
	for n in COUNT:
		var bird := Node3D.new()
		var trunk := MeshInstance3D.new()
		trunk.mesh = body
		trunk.rotation.x = PI / 2
		bird.add_child(trunk)
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			var blade := MeshInstance3D.new()
			blade.mesh = wing
			blade.position.x = side * 0.7
			pivot.add_child(blade)
			bird.add_child(pivot)
		bird.scale = Vector3.ONE * 1.6
		add_child(bird)
		var at := _perch()
		bird.position = at
		_birds.append({"node": bird, "from": at, "to": at, "t": 1.0, "duration": 1.0, "rest": _rng.randf_range(0.0, SIT_TIME.y)})


func _process(delta: float) -> void:
	for bird in _birds:
		var node: Node3D = bird["node"]
		if bird["rest"] > 0.0:
			bird["rest"] -= delta
			_wings(node, 1.2)  # folded
			if bird["rest"] <= 0.0:
				_take_off(bird)
			continue
		bird["t"] = minf(1.0, bird["t"] + delta / bird["duration"])
		var t: float = bird["t"]
		var lift: float = bird["lift"]
		var from: Vector3 = bird["from"]
		var to: Vector3 = bird["to"]
		var at := from.lerp(to, t) + Vector3.UP * lift * sin(PI * t)
		var ahead := from.lerp(to, minf(1.0, t + 0.02)) + Vector3.UP * lift * sin(PI * minf(1.0, t + 0.02))
		if not at.is_equal_approx(ahead):
			node.look_at_from_position(at, at + (ahead - at) * Vector3(1, 0.3, 1), Vector3.UP)
		node.position = at
		# Hard flapping near the ground, glides on the way.
		var glide := sin(PI * t)
		var beat := sin(Time.get_ticks_msec() * 0.001 * TAU * FLAP_HZ + bird["phase"])
		_wings(node, beat * lerpf(0.9, 0.25, glide * glide))
		if t >= 1.0:
			node.rotation = Vector3(0.0, node.rotation.y, 0.0)
			bird["rest"] = _rng.randf_range(SIT_TIME.x, SIT_TIME.y)


func _take_off(bird: Dictionary) -> void:
	bird["from"] = bird["node"].position
	bird["to"] = _perch()
	var length: float = bird["from"].distance_to(bird["to"])
	bird["duration"] = length / FLIGHT_SPEED
	bird["lift"] = clampf(length * 0.35, 15.0, 60.0)
	bird["phase"] = _rng.randf() * TAU
	bird["t"] = 0.0


## Wing angle in radians: positive lifts both tips up.
func _wings(bird: Node3D, angle: float) -> void:
	bird.get_child(1).rotation.z = -angle
	bird.get_child(2).rotation.z = angle


## A dry spot on the valley floor.
func _perch() -> Vector3:
	while true:
		var x := _rng.randf_range(AREA_X.x, AREA_X.y)
		var z := _rng.randf_range(AREA_Z.x, AREA_Z.y)
		var y: float = height_at.call(x, z)
		if y > -44.0:
			return Vector3(x, y + 0.4, z)
	return Vector3.ZERO
