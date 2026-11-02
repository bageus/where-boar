extends SceneTree

## Bakes the saddle, the hunter's backpack and the helper's hammer in the style of the game PEAK (owner,
## 2026-11-02), to match the weapons, rocks and trees (bake_peak_weapons.gd and others). Our own procedural
## shapes: chunky prisms and lumps, smoothed by peak_smooth.gd, one surface with bright vertex colours.
## Axes are those of the old glb files, so the fitting code does not change:
## - saddle: spine along Z (front +Z), pad underside at y 0.3, stirrups hanging down to y -0.45;
## - backpack: top at y 0, hanging down to y -1 (parent of the old node_0 rotated it upright);
## - hammer: handle along +Y from -0.09 to 0.4, the head at the top, wide along X (a child of hand_r).
## Run: godot --headless --path . -s res://tools/bake_peak_gear.gd

const PeakSmooth := preload("res://tools/peak_smooth.gd")
const OUT := "res://assets/models/peak_gear/"
const FUR := Color(0.93, 0.78, 0.5)
const FUR_DARK := Color(0.74, 0.52, 0.3)
const LEATHER := Color(0.6, 0.34, 0.16)
const LEATHER_LIGHT := Color(0.8, 0.5, 0.24)
const WRAP := Color(0.78, 0.3, 0.2)
const ROPE := Color(0.95, 0.86, 0.6)
const WOOD := Color(0.8, 0.5, 0.24)
const WOOD_DARK := Color(0.6, 0.35, 0.16)
const STONE := Color(0.55, 0.58, 0.66)
const STONE_LIGHT := Color(0.74, 0.77, 0.85)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_save(_saddle(), "saddle", true)
	_save(_backpack(), "backpack", true)
	_save(_hammer(), "hammer", false)
	quit()


func _saddle() -> SurfaceTool:
	var t := _tool()
	_saddle_pad(t)
	# Girth strap and stirrup leathers start inside the pad's rim and hang down both sides, wooden stirrups.
	for side in [-1.0, 1.0]:
		_prism(t, Vector3(side * 0.27, 0.22, -0.07), Vector3(side * 0.3, -0.21, -0.07), 0.035, 0.03, 6, WRAP)
		_prism(t, Vector3(side * 0.27, 0.22, 0.1), Vector3(side * 0.34, -0.29, 0.1), 0.028, 0.025, 6, LEATHER)
		var hang := Vector3(side * 0.34, -0.3, 0.1)
		_prism(t, hang + Vector3(0, 0.02, 0), hang + Vector3(0, -0.07, 0), 0.04, 0.04, 6, ROPE)  # rope lashing
		var loop := hang + Vector3(0, -0.1, 0)
		_prism(t, loop + Vector3(-0.07, 0, 0), loop + Vector3(0.07, 0, 0), 0.028, 0.028, 6, WOOD)
		_prism(t, loop + Vector3(-0.07, 0.01, 0), loop + Vector3(-0.07, -0.14, 0), 0.028, 0.028, 6, WOOD)
		_prism(t, loop + Vector3(0.07, 0.01, 0), loop + Vector3(0.07, -0.14, 0), 0.028, 0.028, 6, WOOD)
		_prism(t, loop + Vector3(-0.09, -0.13, 0), loop + Vector3(0.09, -0.13, 0), 0.03, 0.03, 6, WOOD_DARK)
	return t


