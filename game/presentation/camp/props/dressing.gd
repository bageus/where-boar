extends Node3D

## Camp ground dressing (owner, 2026-10-29): trodden ground at the campfire, in front of every
## entrance and along the paths to them and to the gate; ferns and bushes along the sides and backs of
## the buildings; pebbles scattered round the perimeter. The ground colours live in ground.gdshader.

const GROUND_MATERIAL := preload("res://game/presentation/camp/props/ground_material.tres")
const FERN_MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/06_upright_fern.res"), preload("res://assets/nature/meshes/07_small_fern.res"),
]  # the pack's two lightest ferns (3-3.5k triangles each)
const BUSH_SCENE := preload("res://assets/models/bush.glb")
const PEBBLE_MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/Rock1.res"), preload("res://assets/nature/meshes/Rock2.res"),
	preload("res://assets/nature/meshes/Rock3.res"), preload("res://assets/nature/meshes/Rock_1.res"),
	preload("res://assets/nature/meshes/Rock_10.res"),
]
const HALF := 17.0  # the camp's dirt square, as in ground.tscn and ground.gdshader
const SOUTH_SPLIT := 2.0
const GATE := Vector2(0.0, -HALF)
const PEBBLES := 90
const PLANTS_PER_BUILDING := 6
const FIRE_WORN_RADIUS := 4.2
const DOOR_WORN_RADIUS := 2.4
const PATH_WORN_RADIUS := 1.3
const MAX_WORN := 16  # the shader's array size


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var pebbles: Array[Transform3D] = []
	while pebbles.size() < PEBBLES:
		var p := Vector3(rng.randf_range(-HALF, HALF), 0.0, rng.randf_range(-HALF, HALF))
		var inset := HALF - maxf(absf(p.x), absf(p.z))
		if inset < rng.randf_range(0.2, 3.0) and not (p.z < -HALF + 3.0 and absf(p.x) < 2.5):
			pebbles.append(_flat(rng, p, rng.randf_range(0.12, 0.5)))
	_scatter(rng, PEBBLE_MESHES, pebbles, false)


## Wears the ground at the fire, the entrances and the gate, and plants greenery round each building.
## Each building's entrance faces its local +z.
func dress(fire: Vector3, gate_sign: Vector3, buildings: Array[Node3D]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var worn := PackedVector4Array([_strip(fire, fire), _strip(gate_sign, Vector3(GATE.x, 0.0, GATE.y))])
	var radii := PackedFloat32Array([FIRE_WORN_RADIUS, PATH_WORN_RADIUS * 1.4])
	var plants: Array[Transform3D] = []
	for building in buildings:
		var box := _footprint(building)
		var centre := box.get_center() * Vector3(1, 0, 1)
		var door := building.global_transform * ((centre + Vector3(0.0, 0.0, box.size.z * 0.5 + 0.8)) / building.scale)
		if worn.size() + 2 <= MAX_WORN:
			worn.append_array([_strip(door, door), _strip(door, fire)])
			radii.append_array([DOOR_WORN_RADIUS, PATH_WORN_RADIUS])
		for n in PLANTS_PER_BUILDING:
			# Round the sides and the back only: angle 0 is straight out of the door.
			var angle := rng.randf_range(0.8, TAU - 0.8)
			var out := Vector3(sin(angle) * box.size.x, 0.0, cos(angle) * box.size.z) * 0.5
			out += out.normalized() * rng.randf_range(0.1, 0.9)
			var at := building.global_transform * ((centre + out) / building.scale)
			if absf(at.x) < HALF - 0.4 and absf(at.z) < HALF - 0.4:
				plants.append(_flat(rng, at, rng.randf_range(0.5, 1.2)))
	var ferns: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	for t in plants:
		(bushes if rng.randf() < 0.4 else ferns).append(t)
	_scatter(rng, FERN_MESHES, ferns, false)
	_scatter(rng, [(BUSH_SCENE.instantiate().get_child(0) as MeshInstance3D).mesh], bushes, true)
	GROUND_MATERIAL.set_shader_parameter("worn_count", worn.size())
	GROUND_MATERIAL.set_shader_parameter("worn_from_to", worn)
	GROUND_MATERIAL.set_shader_parameter("worn_radius", radii)


## 1 deep in the grass border along the rock wall, the palisade and the south-west, 0 on bare dirt;
## the same wobbly band as greenness() in ground.gdshader.
static func greenness(p: Vector3) -> float:
	var g := maxf(_band(p.x + HALF, p.z), _band(p.z + HALF, p.x + 7.0))
	return maxf(g, _band(HALF - p.z, p.x + 3.0) * (1.0 - smoothstep(SOUTH_SPLIT - 4.0, SOUTH_SPLIT, p.x)))


static func _band(d: float, t: float) -> float:
	var w := 3.0 + 1.1 * sin(t * 0.37) + 0.6 * sin(t * 1.21 + 1.7)
	return 1.0 - smoothstep(w - 1.4, w + 0.4, d)


func _strip(from: Vector3, to: Vector3) -> Vector4:
	return Vector4(from.x, from.z, to.x, to.z)


## The building's mesh bounds in its own space, scale left out.
func _footprint(building: Node3D) -> AABB:
	var box := AABB()
	var inverse := building.global_transform.affine_inverse()
	for mesh: MeshInstance3D in building.find_children("*", "MeshInstance3D", true, false):
		var local := inverse * mesh.global_transform * mesh.get_aabb()
		box = local if box.size == Vector3.ZERO else box.merge(local)
	return AABB(box.position * building.scale, box.size * building.scale)


func _flat(rng: RandomNumberGenerator, at: Vector3, size: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), at)


## One MultiMesh per mesh: each transform goes to a random mesh of the pool, its scale read as the
## wanted width. Pebbles and ferns cast no shadow (cheap); bushes do.
func _scatter(rng: RandomNumberGenerator, pool: Array[Mesh], spots: Array[Transform3D], shadows: bool) -> void:
	var groups: Array[Array] = []
	groups.resize(pool.size())
	for t in spots:
		groups[rng.randi() % pool.size()].append(t)
	for i in pool.size():
		var box := pool[i].get_aabb()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = pool[i]
		multimesh.instance_count = groups[i].size()
		for n in groups[i].size():
			var t: Transform3D = groups[i][n]
			var k := t.basis.get_scale().x / maxf(box.size.x, box.size.z)
			multimesh.set_instance_transform(n, Transform3D(t.basis.orthonormalized().scaled(Vector3.ONE * k), t.origin - Vector3(0.0, box.position.y * k + 0.05, 0.0)))
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
