extends SceneTree

## Bakes the stylized trees and bushes (owner, 2026-11-02: trees and bushes in the style of the game PEAK,
## to match the rocks of bake_peak_rocks.gd). Our own procedural shapes, nothing taken from that game:
## a leafy crown is a cluster of chunky jittered icosahedra ("puffs"), a pine is a stack of jagged cones,
## trunks and branches are six-sided tapered prisms; palms and undergrowth have folded leaf strips.
## Everything is one surface with vertex colours: bright, saturated greens, lit tops and dark, cool undersides.
## Normals lean almost fully to the puff's own round shape (SOFT), so the crowns read as soft, fluffy
## blobs; lighting wraps softly round them (peak_smooth.gd soften). Origin at the foot of the trunk (bushes: their centre).
## Run: godot --headless --path . -s res://tools/bake_peak_trees.gd

const PeakSmooth := preload("res://tools/peak_smooth.gd")
const OUT := "res://assets/nature/meshes/peak/"
const LEAF_DARK := Color(0.07, 0.24, 0.1)
const LEAF: Array[Color] = [Color(0.24, 0.52, 0.12), Color(0.3, 0.56, 0.1), Color(0.2, 0.48, 0.15)]
const LEAF_LIGHT := Color(0.56, 0.78, 0.22)
const PINE_DARK := Color(0.04, 0.18, 0.12)
const PINE := Color(0.1, 0.36, 0.18)
const PINE_LIGHT := Color(0.3, 0.56, 0.22)
const BARK := Color(0.47, 0.31, 0.18)
const BARK_DARK := Color(0.27, 0.17, 0.1)
const BIRCH := Color(0.72, 0.69, 0.6)
const DEAD := Color(0.42, 0.35, 0.28)
const PALM_BARK := Color(0.6, 0.45, 0.28)
## How far a puff's normals lean from the facet to its round shape: 0 flat facets, 1 a smooth ball.
const SOFT := 0.9  # owner 2026-11-02: crowns read as soft lumps, not as facets glued together
const PHI := 1.618034
const ICO_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
	[7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
	[8, 6, 7], [9, 8, 1],
]

var _tool: SurfaceTool
var _rng := RandomNumberGenerator.new()
## The crown's height span, for the dark-underside to lit-top gradient.
var _span := Vector2(0.0, 1.0)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_rng.seed = 2611
	# Leafy trees: round, tall, wide and a pale-barked one (crown height, width, trunk height, bark).
	var oaks := [[5.5, 6.0, 4.0, BARK], [7.5, 4.2, 4.5, BARK], [4.5, 8.0, 3.2, BARK], [5.0, 4.6, 5.5, BIRCH]]
	for n in oaks.size():
		_begin()
		_leafy(oaks[n][0], oaks[n][1], oaks[n][2], oaks[n][3])
		_save(OUT + "PeakTree%d.res" % (n + 1))
	for n in 3:
		_begin()
		_pine(3 + n, _rng.randf_range(9.0, 13.0))
		_save(OUT + "PeakPine%d.res" % (n + 1))
	for n in 2:
		_begin()
		_dead(_rng.randf_range(6.0, 8.0))
		_save(OUT + "PeakDead%d.res" % (n + 1))
	for n in 3:
		_begin()
		_palm(_rng.randf_range(5.5, 7.5), _rng.randf_range(0.6, 1.8))
		_save(OUT + "PeakPalm%d.res" % (n + 1), true)
	for n in 3:
		_begin()
		_bush(_rng.randf_range(2.0, 2.4))
		_save(OUT + "PeakBush%d.res" % (n + 1))
	for n in 3:
		_begin()
		_shrub(6 + n * 2, _rng.randf_range(0.7, 0.9))
		_save(OUT + "PeakShrub%d.res" % (n + 1), true)
	quit()


func _begin() -> void:
	_tool = SurfaceTool.new()
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


## One triangle, turned so its front (clockwise, Godot) faces `out`.
func _tri(p: Array, c: Array, n: Array, out: Vector3) -> void:
	var order := [0, 1, 2] if (p[1] - p[0]).cross(p[2] - p[0]).dot(out) < 0.0 else [0, 2, 1]
	for k: int in order:
		var col: Color = c[k]
		col.a = 1.0
		_tool.set_color(col)
		_tool.set_normal((n[k] as Vector3).normalized())
		_tool.add_vertex(p[k])


