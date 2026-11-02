extends SceneTree

## Bakes the stumps and logs in the PEAK style (owner, 2026-11-02), to match the trees of bake_peak_trees.gd and
## the rocks of bake_peak_rocks.gd. Our own procedural shapes: chunky six/seven-sided prisms with jittered rings,
## a pale cut face with a darker rim, a mossy top, a few branch stubs. One surface, vertex colours.
## Same footprints as the old models (stumps and logs are solid, boxes fitted to the AABB): origin at the middle
## of the footing, base on y=0, logs lie along Z.
## Run: godot --headless --path . -s res://tools/bake_peak_stumps.gd

const OUT := "res://assets/nature/meshes/peak/"
const BARK := Color(0.47, 0.31, 0.18)
const BARK_DARK := Color(0.25, 0.16, 0.09)
const CUT := Color(0.86, 0.68, 0.4)
const CUT_RIM := Color(0.6, 0.42, 0.22)
const MOSS := Color(0.3, 0.56, 0.12)
const MOSS_LIGHT := Color(0.52, 0.76, 0.22)

var _tool: SurfaceTool
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_rng.seed = 4711
	_begin()
	_stump(0.5, 0.6)
	_save(OUT + "PeakStump1.res")
	# Radius, length (the old WoodLog, Log_1..3).
	var logs := [[0.34, 2.67, 1], [0.27, 4.59, 0], [0.42, 3.84, 2], [0.52, 2.01, 1]]
	for n in logs.size():
		_begin()
		_log(logs[n][0], logs[n][1], logs[n][2])
		_save(OUT + "PeakLog%d.res" % (n + 1))
	quit()


func _begin() -> void:
	_tool = SurfaceTool.new()
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


func _tri(p: Array, c: Array, n: Array, out: Vector3) -> void:
	var order := [0, 1, 2] if (p[1] - p[0]).cross(p[2] - p[0]).dot(out) < 0.0 else [0, 2, 1]
	for k: int in order:
		var col: Color = c[k]
		col.a = 1.0
		_tool.set_color(col)
		_tool.set_normal((n[k] as Vector3).normalized())
		_tool.add_vertex(p[k])


## Bark colour at a ring vertex: dark underneath, brown at the sides, moss on top (moss: 0 none, 1 patchy, 2 heavy).
func _bark(d: Vector3, moss: int, shade: float) -> Color:
	var c := BARK_DARK.lerp(BARK, clampf(d.y * 0.5 + 0.6, 0.0, 1.0)) * shade
	if moss > 0 and d.y > 0.45:
		var m := clampf((d.y - 0.45) * (1.0 if moss == 1 else 2.0), 0.0, 1.0)
		c = c.lerp(MOSS.lerp(MOSS_LIGHT, clampf(d.y, 0.0, 1.0) * 0.6), m)
	return c


## A tapered prism from a to b; ring radii ra, rb with jitter; flat-ish facets, normals half way to round.
## The far end b gets a cut face. Returns nothing.
func _prism(a: Vector3, b: Vector3, ra: float, rb: float, sides: int, moss: int, cap_a := false, flare := 1.0) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var turn := _rng.randf() * TAU
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for k in sides:
		var d := side.rotated(axis, turn + TAU * k / sides)
		dirs.append(d)
		ring_a.append(a + d * ra * _rng.randf_range(0.92, 1.08) * (flare if k % 2 == 0 else 1.0))
		ring_b.append(b + d * rb * _rng.randf_range(0.92, 1.08))
	for k in sides:
		var m := (k + 1) % sides
		var out := (dirs[k] + dirs[m]).normalized()
		var shade := _rng.randf_range(0.93, 1.05)
		var ca := _bark(dirs[k], moss, shade)
		var cm := _bark(dirs[m], moss, shade)
		var nk := (dirs[k] + out).normalized()
		var nm := (dirs[m] + out).normalized()
		_tri([ring_a[k], ring_a[m], ring_b[k]], [ca, cm, ca], [nk, nm, nk], out)
		_tri([ring_a[m], ring_b[m], ring_b[k]], [cm, cm, ca], [nm, nm, nk], out)
	_cap(b, axis, ring_b)
	if cap_a:
		_cap(a, -axis, ring_a)


