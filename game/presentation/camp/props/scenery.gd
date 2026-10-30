extends Node3D

## Camp edges (owner, 2026-10-29): a rock wall rising on the west side and south-west corner, a rocky
## drop-off on the east side and south-east corner (the vista lies below it), and a palisade with an
## ajar gate on the north side by the Start hunt sign, with forest beyond. Lower rocks skirt the rock
## wall and the drop-off so they meet the ground with no seam and spill a little into the camp. The
## camp's StaticBody walls in camp.tscn keep the hunter in; only the rim rocks collide (_skirt_collision).

const Dressing = preload("res://game/presentation/camp/props/dressing.gd")

const TREES_MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/OakTree1.res"), preload("res://assets/nature/meshes/OakTree2.res"),
	preload("res://assets/nature/meshes/OakTree3.res"), preload("res://assets/nature/meshes/SpruceTree1.res"),
	preload("res://assets/nature/meshes/SpruceTree2.res"), preload("res://assets/nature/meshes/SpruceTree3.res"),
]
const BIG_ROCK_MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/BigRock1.res"), preload("res://assets/nature/meshes/BigRock2.res"),
	preload("res://assets/nature/meshes/BigRock3.res"), preload("res://assets/nature/meshes/BigRock4.res"),
	preload("res://assets/nature/meshes/BigRock5.res"),
]
const GRASS_MESH := preload("res://assets/grass/grass.glb")
const GRASS_MATERIAL := preload("res://assets/grass/grass_material.tres")
const GROUND_MATERIAL := preload("res://game/presentation/camp/props/ground_material.tres")
const HALF := Dressing.HALF  # the camp's dirt square
## The south side splits here: rock wall to the west of it, drop-off to the east.
const SOUTH_SPLIT := Dressing.SOUTH_SPLIT
## The forest behind the palisade: x and z ranges.
const FOREST_X := Vector2(-40.0, 18.0)
const FOREST_Z := Vector2(-67.0, -20.0)
const TREE_COUNT := 75
const GRASS_INSIDE := 1800  # the camp shrank from 40 m to 34 m; same density
const GRASS_FOREST := 2500  # mostly hidden behind the palisade
## The wall's rocks reach down to the valley floor (vista.gd BASE_Y) so no sky or valley shows under them.
const WALL_DEPTH := 44.0
const GATE_HALF := 2.2
const GATE_OPEN := 0.55  # radians each leaf swings out towards the forest
const WOOD: Array[Color] = [Color(0.42, 0.3, 0.19), Color(0.5, 0.37, 0.24), Color(0.36, 0.26, 0.17), Color(0.47, 0.4, 0.3)]

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_forest_floor()
	for n in TREE_COUNT:
		var at := Vector3(rng.randf_range(FOREST_X.x, FOREST_X.y), 0.0, rng.randf_range(FOREST_Z.x, FOREST_Z.y))
		_prop(rng, TREES_MESHES, at, Vector2(7, 12), true)
	_grass(rng, GRASS_INSIDE, func(): return _edge_grass(rng))
	_grass(rng, GRASS_FOREST, func(): return Vector3(rng.randf_range(FOREST_X.x, FOREST_X.y + 2.0), 0.0, rng.randf_range(FOREST_Z.x, -HALF - 0.5)))
	_rock_wall(rng)
	_drop_off(rng)
	_skirt(rng)
	_palisade(rng)