## A puff of foliage: a jittered icosahedron of radii r round centre. Lighter on top and towards the outside
## of the crown (core: the crown's middle), darker underneath and inside.
func _puff(centre: Vector3, r: Vector3, core: Vector3, base: Color) -> void:
	var verts: Array[Vector3] = []
	for v: Vector3 in [Vector3(-1, PHI, 0), Vector3(1, PHI, 0), Vector3(-1, -PHI, 0), Vector3(1, -PHI, 0),
			Vector3(0, -1, PHI), Vector3(0, 1, PHI), Vector3(0, -1, -PHI), Vector3(0, 1, -PHI),
			Vector3(PHI, 0, -1), Vector3(PHI, 0, 1), Vector3(-PHI, 0, -1), Vector3(-PHI, 0, 1)]:
		verts.append(centre + v.normalized() * _rng.randf_range(0.85, 1.12) * r)
	for f: Array in ICO_FACES:
		var p := [verts[f[0]], verts[f[1]], verts[f[2]]]
		var mid: Vector3 = (p[0] + p[1] + p[2]) / 3.0
		var facet: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
		if facet.dot(mid - centre) < 0.0:
			facet = -facet
		_rng.randf()  # was a per-face tint; still drawn so the crowns keep their random layout
		var tint := 1.0
		var cols := []
		var normals := []
		for q: Vector3 in p:
			var round_n := ((q - centre) / (r * r)).normalized()
			var n := facet.lerp(round_n, SOFT).normalized()
			normals.append(n)
			var up := clampf((q.y - _span.x) / (_span.y - _span.x), 0.0, 1.0)
			var outside := clampf((q - core).length() / maxf(0.01, (centre - core).length() + r.length() * 0.6), 0.0, 1.0)
			var c := LEAF_DARK.lerp(base, clampf(up * 1.4 + 0.15, 0.0, 1.0) * lerpf(0.75, 1.0, outside))
			c = c.lerp(LEAF_LIGHT, clampf(n.y, 0.0, 1.0) * up * 0.55)
			cols.append(c * tint)
		_tri(p, cols, normals, facet)


## A tapered prism from a to b (sides around), radii ra and rb, colours ca and cb; smooth round normals.
## `flare` widens the first ring into roots.
func _limb(a: Vector3, b: Vector3, ra: float, rb: float, ca: Color, cb: Color, sides := 6, flare := 1.0) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var turn := _rng.randf() * TAU
	var ring_a: Array[Vector3] = []
	var ring_b: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for k in sides:
		var d := side.rotated(axis, turn + TAU * k / sides)
		dirs.append(d)
		ring_a.append(a + d * ra * (flare if k % 2 == 0 else flare * 0.8))
		ring_b.append(b + d * rb)
	for k in sides:
		var m := (k + 1) % sides
		var out := (dirs[k] + dirs[m]).normalized()
		_tri([ring_a[k], ring_a[m], ring_b[k]], [ca, ca, cb], [dirs[k], dirs[m], dirs[k]], out)
		_tri([ring_a[m], ring_b[m], ring_b[k]], [ca, cb, cb], [dirs[m], dirs[m], dirs[k]], out)
	if rb > 0.05:  # cap the cut end
		for k in sides:
			_tri([b, ring_b[k], ring_b[(k + 1) % sides]], [cb, cb, cb], [axis, axis, axis], axis)


## A broadleaf: a trunk that leans and splits into two or three branches, each ending in a cluster of puffs.
func _leafy(crown_h: float, crown_w: float, trunk_h: float, bark: Color) -> void:
	var dark := bark * 0.6 if bark == BIRCH else BARK_DARK
	var lean := Vector3(_rng.randf_range(-0.4, 0.4), 0.0, _rng.randf_range(-0.4, 0.4))
	var top := Vector3(0.0, trunk_h, 0.0) + lean
	var r := 0.18 * crown_w / 5.0 + 0.2
	_limb(Vector3.ZERO, top, r * 1.25, r * 0.8, dark, bark, 6, 1.5)
	var core := top + Vector3(0.0, crown_h * 0.45, 0.0)
	_span = Vector2(top.y - 0.3, top.y + crown_h)
	var leaf: Color = LEAF[_rng.randi() % LEAF.size()]
	if bark == BIRCH:
		leaf = leaf.lerp(LEAF_LIGHT, 0.25)
	_puff(core, Vector3(crown_w, crown_h, crown_w) * 0.42, core, leaf)
	var branches := 2 + _rng.randi() % 2
	for b in branches:
		var a := TAU * b / branches + _rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var tip := top + dir * crown_w * 0.28 + Vector3(0.0, crown_h * _rng.randf_range(0.3, 0.5), 0.0)
		_limb(top - Vector3(0.0, 0.3, 0.0), tip, r * 0.6, r * 0.3, bark, bark)
		var size := Vector3(crown_w * 0.34, crown_h * 0.32, crown_w * 0.34) * _rng.randf_range(0.85, 1.1)
		_puff(tip + Vector3(0.0, size.y * 0.3, 0.0), size, core, leaf)
	for n in 4:  # smaller puffs round the rim and on top fill the gaps
		var a := _rng.randf() * TAU
		var at := core + Vector3(cos(a) * crown_w * 0.3, crown_h * _rng.randf_range(-0.05, 0.4), sin(a) * crown_w * 0.3)
		_puff(at, Vector3.ONE * minf(crown_w, crown_h) * _rng.randf_range(0.24, 0.3), core, leaf)


