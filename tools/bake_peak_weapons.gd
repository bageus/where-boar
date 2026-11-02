extends SceneTree

## Bakes the hunter's weapons in the style of the game PEAK (owner, 2026-11-02), to match the rocks and trees
## (bake_peak_rocks.gd, bake_peak_trees.gd). Our own procedural shapes, nothing taken from that game: chunky
## five- and six-sided prisms, flat shaded, one surface with bright vertex colours (warm wood, blue-grey flint,
## red wraps, cream rope). Each weapon is saved as a mesh and as a small scene (root Node3D + MeshInstance3D
## "Model") that replaces the old textured .glb in hands.tscn, spear.tscn, arrow.tscn and stone.tscn.
## Axes: thrown things lie along +Y with the tip at +Y, centred on the origin, so the projectile scenes' mesh
## rotation (model +Y -> body -Z, along the capsule) flies them tip first. Held things have the grip at the origin.
## Run: godot --headless --path . -s res://tools/bake_peak_weapons.gd

const PeakSmooth := preload("res://tools/peak_smooth.gd")
const OUT := "res://assets/models/peak_weapons/"
const WOOD := Color(0.8, 0.5, 0.24)
const WOOD_DARK := Color(0.6, 0.35, 0.16)
const FLINT := Color(0.52, 0.58, 0.7)
const FLINT_LIGHT := Color(0.7, 0.76, 0.86)
const BONE := Color(0.9, 0.86, 0.74)
const BONE_LIGHT := Color(0.99, 0.97, 0.9)
const WRAP := Color(0.86, 0.24, 0.18)
const ROPE := Color(0.95, 0.86, 0.6)
const LEATHER := Color(0.55, 0.31, 0.15)
const FEATHER := Color(0.97, 0.96, 0.9)
const STONE := Color(0.6, 0.6, 0.62)
const STONE_LIGHT := Color(0.74, 0.73, 0.72)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_save(_spear(), "spear")
	_save(_spear_bone(), "spear_bone")
	_save(_spear_wood(), "spear_wood")
	_save(_arrow(), "arrow")
	_save(_club(), "club")
	_save(_knife(), "knife")
	_save(_sling(), "sling")
	_save(_bow(), "bow")
	_save(_stone(), "stone")
	quit()


func _spear() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.9, 0), Vector3(0, 0.62, 0), 0.034, 0.03, 6, WOOD)
	_prism(t, Vector3(0, -0.94, 0), Vector3(0, -0.88, 0), 0.03, 0.04, 6, WOOD_DARK)  # butt
	_prism(t, Vector3(0, -0.12, 0), Vector3(0, 0.12, 0), 0.045, 0.045, 6, LEATHER)  # grip
	_prism(t, Vector3(0, 0.56, 0), Vector3(0, 0.66, 0), 0.048, 0.042, 6, WRAP)  # binding
	_blade(t, Vector3(0, 0.6, 0), Vector3(0, 0.92, 0), 0.075, 0.035, FLINT, FLINT_LIGHT)
	return t


## Bone spear: a pale shaft, a long splintered bone point lashed on with rope.
func _spear_bone() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.9, 0), Vector3(0, 0.62, 0), 0.034, 0.03, 6, WOOD)
	_prism(t, Vector3(0, -0.94, 0), Vector3(0, -0.88, 0), 0.03, 0.04, 6, WOOD_DARK)  # butt
	_prism(t, Vector3(0, -0.12, 0), Vector3(0, 0.12, 0), 0.045, 0.045, 6, LEATHER)  # grip
	_prism(t, Vector3(0, 0.5, 0), Vector3(0, 0.7, 0), 0.046, 0.044, 6, ROPE)  # lashing
	_prism(t, Vector3(0, 0.6, 0), Vector3(0, 0.66, 0), 0.05, 0.05, 6, WRAP)
	_prism(t, Vector3(0, 0.6, 0), Vector3(0, 0.86, 0), 0.036, 0.028, 5, BONE)  # socket of the bone
	_blade(t, Vector3(0, 0.82, 0), Vector3(0, 1.0, 0), 0.04, 0.03, BONE, BONE_LIGHT)
	_blade(t, Vector3(0.0, 0.7, 0), Vector3(0.07, 0.82, 0), 0.03, 0.02, BONE, BONE_LIGHT)  # barb
	return t


## Plain sharpened wooden spear: one long shaft, fire-darkened point, a little rope grip.
func _spear_wood() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.9, 0), Vector3(0, 0.62, 0), 0.034, 0.03, 6, WOOD)
	_prism(t, Vector3(0, -0.94, 0), Vector3(0, -0.88, 0), 0.03, 0.04, 6, WOOD_DARK)  # butt
	_prism(t, Vector3(0, -0.12, 0), Vector3(0, 0.12, 0), 0.042, 0.042, 6, ROPE)  # grip
	_prism(t, Vector3(0, 0.6, 0), Vector3(0, 0.98, 0), 0.03, 0.004, 6, WOOD_DARK)  # sharpened point
	return t


