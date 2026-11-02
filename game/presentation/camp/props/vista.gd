extends Node3D

## The view from the camp's drop-off (owner, 2026-10-29): hills, a river and woods far below, out of reach,
## hinting at the hunting grounds; toy clouds drift over it and birds fly between perches (birds.gd).

const CloudsScript = preload("res://game/core/clouds/public/clouds.gd")
const BirdsScript = preload("res://game/presentation/camp/props/birds.gd")
## Stylized broadleaves and pines like in PEAK (owner, 2026-11-02), tools/bake_peak_trees.gd.
const TREE_MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/peak/PeakTree1.res"), preload("res://assets/nature/meshes/peak/PeakTree2.res"),
	preload("res://assets/nature/meshes/peak/PeakTree3.res"), preload("res://assets/nature/meshes/peak/PeakTree4.res"),
	preload("res://assets/nature/meshes/peak/PeakPine1.res"), preload("res://assets/nature/meshes/peak/PeakPine2.res"),
	preload("res://assets/nature/meshes/peak/PeakPine3.res"),
]
## The valley floor, below the camp; the river cuts under WATER_Y.
const BASE_Y := -42.0
const WATER_Y := -45.0
## The land spans x from START_X eastwards (under the camp too, so it shows below the south drop)
## and z across the whole view; trees grow from TREES_X on, clear of the cliff.
const START_X := -150.0
const TREES_X := 45.0
const SIZE := Vector2(850.0, 900.0)
const CELLS := Vector2i(170, 180)
const TREE_COUNT := 1400
## Extra trees in the near valley, in front of the camp's drop-off but beyond the rocks (to x, z = 58), with
## no meadow patches left out, so the view below has no bare stretch.
const NEAR_TREES := 450
const NEAR_FROM := 58.0
const NEAR_SPAN := Rect2(-40.0, -70.0, 150.0, 180.0)
const TREE_CELL := 300.0
const GRASS := Color(0.3, 0.55, 0.18)
const MEADOW := Color(0.5, 0.62, 0.25)
const SAND := Color(0.72, 0.66, 0.45)

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 11
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	_land()
	_water()
	_trees(rng)
	add_child(CloudsScript.new())
	var birds: Node3D = BirdsScript.new()
	birds.height_at = height_at
	add_child(birds)


## The river winds north to south about 150 m east of the camp.
func river_x(z: float) -> float:
	return 160.0 + 55.0 * sin(z / 80.0) + 25.0 * sin(z / 31.0 + 1.0)


## Ground height of the valley; hills grow taller with distance so the far edge reads as a ridge.
func height_at(x: float, z: float) -> float:
	var far := Vector2(x, z).length()
	var h := BASE_Y + (_noise.get_noise_2d(x, z) * 0.5 + 0.5) * (6.0 + far * 0.09)
	var to_river := absf(x - river_x(z))
	if to_river < 30.0:
		h = lerpf(WATER_Y - 2.0, h, smoothstep(6.0, 30.0, to_river))
	return h


func _land() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := Vector2(SIZE.x / CELLS.x, SIZE.y / CELLS.y)
	for i in CELLS.x + 1:
		for j in CELLS.y + 1:
			var x := START_X + i * step.x
			var z := -SIZE.y * 0.5 + j * step.y
			var h := height_at(x, z)
			var shore := smoothstep(WATER_Y + 0.5, WATER_Y + 2.5, h)
			st.set_color(SAND.lerp(GRASS.lerp(MEADOW, _noise.get_noise_2d(z * 3.0, x * 3.0) * 0.5 + 0.5), shore))
			st.add_vertex(Vector3(x, h, z))
	for i in CELLS.x:
		for j in CELLS.y:
			var a := i * (CELLS.y + 1) + j
			var b := a + CELLS.y + 1
			for k in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(k)
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	st.set_material(material)
	var land := MeshInstance3D.new()
	land.mesh = st.commit()
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)


func _water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.55, 0.75)
	material.metallic = 0.3
	material.roughness = 0.15
	mesh.material = material
	var water := MeshInstance3D.new()
	water.mesh = mesh
	water.position = Vector3(START_X + SIZE.x * 0.5, WATER_Y, 0.0)
	add_child(water)


## Woods in patches, kept off the river banks; one MultiMesh per tree model.
func _trees(rng: RandomNumberGenerator) -> void:
	var spots: Array[Array] = []
	for mesh in TREE_MESHES:
		spots.append([])
	var near := 0
	while near < NEAR_TREES:
		var x := rng.randf_range(NEAR_SPAN.position.x, NEAR_SPAN.end.x)
		var z := rng.randf_range(NEAR_SPAN.position.y, NEAR_SPAN.end.y)
		if (x < NEAR_FROM and z < NEAR_FROM) or height_at(x, z) < WATER_Y + 1.5:
			continue
		near += 1
		spots[rng.randi() % spots.size()].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6)), Vector3(x, height_at(x, z) - 0.3, z)))
	while spots.reduce(func(sum, list): return sum + list.size(), 0) < TREE_COUNT + NEAR_TREES:
		var x := rng.randf_range(TREES_X, START_X + SIZE.x)
		var z := rng.randf_range(-SIZE.y * 0.5, SIZE.y * 0.5)
		if _noise.get_noise_2d(z * 2.0 + 500.0, x * 2.0) < 0.0 or height_at(x, z) < WATER_Y + 1.5:
			continue
		var size := rng.randf_range(0.8, 1.4)
		spots[rng.randi() % spots.size()].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(x, height_at(x, z) - 0.3, z)))
	# One MultiMesh per model and TREE_CELL square, so the woods out of view are culled (owner, 2026-10-30: low FPS).
	var cells := {}  # [model, cell] -> Array[Transform3D]
	for m in TREE_MESHES.size():
		for t: Transform3D in spots[m]:
			var key := [m, Vector2i(floori(t.origin.x / TREE_CELL), floori(t.origin.z / TREE_CELL))]
			if not cells.has(key):
				cells[key] = [] as Array[Transform3D]
			cells[key].append(t)
	for key: Array in cells:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = TREE_MESHES[key[0]]
		multimesh.instance_count = cells[key].size()
		for n in cells[key].size():
			multimesh.set_instance_transform(n, cells[key][n])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