## A pine: a straight trunk under `tiers` jagged cones, wide at the bottom, each overlapping the next.
func _pine(tiers: int, height: float) -> void:
	var trunk_h := height * 0.18
	_limb(Vector3.ZERO, Vector3(0.0, height * 0.75, 0.0), height * 0.035, height * 0.015, BARK_DARK, BARK, 6, 1.4)
	_span = Vector2(trunk_h, height)
	var step := (height - trunk_h) / (tiers + 0.6)
	for t in tiers:
		var y := trunk_h + step * t
		var h := step * 1.75
		var radius := height * 0.24 * (1.0 - 0.17 * t) * _rng.randf_range(0.92, 1.05)
		_cone(Vector3(0.0, y, 0.0), radius, h, 7 + (1 if t == 0 else 0))


## One jagged cone of a pine: the rim zigzags in and out and its points droop; a shallow hollow underneath.
func _cone(base: Vector3, radius: float, h: float, sides: int) -> void:
	var apex := base + Vector3(_rng.randf_range(-0.08, 0.08), h, _rng.randf_range(-0.08, 0.08))
	var under := base + Vector3(0.0, h * 0.22, 0.0)
	var turn := _rng.randf() * TAU
	var rim: Array[Vector3] = []
	for k in sides * 2:
		var tip := k % 2 == 0
		var d := Vector3(cos(turn + PI * k / sides), 0.0, sin(turn + PI * k / sides))
		rim.append(base + d * radius * (1.0 if tip else 0.72) + Vector3(0.0, -h * 0.12 if tip else h * 0.04, 0.0))
	var light := PINE.lerp(PINE_LIGHT, clampf((base.y - _span.x) / (_span.y - _span.x), 0.0, 1.0) * 0.6)
	for k in rim.size():
		var a := rim[k]
		var b := rim[(k + 1) % rim.size()]
		var facet := (a - apex).cross(b - apex).normalized()
		var mid := (a + b) * 0.5 - base
		if facet.dot(mid) < 0.0:
			facet = -facet
		var round_a := ((a - base).normalized() + Vector3.UP * 0.8).normalized()
		var round_b := ((b - base).normalized() + Vector3.UP * 0.8).normalized()
		var tint := 1.0 + _rng.randf_range(-0.05, 0.05)
		_tri([apex, a, b], [light.lerp(PINE_LIGHT, 0.45) * tint, PINE * tint, PINE * tint],
			[Vector3.UP, facet.lerp(round_a, SOFT), facet.lerp(round_b, SOFT)], facet)
		_tri([under, b, a], [PINE_DARK, PINE_DARK.lerp(PINE, 0.4), PINE_DARK.lerp(PINE, 0.4)],
			[Vector3.DOWN, Vector3.DOWN, Vector3.DOWN], Vector3.DOWN)


## A dead tree: a bare, slightly crooked trunk and a few upturned branches.
func _dead(height: float) -> void:
	var mid := Vector3(_rng.randf_range(-0.4, 0.4), height * 0.55, _rng.randf_range(-0.4, 0.4))
	var top := mid + Vector3(_rng.randf_range(-0.5, 0.5), height * 0.45, _rng.randf_range(-0.5, 0.5))
	_limb(Vector3.ZERO, mid, 0.42, 0.3, DEAD * 0.6, DEAD, 6, 1.5)
	_limb(mid, top, 0.3, 0.06, DEAD, DEAD * 1.1)
	for n in 4:
		var from := Vector3.ZERO.lerp(mid, 0.6 + 0.3 * n) if n < 2 else mid.lerp(top, 0.3 * (n - 1))
		var a := _rng.randf() * TAU
		var tip := from + Vector3(cos(a), 0.0, sin(a)) * height * 0.25 + Vector3(0.0, height * 0.2, 0.0)
		_limb(from, tip, 0.15, 0.03, DEAD, DEAD * 1.1, 5)