## The saddle as one moulded piece (owner: it looked like separate chunks): a thick fur pad draped over the
## back, its underside along the spine at y 0.3 (SADDLE_PAD), drooping at the sides, the leather seat
## sunk into it with the cantle and the pommel rising out of the same surface, a red trim round the rim.
## Top and underside meet at the rim, so there are no seams or boxes.
func _saddle_pad(t: SurfaceTool) -> void:
	var n := 14
	var top := []
	var bottom := []
	var tint := []
	for i in n + 1:
		for j in n + 1:
			var u := lerpf(-1.0, 1.0, float(i) / n)
			var v := lerpf(-1.0, 1.0, float(j) / n)
			# Square grid -> rounded outline; m is 1 on the rim.
			var x := 0.31 * u * sqrt(1.0 - v * v * 0.5)
			var z := 0.28 * v * sqrt(1.0 - u * u * 0.5)
			var m := maxf(absf(u), absf(v))
			var edge := sqrt(maxf(1.0 - pow(m, 4.0), 0.0))
			var low := 0.3 - 0.15 * u * u
			var middle := clampf(1.0 - u * u / 0.4, 0.0, 1.0)
			var cantle := 0.07 * smoothstep(-0.08, -0.24, z) * middle
			var pommel := 0.05 * smoothstep(0.1, 0.24, z) * clampf(1.0 - u * u / 0.2, 0.0, 1.0)
			var seat := -0.03 * middle * clampf(1.0 - absf(z) / 0.15, 0.0, 1.0)
			top.append(Vector3(x, low + (0.14 - 0.05 * u * u + cantle + pommel + seat) * edge, z))
			bottom.append(Vector3(x, low - 0.015 * edge, z))
			var colour := FUR.lerp(FUR_DARK, clampf(absf(u) * 0.8 - 0.1, 0.0, 1.0))
			if absf(u) < 0.45 and absf(v) < 0.8:
				colour = LEATHER_LIGHT
			if m > 0.92:
				colour = WRAP
			tint.append(colour)
	for i in n:
		for j in n:
			var a := i * (n + 1) + j
			var quad := [a, a + 1, a + n + 2, a + n + 1]
			_face(t, [top[quad[0]], top[quad[1]], top[quad[2]]], [tint[quad[0]], tint[quad[1]], tint[quad[2]]], Vector3.UP)
			_face(t, [top[quad[0]], top[quad[2]], top[quad[3]]], [tint[quad[0]], tint[quad[2]], tint[quad[3]]], Vector3.UP)
			_face(t, [bottom[quad[0]], bottom[quad[1]], bottom[quad[2]]], [FUR_DARK, FUR_DARK, FUR_DARK], Vector3.DOWN)
			_face(t, [bottom[quad[0]], bottom[quad[2]], bottom[quad[3]]], [FUR_DARK, FUR_DARK, FUR_DARK], Vector3.DOWN)


## One triangle with a colour per corner, wound to face `out`.
func _face(t: SurfaceTool, p: Array, colours: Array, out: Vector3) -> void:
	var normal: Vector3 = (p[2] - p[0]).cross(p[1] - p[0])
	if normal.length_squared() < 1e-12:
		return
	var order := [0, 1, 2] if normal.dot(out) > 0.0 else [0, 2, 1]
	normal = normal.normalized() * (1.0 if normal.dot(out) > 0.0 else -1.0)
	for k: int in order:
		t.set_color(colours[k])
		t.set_normal(normal)
		t.add_vertex(p[k])


func _backpack() -> SurfaceTool:
	var t := _tool()
	# Wooden frame sticks behind, the hide sack, a flap and a rolled sleeping hide below.
	for x in [-0.22, 0.22]:
		_prism(t, Vector3(x, -0.9, 0.2), Vector3(x, -0.05, 0.2), 0.035, 0.035, 5, WOOD)
	_prism(t, Vector3(-0.3, -0.3, 0.2), Vector3(0.3, -0.3, 0.2), 0.03, 0.03, 5, WOOD_DARK)
	_lump(t, Vector3(0, -0.52, 0.0), Vector3(0.38, 0.4, 0.28), FUR_DARK, FUR, 3)
	_lump(t, Vector3(0, -0.14, -0.02), Vector3(0.34, 0.14, 0.27), LEATHER, LEATHER_LIGHT, 8)  # flap
	_prism(t, Vector3(-0.42, -0.9, -0.05), Vector3(0.42, -0.9, -0.05), 0.15, 0.15, 7, ROPE)  # rolled hide
	for x in [-0.28, 0.28]:
		_prism(t, Vector3(x, -0.9, -0.05), Vector3(x + signf(x) * 0.02, -0.9, -0.05), 0.16, 0.16, 7, WRAP)
	_lump(t, Vector3(-0.38, -0.6, 0.0), Vector3(0.1, 0.14, 0.14), LEATHER, LEATHER_LIGHT, 4)  # side pouches
	_lump(t, Vector3(0.38, -0.6, 0.0), Vector3(0.1, 0.14, 0.14), LEATHER, LEATHER_LIGHT, 6)
	# Rope straps across the flap and down the sack, and the shoulder straps on the back.
	_box(t, Vector3(0, -0.24, -0.15), Vector3(0.07, 0.34, 0.07), 1.0, ROPE, ROPE)
	_box(t, Vector3(0, -0.5, -0.3), Vector3(0.07, 0.4, 0.07), 1.0, ROPE, ROPE)
	for x in [-0.15, 0.15]:
		_box(t, Vector3(x, -0.4, 0.3), Vector3(0.07, 0.6, 0.05), 1.0, LEATHER, LEATHER)
	return t