## A point in the square band between two half-widths (the camp is a square).
func _edge(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector3:
	while true:
		var p := Vector3(rng.randf_range(-outer, outer), 0.0, rng.randf_range(-outer, outer))
		if maxf(absf(p.x), absf(p.z)) > inner:
			return p
	return Vector3.ZERO


## Tall grass in the green border along the palisade and the rock wall (thinning towards its wobbly
## inner edge); kept off the drop-off (it would hide the view) and out of the gateway.
func _edge_grass(rng: RandomNumberGenerator) -> Vector3:
	while true:
		var p := _edge(rng, HALF - 4.8, HALF - 0.6)
		if Dressing.greenness(p) > rng.randf_range(0.5, 1.0) and not _by_drop(p) and not (p.z < -HALF + 3.5 and absf(p.x) < GATE_HALF + 1.0):
			return p
	return Vector3.ZERO


func _by_drop(p: Vector3) -> bool:
	return p.x > HALF - 4.0 or (p.z > HALF - 4.0 and p.x > SOUTH_SPLIT)


## Big rocks in two rows along the west side and the west half of the south side; the back row
## stands higher (all rocks stand on the ground, none hangs in the air), so the wall climbs away from the camp.
func _rock_wall(rng: RandomNumberGenerator) -> void:
	for row in 2:
		var step := 7.0
		var extra := row * 9.0  # the back row's rocks are taller
		var out := 6.0 + row * 9.0
		for z in range(int(FOREST_Z.x), int(HALF + out), int(step)):
			_big_rock(rng, Vector3(-HALF - out, 0.0, z + rng.randf_range(-1.5, 1.5)), Vector2(14, 20) + Vector2.ONE * extra, false, [], WALL_DEPTH)
		# The south end of the wall sinks towards the drop-off instead of ending in a sheer face.
		for x in range(int(-HALF - out), int(SOUTH_SPLIT) + 6, int(step)):
			var low := lerpf(1.0, 0.25, smoothstep(-8.0, SOUTH_SPLIT + 4.0, x))
			_big_rock(rng, Vector3(x + rng.randf_range(-1.5, 1.5), 0.0, HALF + out), (Vector2(14, 20) + Vector2.ONE * extra) * low, false, [], WALL_DEPTH)


## Rocks stepping down from the camp's rim towards the valley along the east side and the east half
## of the south side.
func _drop_off(rng: RandomNumberGenerator) -> void:
	for row in 5:
		var top := 0.4 - row * row * 2.2 - row * 2.0
		var out := 3.0 + row * 5.5
		for z in range(int(FOREST_Z.x), int(HALF + out), 5):
			_big_rock(rng, Vector3(HALF + out, top, z + rng.randf_range(-1.0, 1.0)), Vector2(6, 9) + Vector2.ONE * row * 4.0, true)
		for x in range(int(SOUTH_SPLIT), int(HALF + out), 5):
			_big_rock(rng, Vector3(x + rng.randf_range(-1.0, 1.0), top, HALF + out), Vector2(6, 9) + Vector2.ONE * row * 4.0, true)


## Lower rocks along the camp's rim, some well inside it: on the rock wall side they stand on the
## ground at the foot of the wall; on the drop-off side their tops stand just above the rim and their
## bodies reach down the slope, hiding the ground's edge.
func _skirt(rng: RandomNumberGenerator) -> void:
	var skirt: Array[Array] = []  # rock transforms, one list per BIG_ROCK_MESHES entry
	for mesh in BIG_ROCK_MESHES:
		skirt.append([])
	var rim: Array[Vector3] = []
	for t in range(int(-HALF) - 2, int(HALF) + 3, 1):
		rim.append(Vector3(-HALF, 0.0, t))  # west
		rim.append(Vector3(HALF, 0.0, t))  # east
		rim.append(Vector3(t, 0.0, HALF))  # south
	for at in rim:
		var inward := -Vector3(signf(at.x) if absf(at.x) >= HALF else 0.0, 0.0, signf(at.z) if absf(at.z) >= HALF else 0.0)
		var spot := at + Vector3(rng.randf_range(-0.7, 0.7), 0.0, rng.randf_range(-0.7, 0.7)) * (Vector3.ONE - inward.abs())
		# The rocks reach in and out along the rim in slow waves, so the ground's edge is no straight line.
		var t := at.x + at.z
		var reach := 0.9 + 1.0 * sin(t * 0.42) + 0.8 * sin(t * 1.1 + 2.0) + rng.randf_range(-0.4, 0.4)
		if _by_drop(spot):
			_big_rock(rng, spot - inward * (reach + rng.randf_range(-0.6, 1.2)) + Vector3(0.0, rng.randf_range(0.15, 0.8), 0.0), Vector2(2.6, 5.0), true, skirt)
		else:
			_big_rock(rng, spot + inward * (reach + rng.randf_range(-0.8, 0.9)) + Vector3(0.0, 0.6, 0.0), Vector2(1.4, 4.0), false, skirt)
			if rng.randf() < 0.35:
				_big_rock(rng, spot + inward * rng.randf_range(1.2, 2.6) + Vector3(0.0, 0.7, 0.0), Vector2(0.6, 1.4), false, skirt)
	_skirt_collision(skirt)
	# Low and many: one shadowless MultiMesh per rock mesh keeps them to a handful of draw calls.
	for i in BIG_ROCK_MESHES.size():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = BIG_ROCK_MESHES[i]
		multimesh.instance_count = skirt[i].size()
		for n in skirt[i].size():
			multimesh.set_instance_transform(n, skirt[i][n])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


## The rim rocks are solid: a convex hull per rock with its transform baked into the points, since
## physics shapes do not like the rocks' uneven scale.
func _skirt_collision(skirt: Array[Array]) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	for i in BIG_ROCK_MESHES.size():
		var hull := BIG_ROCK_MESHES[i].create_convex_shape(true, true).points
		for xf: Transform3D in skirt[i]:
			var shape := ConvexPolygonShape3D.new()
			shape.points = xf * hull
			var node := CollisionShape3D.new()
			node.shape = shape
			body.add_child(node)


## A big rock of the given height range; by_top puts its top at `at.y` instead of its base. With
## `into`, the rock's transform goes to the list for its mesh instead of a node of its own.
func _big_rock(rng: RandomNumberGenerator, at: Vector3, height: Vector2, by_top := false, into: Array[Array] = [], depth := 0.0) -> void:
	var i := rng.randi() % BIG_ROCK_MESHES.size()
	var box := BIG_ROCK_MESHES[i].get_aabb()
	var k := rng.randf_range(height.x, height.y) / box.size.y
	var node := MeshInstance3D.new()
	node.mesh = BIG_ROCK_MESHES[i]
	node.scale = Vector3(k * rng.randf_range(0.6, 0.8), k, k * rng.randf_range(0.6, 0.8))
	node.rotation.y = rng.randf() * TAU
	node.position = at - Vector3(0.0, box.end.y * k if by_top else 1.0 + depth, 0.0)
	node.scale.y *= 1.0 + depth / (box.size.y * k)  # stretched downwards, the top stays put
	if into.is_empty():
		add_child(node)
	else:
		into[i].append(node.transform)
		node.free()


## Logs of mixed thickness and height with sharpened tops, two binding rails on the inside, and two
## gate leaves swung slightly out.
func _palisade(rng: RandomNumberGenerator) -> void:
	var materials: Array[StandardMaterial3D] = []
	for color in WOOD:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		materials.append(material)
	var x := -HALF - 1.0
	while x < HALF + 1.0:
		var radius := rng.randf_range(0.16, 0.3)
		x += radius
		if absf(x) > GATE_HALF + radius:
			add_child(_log(rng, materials, Vector3(x, 0.0, -HALF - 0.4), radius, rng.randf_range(3.6, 5.2)))
		x += radius + 0.02
	for y in [1.1, 2.9]:
		for side in [-1.0, 1.0]:
			var rail := _beam(materials[2], HALF + 1.0 - GATE_HALF)
			rail.position = Vector3(side * (GATE_HALF + HALF + 1.0) * 0.5, y, -HALF + 0.05)
			add_child(rail)
	for side in [-1.0, 1.0]:
		var leaf := Node3D.new()
		leaf.position = Vector3(side * GATE_HALF, 0.0, -HALF - 0.4)
		leaf.rotation.y = side * -GATE_OPEN * rng.randf_range(0.7, 1.3)
		var along := 0.0
		while along < GATE_HALF - 0.1:
			var radius := rng.randf_range(0.14, 0.18)
			along += radius
			leaf.add_child(_log(rng, materials, Vector3(-side * along, 0.0, 0.0), radius, rng.randf_range(3.0, 3.4)))
			along += radius + 0.01
		for y in [0.7, 2.4]:
			var brace := _beam(materials[1], GATE_HALF)
			brace.position = Vector3(-side * GATE_HALF * 0.5, y, 0.25)
			leaf.add_child(brace)
		add_child(leaf)


func _log(rng: RandomNumberGenerator, materials: Array[StandardMaterial3D], at: Vector3, radius: float, height: float) -> Node3D:
	var material: StandardMaterial3D = materials[rng.randi() % materials.size()]
	var trunk := CylinderMesh.new()
	trunk.top_radius = radius
	trunk.bottom_radius = radius * rng.randf_range(1.0, 1.15)
	trunk.height = height
	trunk.radial_segments = 8
	trunk.material = material
	var tip := CylinderMesh.new()
	tip.top_radius = 0.02
	tip.bottom_radius = radius
	tip.height = radius * rng.randf_range(2.0, 3.5)
	tip.radial_segments = 8
	tip.material = material
	var node := MeshInstance3D.new()
	node.mesh = trunk
	node.position = at + Vector3(0.0, height * 0.5 - 0.3, 0.0)
	node.rotation = Vector3(rng.randf_range(-0.04, 0.04), rng.randf() * TAU, rng.randf_range(-0.04, 0.04))
	var cap := MeshInstance3D.new()
	cap.mesh = tip
	cap.position.y = (height + tip.height) * 0.5
	node.add_child(cap)
	return node


func _beam(material: StandardMaterial3D, length: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.1
	mesh.height = length
	mesh.radial_segments = 6
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.rotation.z = PI / 2
	return node


func _prop(rng: RandomNumberGenerator, pool: Array[Mesh], at: Vector3, size: Vector2, by_height: bool) -> void:
	var mesh: Mesh = pool[rng.randi() % pool.size()]
	var box := mesh.get_aabb()
	var k := rng.randf_range(size.x, size.y) / (box.size.y if by_height else maxf(box.size.x, box.size.z))
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.scale = Vector3.ONE * k
	node.rotation.y = rng.randf() * TAU
	node.position = at + Vector3(0.0, -box.position.y * k - 0.1 * k, 0.0)
	add_child(node)


## Green ground under the forest beyond the palisade; the camp ground's material, so the grass runs
## on under the palisade without a seam.
func _forest_floor() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(FOREST_X.y - FOREST_X.x + 8.0, FOREST_Z.y - FOREST_Z.x + 10.0)
	mesh.material = GROUND_MATERIAL
	var lawn := MeshInstance3D.new()
	lawn.mesh = mesh
	lawn.position = Vector3((FOREST_X.x + FOREST_X.y) * 0.5 - 2.0, -0.03, (FOREST_Z.x + FOREST_Z.y) * 0.5 + 1.0)
	add_child(lawn)


func _grass(rng: RandomNumberGenerator, count: int, spot: Callable) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = (GRASS_MESH.instantiate().get_child(0) as MeshInstance3D).mesh
	multimesh.instance_count = count
	for n in count:
		var size := rng.randf_range(0.4, 0.9)
		multimesh.set_instance_transform(n, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), spot.call()))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.material_override = GRASS_MATERIAL
	add_child(node)