## A cut face: pale in the middle, a darker rim, a little domed.
func _cap(centre: Vector3, out: Vector3, ring: Array[Vector3]) -> void:
	var n := ring.size()
	var mid := centre + out * 0.03
	var inner: Array[Vector3] = []
	for k in n:
		inner.append(centre.lerp(ring[k], 0.72) + out * 0.015)
	for k in n:
		var m := (k + 1) % n
		_tri([mid, inner[k], inner[m]], [CUT, CUT, CUT], [out, out, out], out)
		_tri([inner[k], ring[k], ring[m]], [CUT, CUT_RIM, CUT_RIM], [out, out, out], out)
		_tri([inner[k], ring[m], inner[m]], [CUT, CUT_RIM, CUT], [out, out, out], out)


## A stump: a wide root flare, a thick trunk, an uneven cut top; a moss cushion and a few root bumps.
func _stump(radius: float, height: float) -> void:
	_prism(Vector3.ZERO, Vector3(0.0, height, 0.0), radius * 1.12, radius * 0.88, 7, 0, false, 1.25)
	for n in 3:  # roots
		var a := TAU * n / 3.0 + _rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(a), 0.0, sin(a))
		_prism(Vector3(0.0, 0.12, 0.0) + dir * radius * 0.7, dir * radius * 1.15,
			radius * 0.2, radius * 0.1, 5, 0)
	# Moss cushion on one side of the top.
	var a := _rng.randf() * TAU
	var at := Vector3(cos(a), 0.0, sin(a)) * radius * 0.35 + Vector3(0.0, height, 0.0)
	_cushion(at, radius * 0.38)


## A flat moss lump: a squashed six-sided dome.
func _cushion(centre: Vector3, r: float) -> void:
	var top := centre + Vector3(0.0, r * 0.45, 0.0)
	var ring: Array[Vector3] = []
	for k in 6:
		var a := TAU * k / 6.0
		ring.append(centre + Vector3(cos(a), 0.0, sin(a)) * r * _rng.randf_range(0.85, 1.1) - Vector3(0.0, 0.04, 0.0))
	for k in 6:
		var m := (k + 1) % 6
		var facet := (ring[m] - ring[k]).cross(top - ring[k]).normalized()
		if facet.y < 0.0:
			facet = -facet
		_tri([ring[k], ring[m], top], [MOSS, MOSS, MOSS_LIGHT], [facet, facet, facet], facet)


## A log lying along Z, centre at the origin: a six-sided trunk with cut faces at both ends, branch stubs,
## moss on top. variant picks how mossy it is.
func _log(radius: float, length: float, moss: int) -> void:
	var a := Vector3(0.0, radius, -length * 0.5)
	var b := Vector3(0.0, radius, length * 0.5)
	_prism(a, b, radius, radius * 0.92, 6, moss, true)
	var stubs := 1 + int(length > 3.0)
	for n in stubs:
		var z := _rng.randf_range(-0.3, 0.3) * length
		var dir := Vector3(_rng.randf_range(-0.6, 0.6), 1.0, _rng.randf_range(-0.5, 0.5)).normalized()
		var base := Vector3(0.0, radius, z) + dir * radius * 0.6
		_prism(base, base + dir * radius * 0.9, radius * 0.3, radius * 0.22, 5, 0)


func _save(path: String) -> void:
	_tool.index()
	var mesh := _tool.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesh.surface_set_material(0, mat)
	ResourceSaver.save(mesh, path)
	print("%s: %d triangles, %s" % [path.get_file(), mesh.surface_get_array_index_len(0) / 3, mesh.get_aabb()])