## The helper's stone hammer: the handle along +Y (grip near the origin), a hexagonal stone maul head across X.
func _hammer() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.1, 0), Vector3(0, 0.38, 0), 0.032, 0.026, 6, WOOD)
	_prism(t, Vector3(0, -0.1, 0), Vector3(0, 0.1, 0), 0.04, 0.04, 6, LEATHER)  # grip
	_prism(t, Vector3(0, 0.1, 0), Vector3(0, 0.13, 0), 0.044, 0.044, 6, WRAP)
	_prism(t, Vector3(-0.115, 0.36, 0), Vector3(0.115, 0.36, 0), 0.066, 0.066, 6, STONE)
	_prism(t, Vector3(-0.14, 0.36, 0), Vector3(-0.11, 0.36, 0), 0.05, 0.068, 6, STONE_LIGHT)
	_prism(t, Vector3(0.11, 0.36, 0), Vector3(0.14, 0.36, 0), 0.068, 0.05, 6, STONE_LIGHT)
	_prism(t, Vector3(0, 0.28, 0), Vector3(0, 0.33, 0), 0.04, 0.05, 6, ROPE)  # lashing under the head
	_prism(t, Vector3(0, 0.395, 0), Vector3(0, 0.42, 0), 0.03, 0.022, 6, WOOD_DARK)  # handle tip above the head
	return t


## A chunky box, optionally narrower at the top (top_scale), lighter on top.
func _box(t: SurfaceTool, c: Vector3, s: Vector3, top_scale: float, colour: Color, side_colour: Color) -> void:
	var h := s * 0.5
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for k in 4:
		var sx := -1.0 if k == 0 or k == 3 else 1.0
		var sz := -1.0 if k < 2 else 1.0
		lo.append(c + Vector3(sx * h.x, -h.y, sz * h.z))
		hi.append(c + Vector3(sx * h.x * top_scale, h.y, sz * h.z * top_scale))
	_tri(t, hi[0], hi[2], hi[1], colour)
	_tri(t, hi[0], hi[3], hi[2], colour)
	_tri(t, lo[0], lo[1], lo[2], side_colour.darkened(0.15))
	_tri(t, lo[0], lo[2], lo[3], side_colour.darkened(0.15))
	for k in 4:
		var j := (k + 1) % 4
		var shade := side_colour if k % 2 == 0 else side_colour.darkened(0.06)
		_tri(t, lo[k], hi[j], hi[k], shade)
		_tri(t, lo[k], lo[j], hi[j], shade)


func _tool() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


