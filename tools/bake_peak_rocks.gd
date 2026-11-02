extends SceneTree

## Bakes the stylized rocks, cliff chunks and grass clump (owner, 2026-11-02: rocks, cliffs and grass in the
## style of the game PEAK). Our own procedural shapes, nothing taken from that game: every rock is the
## intersection of a dozen planes cut around a squashed ellipsoid, so it has few, big, flat facets; a cliff
## chunk is a broad wall of two or three such slabs, each stepped back, so it reads as terraced rock with ledges. Faces are
## flat shaded with a light, slightly warm stone colour, green moss on faces turned up and darker towards
## the foot; horizon peaks are tall ones with a summit block. Origin at the bottom centre, like the nature pack (bake_nature_meshes.gd).
## Run: godot --headless --path . -s res://tools/bake_peak_rocks.gd

const OUT := "res://assets/nature/meshes/peak/"
const GRASS_OUT := "res://assets/grass/peak_grass.res"
const STONE: Array[Color] = [Color(0.52, 0.5, 0.5), Color(0.47, 0.48, 0.53), Color(0.56, 0.52, 0.46)]
const MOSS: Array[Color] = [Color(0.3, 0.52, 0.14), Color(0.38, 0.58, 0.16)]
## Faces whose normal.y is above this get moss (if the shape has moss).
const MOSS_UP := 0.6
const ROCKS := 8
const CLIFFS := 5
## Tall peaks for the horizon (surroundings.gd mountains).
const SPIRES := 3


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for n in ROCKS:
		var tool := _tool()
		var r := Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.5, 0.9), rng.randf_range(0.7, 1.1))
		_slab(tool, rng, Vector3.ZERO, r, 11 + rng.randi() % 5, n % 3 != 2)
		_save(tool, OUT + "PeakRock%d.res" % (n + 1))
	var cliff_rng := RandomNumberGenerator.new()
	cliff_rng.seed = 2611
	for n in CLIFFS:
		# A broad wall (owner, 2026-11-02: cliffs as solid faces, not a pile of boulders): long along x, face
		# towards +z; each layer steps back and in a little, so the face reads as terraces with mossy ledges.
		# shortcut: own rng, so the committed spires and grass (baked after the old cliffs) no longer match a
		# rebake of them exactly; same style, fine to rebake them whenever they change.
		var tool := _tool()
		var y := 0.0
		var z := 0.0
		var layers := 2 + cliff_rng.randi() % 2
		var width := cliff_rng.randf_range(9.0, 11.0)
		for k in layers:
			var h := cliff_rng.randf_range(3.0, 4.2)
			var r := Vector3(width * 0.5, h * 0.5, width * cliff_rng.randf_range(0.24, 0.3))
			_slab(tool, cliff_rng, Vector3(cliff_rng.randf_range(-0.4, 0.4), y, z), r, 7 + cliff_rng.randi() % 3, true, true, 0.9)
			y += h * cliff_rng.randf_range(0.82, 0.92)  # each layer sinks a little into the one below
			z -= r.z * cliff_rng.randf_range(0.25, 0.4)
			width *= cliff_rng.randf_range(0.82, 0.92)
		_save(tool, OUT + "PeakCliff%d.res" % (n + 1))
	for n in SPIRES:
		var tool := _tool()
		var r := Vector3(rng.randf_range(5.0, 6.5), rng.randf_range(6.0, 7.5), rng.randf_range(4.5, 6.0))
		_slab(tool, rng, Vector3.ZERO, r, 16, false)
		# A smaller, offset summit block makes the top jagged instead of one dome.
		var top := Vector3(r.x * 0.45, r.y * 0.45, r.z * 0.45)
		_slab(tool, rng, Vector3(r.x * 0.2, r.y * 1.35, -r.z * 0.15), top, 12, false)
		_save(tool, OUT + "PeakSpire%d.res" % (n + 1))
	_bake_grass(rng)
	quit()


func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


