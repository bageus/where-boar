extends Node3D

## Land outside the hunting grounds (owner, 2026-10-30): the same grassy woods carry on past the invisible
## walls, hills rise with distance, rocky outcrops and far mountains stand on some sides only, and every
## escape zone opens into a "natural gate" of tall grass and rotten stumps. Out of reach and cheap: one ground
## mesh, MultiMesh per model and side, no shadows; grass and ferns are drawn only near the camera.

const TerrainScript = preload("res://game/presentation/hunt_map/props/terrain.gd")
const HALF := 80.0
## The ground runs this far past the walls, one vertex every STEP metres.
const REACH := 200.0
const STEP := 2.0
const FOREST := Color(0.12, 0.33, 0.08)
const NEAR_TREES: Array[Mesh] = [
	preload("res://assets/nature/meshes/OakTree1.res"), preload("res://assets/nature/meshes/OakTree2.res"),
	preload("res://assets/nature/meshes/SpruceTree1.res"), preload("res://assets/nature/meshes/SpruceTree3.res"),
	preload("res://assets/nature/meshes/Tree_1.res"),
]
## Spruces are the cheapest trees (130-190 triangles): the far woods are only these.
const FAR_TREES: Array[Mesh] = [
	preload("res://assets/nature/meshes/SpruceTree1.res"), preload("res://assets/nature/meshes/SpruceTree2.res"),
	preload("res://assets/nature/meshes/SpruceTree3.res"), preload("res://assets/nature/meshes/OakTree2.res"),
]
const NEAR_COUNT := 500
const NEAR_BAND := 40.0
const FAR_COUNT := 900
const DEAD_TREES: Array[Mesh] = [
	preload("res://assets/nature/meshes/DeadOak1.res"), preload("res://assets/nature/meshes/DeadOak2.res"),
	preload("res://assets/nature/meshes/DeadSpruce1.res"),
]
## Rocky outcrops and mountains, only on these compass sectors (angle from +x towards +z, half-width), radians.
const ROCK_SECTORS := [Vector2(-1.9, 0.5), Vector2(0.4, 0.35), Vector2(2.6, 0.45)]
const OUTCROPS := 14
const MOUNTAINS := 9
const MOUNTAIN_HAZE := Color(0.4, 0.47, 0.6)
## Grass and ferns in a strip this wide just outside the walls, like inside (terrain.gd).
const GRASS_STRIP := 10.0
const GRASS_PER_M2 := 4
const FERNS := 180
## Natural gates: tall grass this far around each zone; the path out stays clear of trees this wide and long.
const GATE_GRASS := 6.5
const GATE_PATH := Vector2(7.0, 45.0)

var _terrain: StaticBody3D
var _gates: Array[Vector2] = []
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_terrain = get_parent().get_node("Terrain")
	for zone: Node3D in get_parent().get_node("EscapeZones").get_children():
		_gates.append(Vector2(zone.position.x, zone.position.z))
	_noise.seed = 5
	_noise.frequency = 0.012
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	_ground()
	_trees(rng)
	_rocks(rng)
	_grass(rng)
	for gate in _gates:
		_gate(gate, rng)


## Metres past the nearest wall (0 on it, negative inside).
func _past(x: float, z: float) -> float:
	return maxf(absf(x), absf(z)) - HALF


## The edge of the map carried straight out (the river too, as a valley), then hills that rise with
## distance; the river valley closes further out so no gap shows to the horizon.
func height_at(x: float, z: float) -> float:
	var edge: float = _terrain.height_at(x, z)
	var past := _past(x, z)
	var river := 1.0 - smoothstep(-0.2, 0.9, edge)
	var hills := smoothstep(12.0, 150.0, past) * (6.0 + 22.0 * (_noise.get_noise_2d(x, z) * 0.5 + 0.5))
	return edge + hills * lerpf(1.0 - river, 1.0, smoothstep(50.0, 110.0, past))


func _ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := int((HALF + REACH) * 2.0 / STEP)
	var origin := -(HALF + REACH)
	for j in cells + 1:
		for i in cells + 1:
			var x := origin + i * STEP
			var z := origin + j * STEP
			var h := height_at(x, z)
			var tint := TerrainScript.GRASS.lerp(FOREST, _noise.get_noise_2d(z * 3.0, x * 3.0) * 0.5 + 0.5)
			st.set_color(TerrainScript.MUD if h < -0.3 else tint)
			st.add_vertex(Vector3(x, h, z))
	for j in cells:
		for i in cells:
			if _past(origin + (i + 0.5) * STEP, origin + (j + 0.5) * STEP) < 0.0:
				continue  # the hunt map's own terrain
			var a := j * (cells + 1) + i
			var b := a + cells + 1
			for k in [a, a + 1, b, a + 1, b + 1, b]:
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