func _tri(t: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	t.set_color(colour)
	t.set_normal(normal)
	for p in [a, b, c]:
		t.add_vertex(p)


## A tapered prism from a to b (radii ra, rb), with caps; flat shaded.
func _prism(t: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, sides: int, colour: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	for k in sides:
		var ang := TAU * k / sides
		var dir := side * cos(ang) + other * sin(ang)
		ring_a.append(a + dir * ra)
		ring_b.append(b + dir * rb)
	var dark := colour.darkened(0.06)
	for k in sides:
		var j := (k + 1) % sides
		var shade := colour  # one colour all round, so the smoothed prism reads as one round piece
		_tri(t, ring_a[k], ring_b[k], ring_b[j], shade)
		_tri(t, ring_a[k], ring_b[j], ring_a[j], shade)
	for k in range(1, sides - 1):
		_tri(t, ring_a[0], ring_a[k + 1], ring_a[k], dark)
		_tri(t, ring_b[0], ring_b[k], ring_b[k + 1], colour)


## A leaf-shaped flint head from base to tip: a diamond cross-section (width, thickness), widest a third of the way.
func _blade(t: SurfaceTool, base: Vector3, tip: Vector3, width: float, thick: float, colour: Color, light: Color) -> void:
	var axis := (tip - base).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis.cross(side)
	var mid := base.lerp(tip, 0.35)
	var ring: Array[Vector3] = [mid + side * width, mid + other * thick, mid - side * width, mid - other * thick]
	for k in 4:
		var j := (k + 1) % 4
		_tri(t, ring[k], tip, ring[j], light if k % 2 == 0 else colour)
		_tri(t, ring[j], base, ring[k], colour.darkened(0.08))


## A flat, double-sided fletching fin along the shaft from a to b, sticking out by out.
func _fin(t: SurfaceTool, a: Vector3, b: Vector3, out: Vector3, colour: Color) -> void:
	var c := a + out + (b - a) * 0.15
	var d := a + out * 0.7 + (b - a) * 0.75
	for quad in [[a, c, d, b]]:
		_tri(t, quad[0], quad[1], quad[2], colour)
		_tri(t, quad[0], quad[2], quad[3], colour)
		_tri(t, quad[0], quad[2], quad[1], colour.darkened(0.1))
		_tri(t, quad[0], quad[3], quad[2], colour.darkened(0.1))


## A chunky faceted lump (club head, pouch, pebble): an octahedron-based sphere, jittered, darker below.
func _lump(t: SurfaceTool, centre: Vector3, r: Vector3, low: Color, high: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Jitter each distinct position once so shared corners stay shared.
	var moved := {}
	for v in verts:
		var key := v.snapped(Vector3.ONE * 0.001)
		if not moved.has(key):
			moved[key] = v * rng.randf_range(0.85, 1.1)
	for n in range(0, index.size(), 3):
		var p: Array[Vector3] = []
		for m in 3:
			var v: Vector3 = moved[verts[index[n + m]].snapped(Vector3.ONE * 0.001)]
			p.append(centre + Vector3(v.x / 0.5 * r.x, v.y / 0.5 * r.y, v.z / 0.5 * r.z))
		var up := ((p[0] + p[1] + p[2]) / 3.0 - centre).normalized().y
		var colour := low.lerp(high, clampf(up * 0.5 + 0.5, 0.0, 1.0))
		if (p[0] - p[1]).length() < 0.0001 or (p[1] - p[2]).length() < 0.0001 or (p[0] - p[2]).length() < 0.0001:
			continue
		_tri(t, p[0], p[2], p[1], colour)


func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return PeakSmooth.soften(mat)


func _save(t: SurfaceTool, item: String, as_scene: bool) -> void:
	t.index()
	var mesh := t.commit()
	mesh.surface_set_material(0, _material())
	mesh = PeakSmooth.smooth(mesh)
	var mesh_path := OUT + item + ".res"
	ResourceSaver.save(mesh, mesh_path)
	mesh.take_over_path(mesh_path)
	if as_scene:
		var root := Node3D.new()
		root.name = item.capitalize()
		var model := MeshInstance3D.new()
		model.name = "Model"
		model.mesh = mesh
		root.add_child(model)
		model.owner = root
		var scene := PackedScene.new()
		scene.pack(root)
		ResourceSaver.save(scene, OUT + item + ".tscn")
		root.free()
	print("baked ", item, ": ", mesh.surface_get_array_index_len(0) / 3, " triangles")