## One convex rock: planes cut a box of half-size r round an ellipsoid; flat bottom at base.y (and a flat
## top for a cliff layer, so the next one sits on a ledge). Cliff layers get more cuts, so a wall stretched
## tall in the camp still breaks into many facets, and a slightly darker stone (shade).
func _slab(tool: SurfaceTool, rng: RandomNumberGenerator, base: Vector3, r: Vector3, cuts: int, moss: bool, flat_top := false,
		shade := 1.0) -> void:
	var centre := base + Vector3(0.0, r.y, 0.0)
	var planes: Array[Plane] = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		planes.append(Plane(axis, axis.dot(centre) + (axis.abs() * r).length() * rng.randf_range(0.9, 1.0)))
	planes.append(Plane(Vector3.DOWN, -base.y))
	var top := r.y * (rng.randf_range(0.92, 1.0) if flat_top else 1.0)
	planes.append(Plane(Vector3.UP, centre.y + top))
	for n in cuts:
		# Mostly sideways and upward cuts: the bevels and chamfers that make the big facets.
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 1.0) * (0.25 if flat_top else 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var reach := (dir * r).length() * (rng.randf_range(0.8, 0.92) if flat_top else rng.randf_range(0.72, 0.9))
		planes.append(Plane(dir, dir.dot(centre) + reach))
	var points := Geometry3D.compute_convex_mesh_points(planes)
	var stone: Color = STONE[rng.randi() % STONE.size()] * shade
	var green: Color = MOSS[rng.randi() % MOSS.size()]
	var height := maxf(top * 2.0, 0.01)
	for plane in planes:
		var face: Array[Vector3] = []
		for p in points:
			if absf(plane.distance_to(p)) < 0.001 and not face.any(func(q: Vector3) -> bool: return q.distance_to(p) < 0.001):
				face.append(p)
		if face.size() < 3:
			continue
		var mid := Vector3.ZERO
		for p in face:
			mid += p
		mid /= face.size()
		var u := (face[0] - mid).normalized()
		var v := plane.normal.cross(u)
		face.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return atan2((a - mid).dot(v), (a - mid).dot(u)) < atan2((b - mid).dot(v), (b - mid).dot(u)))
		var tint := 1.0 + rng.randf_range(-0.06, 0.06)
		# Cliff layers keep moss to their flat ledges: the camp stretches them tall, which tilts the bevels.
		var color := (green if moss and plane.normal.y > (0.9 if flat_top else MOSS_UP) else stone) * tint
		for k in range(1, face.size() - 1):
			var tri := [face[0], face[k + 1], face[k]]  # clockwise seen from outside: Godot's front face
			for p: Vector3 in tri:
				var foot := clampf((p.y - base.y) / height, 0.0, 1.0)
				var c := color * lerpf(0.72, 1.06, foot)
				c.a = 1.0
				tool.set_color(c)
				tool.set_normal(plane.normal)
				tool.add_vertex(p)


func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func _save(tool: SurfaceTool, path: String) -> void:
	tool.index()
	var arrays := tool.commit_to_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var box := AABB(verts[0], Vector3.ZERO)
	for p in verts:
		box = box.expand(p)
	var shift := Vector3(box.get_center().x, 0.0, box.get_center().z)  # bottom centre to the origin
	for n in verts.size():
		verts[n] -= shift
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material())
	ResourceSaver.save(mesh, path)


## A grass clump of wide, pointed, bent blades: 3 triangles a blade, UV.y 0 at the root and 1 at the tip
## (peak_grass.gdshader colours and sways by it). About as big as the old clump (2.8 x 2.2 x 2.6 model
## units), so the scales in terrain.gd and scenery.gd still fit. Normals point up, so the clump is lit
## like the ground under it, with no dark backs.
func _bake_grass(rng: RandomNumberGenerator) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var blades := 13
	for n in blades:
		var angle := TAU * n / blades + rng.randf_range(-0.25, 0.25)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var side := out.cross(Vector3.UP)
		var root := out * rng.randf_range(0.0, 0.5)
		var tall := rng.randf_range(1.4, 2.2)
		var lean := rng.randf_range(0.5, 1.1)
		var w := rng.randf_range(0.24, 0.34)
		var mid := root + out * lean * 0.35 + Vector3.UP * tall * 0.55
		var tip := root + out * lean + Vector3.UP * tall
		var points := [root - side * w, root + side * w, mid + side * w * 0.7, mid - side * w * 0.7, tip]
		var heights := [0.0, 0.0, 0.55, 0.55, 1.0]
		for k: int in [0, 2, 1, 0, 3, 2, 3, 4, 2]:  # two triangles to the bend, one to the tip
			tool.set_uv(Vector2(0.5, heights[k]))
			tool.add_vertex(points[k])
	tool.index()
	# Distant grass chunks drop to three blades (spread round the clump), like the imported clump's one
	# LOD (edge length 1.48). Each blade is 9 indices in order.
	var arrays := tool.commit_to_arrays()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var far := PackedInt32Array()
	for n in [0, 4, 8]:
		far.append_array(indices.slice(n * 9, n * 9 + 9))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {1.5: far})
	ResourceSaver.save(mesh, GRASS_OUT)