## A palm: a curved trunk in ringed segments and a crown of drooping, folded fronds.
func _palm(height: float, bend: float) -> void:
	var dir := Vector3(cos(_rng.randf() * TAU), 0.0, sin(_rng.randf() * TAU))
	var prev := Vector3.ZERO
	var segments := 6
	for s in segments:
		var t := float(s + 1) / segments
		var next := Vector3(0.0, height * t, 0.0) + dir * bend * t * t
		var shade := 0.85 if s % 2 == 0 else 1.0
		_limb(prev, next, 0.24 - 0.1 * s / segments, 0.2 - 0.1 * t, PALM_BARK * shade * 0.8, PALM_BARK * shade, 6, 1.35 if s == 0 else 1.0)
		prev = next
	_span = Vector2(prev.y - 2.0, prev.y + 0.5)
	var fronds := 7 + _rng.randi() % 2
	for f in fronds:
		var a := TAU * f / fronds + _rng.randf_range(-0.2, 0.2)
		_frond(prev, Vector3(cos(a), 0.0, sin(a)), _rng.randf_range(2.6, 3.2), 0.55, _rng.randf_range(0.5, 0.9))


## One folded leaf from root along out: rises, then droops by `droop` of its length; the spine is raised above
## the edges, so the two halves catch light differently. Single-sided triangles (the material draws both).
func _frond(root: Vector3, out: Vector3, length: float, width: float, droop: float, rise := 0.35) -> void:
	var side := out.cross(Vector3.UP)
	var spine: Array[Vector3] = []
	var widths := [0.0, 1.0, 0.85, 0.0]
	for k in 4:
		var t := k / 3.0
		spine.append(root + out * length * t + Vector3.UP * length * (rise * t - droop * t * t))
	var leaf: Color = LEAF[_rng.randi() % LEAF.size()]
	for half: float in [-1.0, 1.0]:
		var edge: Array[Vector3] = []
		for k in 4:
			edge.append(spine[k] + side * half * width * widths[k] - Vector3.UP * width * widths[k] * 0.3)
		var c_spine := leaf.lerp(LEAF_LIGHT, 0.35)
		var c_edge := leaf * (0.8 if half < 0.0 else 0.95)
		for k in 3:
			var n := (Vector3.UP + side * half * 0.3).normalized()
			_tri([spine[k], edge[k + 1], spine[k + 1]], [c_spine, c_edge, c_spine], [n, n, n], Vector3.UP)
			if k > 0:
				_tri([spine[k], edge[k], edge[k + 1]], [c_spine, c_edge, c_edge], [n, n, n], Vector3.UP)


## A bush: three to five puffs, wider than tall, the lowest sunk a little into the ground.
func _bush(width: float) -> void:
	var leaf: Color = LEAF[_rng.randi() % LEAF.size()]
	var core := Vector3(0.0, width * 0.25, 0.0)
	_span = Vector2(-0.1, width * 0.65)
	_puff(core, Vector3(width * 0.4, width * 0.3, width * 0.4), core, leaf)
	var puffs := 3 + _rng.randi() % 3
	for n in puffs:
		var a := TAU * n / puffs + _rng.randf_range(-0.3, 0.3)
		var at := Vector3(cos(a) * width * 0.28, width * _rng.randf_range(0.12, 0.3), sin(a) * width * 0.28)
		_puff(at, Vector3.ONE * width * _rng.randf_range(0.2, 0.27), core, leaf)


## Undergrowth (instead of the fern pack): a low rosette of broad folded leaves.
func _shrub(leaves: int, length: float) -> void:
	_span = Vector2(0.0, length * 0.5)
	for n in leaves:
		var a := TAU * n / leaves + _rng.randf_range(-0.25, 0.25)
		var rise := _rng.randf_range(0.8, 1.3)
		_frond(Vector3.ZERO, Vector3(cos(a), 0.0, sin(a)), length * _rng.randf_range(0.8, 1.15), length * 0.28,
			rise * 0.6, rise)


func _save(path: String, two_sided := false) -> void:
	_tool.index()
	var mesh := _tool.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	PeakSmooth.soften(mat)
	if two_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	ResourceSaver.save(mesh, path)
	print("%s: %d triangles, %s" % [path.get_file(), mesh.surface_get_array_index_len(0) / 3, mesh.get_aabb()])