## A random point outside the walls, from..to metres past them.
func _outside(rng: RandomNumberGenerator, from: float, to: float) -> Vector2:
	var side := Vector2.from_angle(rng.randi() % 4 * PI * 0.5).round()
	var along := rng.randf_range(-HALF - to, HALF + to)
	var out := HALF + rng.randf_range(from, to)
	return side * out + side.orthogonal() * along


func _on_gate_path(at: Vector2) -> bool:
	for gate in _gates:
		var out := gate.normalized()
		var d := at - gate
		if absf(d.dot(out.orthogonal())) < GATE_PATH.x and d.dot(out) > -2.0 and d.dot(out) < GATE_PATH.y:
			return true
	return false


func _trees(rng: RandomNumberGenerator) -> void:
	var near := _spots(NEAR_TREES.size())
	var far := _spots(FAR_TREES.size())
	var placed := 0
	while placed < NEAR_COUNT + FAR_COUNT:
		var is_near := placed < NEAR_COUNT
		var at := _outside(rng, 1.5, NEAR_BAND) if is_near else _outside(rng, NEAR_BAND, REACH - 5.0)
		# Woods in patches (fewer gaps near the walls), off the gate paths and out of the river.
		if _noise.get_noise_2d(at.y * 2.0, at.x * 2.0 + 300.0) < (-0.35 if is_near else -0.1) or _on_gate_path(at) \
				or (_terrain.height_at(at.x, at.y) < 0.3 and _past(at.x, at.y) < 70.0):
			continue
		placed += 1
		var meshes := NEAR_TREES if is_near else FAR_TREES
		var k := rng.randi() % meshes.size()
		var size := rng.randf_range(7.0, 12.0) / meshes[k].get_aabb().size.y * (1.0 if is_near else 1.3)
		(near if is_near else far)[_side(at)][k].append(_spot(at, size, rng))
	for side in 4:
		for k in NEAR_TREES.size():
			_add(NEAR_TREES[k], near[side][k])
		for k in FAR_TREES.size():
			_add(FAR_TREES[k], far[side][k])


## Big grey rocks half sunk in the hills and huge ones as mountains on the horizon, on some sides only.
func _rocks(rng: RandomNumberGenerator) -> void:
	var meshes: Array[Mesh] = TerrainScript.CLIFF_ROCKS
	var spots := _spots(meshes.size())
	var peaks := _spots(meshes.size())
	for n in OUTCROPS + MOUNTAINS:
		var mountain := n >= OUTCROPS
		var sector: Vector2 = ROCK_SECTORS[n % ROCK_SECTORS.size()]
		var angle := sector.x + rng.randf_range(-sector.y, sector.y)
		var far := rng.randf_range(330.0, 420.0) if mountain else rng.randf_range(HALF + 35.0, HALF + 150.0)
		var at := Vector2.from_angle(angle) * far
		var size := rng.randf_range(9.0, 16.0) if mountain else rng.randf_range(1.6, 3.2)
		var spot := _spot(at, size, rng)
		spot.origin.y = (0.0 if mountain else height_at(at.x, at.y)) - 0.25 * size * meshes[0].get_aabb().size.y
		(peaks if mountain else spots)[_side(at)][rng.randi() % meshes.size()].append(spot)
	# Hazy blue-grey, so the mountains read as far away rather than as big rocks nearby.
	var haze := StandardMaterial3D.new()
	haze.albedo_color = MOUNTAIN_HAZE
	haze.roughness = 1.0
	for side in 4:
		for k in meshes.size():
			_add(meshes[k], spots[side][k])
			_add(meshes[k], peaks[side][k], haze)