func _arrow() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.4, 0), Vector3(0, 0.31, 0), 0.014, 0.013, 5, WOOD)
	_prism(t, Vector3(0, 0.28, 0), Vector3(0, 0.32, 0), 0.02, 0.018, 5, WRAP)
	_blade(t, Vector3(0, 0.3, 0), Vector3(0, 0.42, 0), 0.034, 0.016, FLINT, FLINT_LIGHT)
	for k in 3:  # three fins, chunky triangles near the nock
		var a := TAU * k / 3.0
		var out := Vector3(cos(a), 0, sin(a))
		var colour := WRAP if k == 0 else FEATHER
		_fin(t, Vector3(0, -0.36, 0), Vector3(0, -0.18, 0), out * 0.045, colour)
	_prism(t, Vector3(0, -0.42, 0), Vector3(0, -0.38, 0), 0.016, 0.018, 5, WOOD_DARK)  # nock
	return t


func _club() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.18, 0), Vector3(0, 0.42, 0), 0.03, 0.055, 6, WOOD)
	_prism(t, Vector3(0, -0.12, 0), Vector3(0, 0.08, 0), 0.04, 0.042, 6, LEATHER)
	_prism(t, Vector3(0, -0.2, 0), Vector3(0, -0.16, 0), 0.036, 0.034, 6, WRAP)
	_lump(t, Vector3(0, 0.52, 0), Vector3(0.12, 0.14, 0.12), WOOD_DARK, WOOD, 7)
	# Two flint studs bound into the head.
	_blade(t, Vector3(0.07, 0.5, 0), Vector3(0.17, 0.53, 0), 0.03, 0.02, FLINT, FLINT_LIGHT)
	_blade(t, Vector3(-0.07, 0.46, 0.02), Vector3(-0.16, 0.5, 0.05), 0.03, 0.02, FLINT, FLINT_LIGHT)
	return t


func _knife() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.09, 0), Vector3(0, 0.05, 0), 0.024, 0.026, 6, LEATHER)
	_prism(t, Vector3(0, -0.11, 0), Vector3(0, -0.08, 0), 0.028, 0.026, 6, WRAP)
	_prism(t, Vector3(0, 0.03, 0), Vector3(0, 0.07, 0), 0.032, 0.03, 6, ROPE)
	_blade(t, Vector3(0, 0.04, 0), Vector3(0, 0.27, 0), 0.05, 0.022, FLINT, FLINT_LIGHT)
	return t


## A Y-shaped slingshot: handle down from the origin, prongs up, the band pulled back toward the holder (+Z).
func _sling() -> SurfaceTool:
	var t := _tool()
	_prism(t, Vector3(0, -0.11, 0), Vector3(0, 0.02, 0), 0.024, 0.028, 6, WOOD)
	_prism(t, Vector3(0, -0.08, 0), Vector3(0, -0.02, 0), 0.032, 0.032, 6, WRAP)
	var tips: Array[Vector3] = [Vector3(-0.08, 0.15, 0), Vector3(0.08, 0.15, 0)]
	for tip in tips:
		_prism(t, Vector3(0, 0.0, 0), tip, 0.024, 0.018, 5, WOOD)
		_prism(t, tip - Vector3(0, 0.025, 0), tip + Vector3(0, 0.012, 0), 0.024, 0.022, 5, ROPE)
	var pouch := Vector3(0, 0.13, 0.13)
	for tip in tips:
		_prism(t, tip, pouch + Vector3(signf(tip.x) * 0.02, 0, 0), 0.008, 0.008, 4, ROPE)
	_lump(t, pouch, Vector3(0.035, 0.022, 0.026), LEATHER, LEATHER, 5)
	return t


## A short bow: the grip at the origin, limbs curving forward (-Z) to tips 0.5 m up and down, the string behind.
func _bow() -> SurfaceTool:
	var t := _tool()
	var points: Array[Vector3] = []
	var segments := 6
	for n in range(-segments, segments + 1):
		var y := 0.5 * n / segments
		points.append(Vector3(0, y, -0.13 * (1.0 - pow(y / 0.5, 2.0))))
	for n in points.size() - 1:
		var mid := absf(points[n].y + points[n + 1].y) * 0.5 / 0.5
		_prism(t, points[n], points[n + 1], lerpf(0.026, 0.012, mid), lerpf(0.026, 0.012, mid), 5, WOOD)
	_prism(t, points[segments] + Vector3(0, -0.07, 0), points[segments] + Vector3(0, 0.07, 0), 0.032, 0.032, 6, WRAP)
	for end in [points[0], points[points.size() - 1]]:
		_prism(t, end - Vector3(0, 0.03, 0), end + Vector3(0, 0.03, 0), 0.017, 0.017, 5, ROPE)
	_prism(t, points[0], points[points.size() - 1], 0.005, 0.005, 3, ROPE)  # string
	return t


## A faceted pebble, bottom at the origin, about the size of the old stone.glb (0.23 x 0.18 x 0.22).
func _stone() -> SurfaceTool:
	var t := _tool()
	_lump(t, Vector3(0, 0.09, 0), Vector3(0.115, 0.09, 0.11), STONE, STONE_LIGHT, 3)
	return t


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


func _save(t: SurfaceTool, weapon: String) -> void:
	t.index()
	var mesh := t.commit()
	mesh.surface_set_material(0, _material())
	mesh = PeakSmooth.smooth(mesh)
	var mesh_path := OUT + weapon + ".res"
	ResourceSaver.save(mesh, mesh_path)
	mesh.take_over_path(mesh_path)
	var root := Node3D.new()
	root.name = weapon.capitalize()
	var model := MeshInstance3D.new()
	model.name = "Model"
	model.mesh = mesh
	root.add_child(model)
	model.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, OUT + weapon + ".tscn")
	root.free()
	print("baked ", weapon, ": ", mesh.surface_get_array_index_len(0) / 3, " triangles")