## The hunt map's short grass and ferns in a strip outside the walls, in chunks drawn only nearby.
func _grass(rng: RandomNumberGenerator) -> void:
	var clump: Mesh = (TerrainScript.GRASS_MESH.instantiate().get_child(0) as MeshInstance3D).mesh
	var chunk := float(TerrainScript.GRASS_CHUNK)
	for side in 4:
		var out := Vector2.from_angle(side * PI * 0.5).round()
		for c in range(int(-HALF - GRASS_STRIP), int(HALF + GRASS_STRIP), int(chunk)):
			var centre2 := out * (HALF + GRASS_STRIP * 0.5) + out.orthogonal() * (c + chunk * 0.5)
			var centre := Vector3(centre2.x, 0.0, centre2.y)
			var spots: Array[Transform3D] = []
			for n in int(chunk * GRASS_STRIP) * GRASS_PER_M2:
				var at := out * (HALF + rng.randf() * GRASS_STRIP) + out.orthogonal() * (c + rng.randf() * chunk)
				if _past(at.x, at.y) < 0.0 or _terrain.height_at(at.x, at.y) < 0.3:
					continue
				var spot := _spot(at, rng.randf_range(0.18, 0.23), rng)
				spot.origin -= centre
				spots.append(spot)
			_add(clump, spots, TerrainScript.GRASS_MATERIAL, TerrainScript.GRASS_RANGE, centre)
	var ferns := _spots(TerrainScript.FERNS.size())
	for n in FERNS:
		var at := _outside(rng, 0.5, GRASS_STRIP)
		ferns[_side(at)][rng.randi() % TerrainScript.FERNS.size()].append(_spot(at, rng.randf_range(1.0, 1.6), rng))
	for side in 4:
		for k in TerrainScript.FERNS.size():
			_add(TerrainScript.FERNS[k], ferns[side][k], null, TerrainScript.FERN_RANGE)


## Tall grass with wheat around the zone, half inside the map; rotten stumps flank the way out (solid, as
## some stand inside), with dead trees further out marking the opening in the woods.
func _gate(gate: Vector2, rng: RandomNumberGenerator) -> void:
	var out := gate.normalized()
	var across := out.orthogonal()
	var clump: Mesh = (TerrainScript.GRASS_MESH.instantiate().get_child(0) as MeshInstance3D).mesh
	var centre := Vector3(gate.x, 0.0, gate.y)
	var tall: Array[Transform3D] = []
	var wheat: Array[Transform3D] = []
	for n in int(PI * GATE_GRASS * GATE_GRASS * 3.0):
		var at := gate + Vector2.from_angle(rng.randf() * TAU) * GATE_GRASS * sqrt(rng.randf())
		var spot := _spot(at, rng.randf_range(0.65, 0.8), rng)
		spot.origin -= centre
		tall.append(spot)
		if rng.randf() < 0.25:
			wheat.append(spot.scaled_local(Vector3.ONE * 1.4 / spot.basis.get_scale().x))
	_add(clump, tall, TerrainScript.GRASS_MATERIAL, TerrainScript.GRASS_RANGE * 2.0, centre)
	_add(TerrainScript.WHEAT, wheat, null, TerrainScript.GRASS_RANGE * 2.0, centre)
	var body := StaticBody3D.new()
	add_child(body)
	var stumps: Array[Transform3D] = []
	for s in [-2.0, 1.5, 5.0, 8.5, 12.0]:
		for side in [-1.0, 1.0]:
			var at: Vector2 = gate + out * (s + rng.randf_range(-0.8, 0.8)) + across * side * rng.randf_range(4.0, 5.5)
			var spot := _spot(at, rng.randf_range(2.0, 3.0), rng)
			stumps.append(spot)
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			var box := TerrainScript.STUMP.get_aabb()
			(shape.shape as BoxShape3D).size = box.size * spot.basis.get_scale() * Vector3(0.7, 1.0, 0.9)
			shape.transform = Transform3D(spot.basis.orthonormalized(), spot * box.get_center())
			body.add_child(shape)
	_add(TerrainScript.STUMP, stumps)
	for side in [-1.0, 1.0]:
		var at: Vector2 = gate + out * rng.randf_range(14.0, 22.0) + across * side * rng.randf_range(6.5, 9.0)
		var k := rng.randi() % DEAD_TREES.size()
		_add(DEAD_TREES[k], [_spot(at, rng.randf_range(1.0, 1.4), rng)] as Array[Transform3D])


## An upright, randomly turned copy at a ground point, slightly sunk.
func _spot(at: Vector2, size: float, rng: RandomNumberGenerator) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(at.x, height_at(at.x, at.y) - 0.1, at.y))


## Which side of the map a point lies on (0 east, 1 south, 2 west, 3 north): one MultiMesh per side lets
## the camera skip the ones behind it.
func _side(at: Vector2) -> int:
	return posmod(roundi(at.angle() / (PI * 0.5)), 4)


func _spots(models: int) -> Array:
	var sides := []
	for side in 4:
		var lists := []
		for k in models:
			lists.append([] as Array[Transform3D])
		sides.append(lists)
	return sides


## One draw call for many copies, never casting shadows; draw_range 0 = always drawn.
func _add(mesh: Mesh, spots: Array[Transform3D], material: Material = null, draw_range := 0.0, centre := Vector3.ZERO) -> void:
	if spots.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for n in spots.size():
		multimesh.set_instance_transform(n, spots[n])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.position = centre
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = draw_range
	add_child(node)
