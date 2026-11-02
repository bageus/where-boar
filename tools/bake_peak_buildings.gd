extends SceneTree

## Bakes the camp buildings in a simplified, PEAK-like style (owner, 2026-11-02: buildings to match the
## rocks and trees of bake_peak_rocks.gd and bake_peak_trees.gd). Our own procedural shapes, nothing taken
## from that game: chunky six-sided logs, thick hide slabs with two-tone stripes and ragged zigzag edges,
## faceted stones, bright warm colours. Each building is one mesh with vertex colours (plus a second,
## unshaded surface for flames and coals), a few hundred to a few thousand triangles instead of 10-60 K.
## Every model keeps the footprint and the anchor points of the model it replaces (camp.gd: cage slots,
## pen spots and rail, the tavern bench and hearth), so collisions and interaction distances stay the same.
## Writes assets/models/peak/<name>.scn. Run: godot --headless --path . -s res://tools/bake_peak_buildings.gd

const OUT := "res://assets/models/peak/"
const WOOD := Color(0.6, 0.36, 0.18)
const WOOD_DARK := Color(0.42, 0.24, 0.13)
const WOOD_LIGHT := Color(0.8, 0.56, 0.3)
const HIDE := Color(0.96, 0.84, 0.6)
const HIDE_DARK := Color(0.9, 0.55, 0.25)
const HIDE_RED := Color(0.8, 0.32, 0.2)
const STONE := Color(0.66, 0.66, 0.63)
const STONE_DARK := Color(0.48, 0.5, 0.5)
const CLAY := Color(0.84, 0.46, 0.26)
const IRON := Color(0.24, 0.24, 0.27)
const STRAW := Color(0.96, 0.8, 0.36)
const ROPE := Color(0.88, 0.74, 0.46)
const WATER := Color(0.32, 0.66, 0.84)
const DARK := Color(0.14, 0.09, 0.07)
const FRUIT: Array[Color] = [Color(0.9, 0.22, 0.18), Color(0.98, 0.78, 0.2), Color(0.55, 0.3, 0.75), Color(0.5, 0.78, 0.2)]
const FIRE := Color(1.0, 0.45, 0.08)
const FIRE_CORE := Color(1.0, 0.86, 0.3)
## How far a log's normals lean from the facet to its round shape (as the tree trunks, softer).
const SOFT := 0.5
const PHI := 1.618034
const ICO_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6],
	[7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10],
	[8, 6, 7], [9, 8, 1],
]
## The corners of a hexahedron (bottom 0-3, top 4-7, both counter-clockwise from above) by face.
const HEX_FACES := [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]

var _tool: SurfaceTool
var _glow: SurfaceTool
var _glowing := false
var _rng := RandomNumberGenerator.new()
var _body_material: StandardMaterial3D
var _glow_material: StandardMaterial3D


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_rng.seed = 1102
	_materials()
	for name: String in ["weapon_stall", "hunter_stall", "cage_rack", "campfire", "tavern", "aframe_hide_tent",
			"large_hide_tent", "round_hide_tent", "boar_pen", "tribal_well", "direction_sign"]:
		_tool = SurfaceTool.new()
		_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_glow = SurfaceTool.new()
		_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
		_glowing = false
		call("_" + name)
		_save(name)
	quit()


func _materials() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.vertex_color_use_as_albedo = true
	_body_material.vertex_color_is_srgb = true
	_body_material.roughness = 1.0
	_body_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	ResourceSaver.save(_body_material, OUT + "building.tres", ResourceSaver.FLAG_CHANGE_PATH)
	_glow_material = StandardMaterial3D.new()
	_glow_material.vertex_color_use_as_albedo = true
	_glow_material.vertex_color_is_srgb = true
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ResourceSaver.save(_glow_material, OUT + "glow.tres", ResourceSaver.FLAG_CHANGE_PATH)


# --- primitives --------------------------------------------------------------------------------------------

## One triangle facing `out`; normals per corner (flat when all three are the facet). Corners near the
## ground get darker (soft contact shade), each face a slight random tint so the facets read.
func _tri(p: Array, n: Array, col: Color, out: Vector3, glow := false) -> void:
	var facet: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	var order := [0, 1, 2] if facet.dot(out) < 0.0 else [0, 2, 1]
	var tint := 1.0 + _rng.randf_range(-0.04, 0.04)
	var st := _glow if glow else _tool
	_glowing = _glowing or glow
	for k: int in order:
		var q: Vector3 = p[k]
		var c := col * tint * (1.0 if glow else lerpf(0.68, 1.0, clampf((q.y + 0.05) / 0.7, 0.0, 1.0)))
		c.a = 1.0
		st.set_color(c)
		st.set_normal((n[k] as Vector3).normalized())
		st.add_vertex(q)


func _flat(p: Array, col: Color, out: Vector3, glow := false) -> void:
	var facet: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	if facet.dot(out) < 0.0:
		facet = -facet
	_tri(p, [facet, facet, facet], col, out, glow)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3) -> void:
	_flat([a, b, c], col, out)
	_flat([a, c, d], col, out)


## A thin sheet seen from both sides (flaps, valances, door shadows).
func _sheet(p: Array, col: Color) -> void:
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	_flat(p, col, n)
	_flat(p, col * 0.85, -n)


## A six-faced solid from eight corners (bottom 0-3, top 4-7), flat shaded.
func _hex(p: Array, col: Color) -> void:
	var centre := Vector3.ZERO
	for q: Vector3 in p:
		centre += q / 8.0
	for f: Array in HEX_FACES:
		var mid: Vector3 = (p[f[0]] + p[f[1]] + p[f[2]] + p[f[3]]) / 4.0
		_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, mid - centre)


func _box(centre: Vector3, size: Vector3, col: Color, yaw := 0.0, roll := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, roll)
	var h := size * 0.5
	var p := []
	for y in [-h.y, h.y]:
		for c: Vector2 in [Vector2(-h.x, -h.z), Vector2(h.x, -h.z), Vector2(h.x, h.z), Vector2(-h.x, h.z)]:
			p.append(centre + b * Vector3(c.x, y, c.y))
	_hex(p, col)


## A slab hanging from four top corners (a roof), `thick` deep.
func _slab(top: Array, thick: float, col: Color) -> void:
	var down := Vector3(0.0, -thick, 0.0)
	_hex([top[0] + down, top[1] + down, top[2] + down, top[3] + down, top[0], top[1], top[2], top[3]], col)


## A striped roof: the slab cut into `stripes` bands from edge a0-a1 to edge b0-b1, alternating colours.
func _roof(a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3, stripes: int, cols: Array, thick := 0.1) -> void:
	for k in stripes:
		var t0 := float(k) / stripes
		var t1 := float(k + 1) / stripes
		_slab([a0.lerp(a1, t0), a0.lerp(a1, t1), b0.lerp(b1, t1), b0.lerp(b1, t0)], thick, cols[k % cols.size()])


## A ragged hide edge: a row of hanging triangles along a-b, `depth` long.
func _zigzag(a: Vector3, b: Vector3, depth: float, teeth: int, col: Color) -> void:
	for k in teeth:
		var p0 := a.lerp(b, float(k) / teeth)
		var p1 := a.lerp(b, float(k + 1) / teeth)
		var tip := (p0 + p1) * 0.5 + Vector3(0.0, -depth * _rng.randf_range(0.7, 1.15), 0.0)
		_sheet([p0, p1, tip], col if k % 2 == 0 else col * 0.9)


## A tapered prism (a log, a post, a pot) from a to b, radii ra and rb; rb 0 makes a cone.
func _log(a: Vector3, b: Vector3, ra: float, col: Color, rb := -1.0, sides := 6, glow := false) -> void:
	rb = ra if rb < 0.0 else rb
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var turn := _rng.randf() * TAU
	var ra_ring: Array[Vector3] = []
	var rb_ring: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for k in sides:
		var d := side.rotated(axis, turn + TAU * k / sides)
		dirs.append(d)
		ra_ring.append(a + d * ra)
		rb_ring.append(b + d * rb)
	for k in sides:
		var m := (k + 1) % sides
		var out := (dirs[k] + dirs[m]).normalized()
		var nk := out.lerp(dirs[k], SOFT)
		var nm := out.lerp(dirs[m], SOFT)
		_tri([ra_ring[k], ra_ring[m], rb_ring[k]], [nk, nm, nk], col, out, glow)
		if rb > 0.0:
			_tri([ra_ring[m], rb_ring[m], rb_ring[k]], [nm, nm, nk], col, out, glow)
		_flat([a, ra_ring[k], ra_ring[m]], col * 0.9, -axis, glow)
		if rb > 0.0:
			_flat([b, rb_ring[k], rb_ring[m]], col * 1.08, axis, glow)


## A faceted stone (or fruit, bowl, loaf): a jittered icosahedron of radii r.
func _ball(centre: Vector3, r: Vector3, col: Color, jitter := 0.12, glow := false) -> void:
	var verts: Array[Vector3] = []
	for v: Vector3 in [Vector3(-1, PHI, 0), Vector3(1, PHI, 0), Vector3(-1, -PHI, 0), Vector3(1, -PHI, 0),
			Vector3(0, -1, PHI), Vector3(0, 1, PHI), Vector3(0, -1, -PHI), Vector3(0, 1, -PHI),
			Vector3(PHI, 0, -1), Vector3(PHI, 0, 1), Vector3(-PHI, 0, -1), Vector3(-PHI, 0, 1)]:
		verts.append(centre + v.normalized() * _rng.randf_range(1.0 - jitter, 1.0 + jitter) * r)
	for f: Array in ICO_FACES:
		var p := [verts[f[0]], verts[f[1]], verts[f[2]]]
		_flat(p, col, (p[0] + p[1] + p[2]) / 3.0 - centre, glow)


## A flat polygon facing up (water, straw, a cage floor).
func _disc(centre: Vector3, r: float, sides: int, col: Color) -> void:
	for k in sides:
		var a := TAU * k / sides
		var b := TAU * (k + 1) / sides
		_flat([centre, centre + Vector3(cos(a), 0, sin(a)) * r, centre + Vector3(cos(b), 0, sin(b)) * r], col, Vector3.UP)


## A frustum round the y axis at `at` from y0 (radius r0) to y1 (radius r1); side k gets cols[k % size].
## Facets start at `turn`; the facet between corners 0 and 1 faces +z when turn = PI/2 - PI/sides.
func _band(at: Vector3, r0: float, r1: float, y0: float, y1: float, sides: int, cols: Array, turn: float) -> Array:
	var ring0 := []
	var ring1 := []
	for k in sides:
		var d := Vector3(cos(turn + TAU * k / sides), 0.0, sin(turn + TAU * k / sides))
		ring0.append(at + d * r0 + Vector3(0, y0, 0))
		ring1.append(at + d * r1 + Vector3(0, y1, 0))
	for k in sides:
		var m := (k + 1) % sides
		var mid: Vector3 = (ring0[k] + ring0[m] + ring1[k] + ring1[m]) / 4.0
		var out := mid - Vector3(at.x, mid.y, at.z)
		if r1 < 0.01:
			_flat([ring0[k], ring0[m], ring1[k]], cols[k % cols.size()], out)
		else:
			_quad(ring0[k], ring0[m], ring1[m], ring1[k], cols[k % cols.size()], out)
	return [ring0, ring1]


func _stone_ring(centre: Vector3, radius: float, count: int, size: float) -> void:
	for k in count:
		var a := TAU * k / count + _rng.randf_range(-0.1, 0.1)
		var s := size * _rng.randf_range(0.85, 1.15)
		_ball(centre + Vector3(cos(a) * radius, s * 0.55, sin(a) * radius), Vector3(s, s * 0.8, s),
			STONE if k % 3 else STONE_DARK, 0.18)


## An upright post with a stone at its foot and a rope lashing near the top.
func _post(at: Vector3, height: float, r := 0.12) -> void:
	_log(at, at + Vector3(_rng.randf_range(-0.03, 0.03), height, _rng.randf_range(-0.03, 0.03)), r, WOOD, r * 0.9)
	_ball(at + Vector3(0, 0.06, 0), Vector3(r * 1.9, r * 1.1, r * 1.9), STONE, 0.2)
	_log(at + Vector3(0, height - 0.32, 0), at + Vector3(0, height - 0.2, 0), r * 1.3, ROPE)


# --- buildings -----------------------------------------------------------------------------------------------

## A market stall (front +z): four posts, a striped sloping hide roof with a ragged edge, a counter, a back
## wall and a sign on an arm to the right.
func _stall_frame() -> void:
	for p in [Vector3(-1.75, 0, -1.0), Vector3(1.75, 0, -1.0), Vector3(-1.75, 0, 0.7), Vector3(1.75, 0, 0.7)]:
		_post(p, 3.05)
	_log(Vector3(-2.0, 2.95, 0.7), Vector3(2.0, 2.95, 0.7), 0.1, WOOD_DARK)
	_log(Vector3(-2.0, 3.05, -1.0), Vector3(2.0, 3.05, -1.0), 0.1, WOOD_DARK)
	_roof(Vector3(-2.1, 3.3, -1.3), Vector3(2.1, 3.3, -1.3), Vector3(-2.1, 3.05, 0.98), Vector3(2.1, 3.05, 0.98),
		5, [HIDE, HIDE_DARK])
	_zigzag(Vector3(-2.1, 2.96, 1.0), Vector3(2.1, 2.96, 1.0), 0.38, 9, HIDE_DARK)
	_box(Vector3(0, 0.5, 0.5), Vector3(3.2, 1.0, 0.5), WOOD)
	_box(Vector3(0, 1.04, 0.5), Vector3(3.45, 0.1, 0.66), WOOD_LIGHT)
	_box(Vector3(0, 0.78, 0.77), Vector3(1.3, 0.4, 0.04), HIDE)
	_zigzag(Vector3(-0.65, 0.58, 0.8), Vector3(0.65, 0.58, 0.8), 0.18, 4, HIDE)
	_box(Vector3(0, 1.45, -1.0), Vector3(3.3, 2.0, 0.08), WOOD_DARK)
	_box(Vector3(0, 1.7, -0.85), Vector3(3.0, 0.07, 0.3), WOOD_LIGHT)
	_log(Vector3(1.75, 2.8, 0.7), Vector3(2.95, 2.8, 0.7), 0.07, WOOD_DARK)
	_log(Vector3(2.6, 2.8, 0.7), Vector3(2.6, 2.55, 0.7), 0.02, ROPE)
	_box(Vector3(2.6, 2.28, 0.7), Vector3(0.75, 0.55, 0.09), WOOD_LIGHT)


func _weapon_stall() -> void:
	_stall_frame()
	# Sign: two crossed spears.
	_box(Vector3(2.6, 2.28, 0.75), Vector3(0.6, 0.06, 0.02), WOOD_DARK, 0.0, 0.6)
	_box(Vector3(2.6, 2.28, 0.75), Vector3(0.6, 0.06, 0.02), WOOD_DARK, 0.0, -0.6)
	# Spear rack to the right of the counter.
	for x in [2.15, 2.75]:
		_log(Vector3(x, 0, 0.2), Vector3(x, 1.35, 0.2), 0.06, WOOD)
	_log(Vector3(2.05, 1.2, 0.2), Vector3(2.85, 1.2, 0.2), 0.05, WOOD_DARK)
	_log(Vector3(2.05, 0.25, 0.2), Vector3(2.85, 0.25, 0.2), 0.05, WOOD_DARK)
	for x in [2.3, 2.48, 2.66]:
		var top := Vector3(x + _rng.randf_range(-0.05, 0.05), 2.3, 0.08)
		_log(Vector3(x, 0.05, 0.3), top, 0.035, WOOD_LIGHT)
		_log(top, top + Vector3(0, 0.3, -0.01), 0.07, STONE_DARK, 0.0, 4)
	# A bow leaning on the left post, a quiver of arrows at its foot.
	var prev := Vector3.ZERO
	for k in 7:
		var a := lerpf(-1.1, 1.1, k / 6.0)
		var p := Vector3(-2.05 - cos(a) * 0.32, 1.1 + sin(a) * 0.95, 0.75)
		if k > 0:
			_log(prev, p, 0.035, WOOD_DARK)
		prev = p
	_log(Vector3(-1.87, 0.25, 0.75), Vector3(-1.87, 1.95, 0.75), 0.008, ROPE, -1.0, 3)
	_log(Vector3(-1.6, 0, 1.1), Vector3(-1.6, 0.6, 1.1), 0.15, HIDE_DARK, 0.17, 7)
	for k in 4:
		_log(Vector3(-1.6, 0.4, 1.1), Vector3(-1.6 + _rng.randf_range(-0.12, 0.12), 1.0, 1.1 + _rng.randf_range(-0.1, 0.1)), 0.015, WOOD_LIGHT, -1.0, 4)
	# On the counter: a club, two stone axes, knives; on the back wall a bow and spears.
	_log(Vector3(-1.2, 1.13, 0.5), Vector3(-0.4, 1.17, 0.45), 0.05, WOOD_DARK, 0.11)
	for x in [0.1, 0.7]:
		_log(Vector3(x, 1.12, 0.35), Vector3(x + 0.1, 1.12, 0.75), 0.03, WOOD_LIGHT, -1.0, 4)
		_box(Vector3(x + 0.1, 1.15, 0.7), Vector3(0.22, 0.08, 0.14), STONE_DARK, 0.3)
	_box(Vector3(1.2, 1.12, 0.5), Vector3(0.28, 0.04, 0.08), STONE, 0.4)
	_box(Vector3(1.4, 1.12, 0.6), Vector3(0.28, 0.04, 0.08), STONE, -0.3)
	_log(Vector3(-1.2, 1.9, -0.92), Vector3(1.2, 1.95, -0.92), 0.03, WOOD_LIGHT)
	_log(Vector3(-1.2, 2.25, -0.92), Vector3(1.2, 2.2, -0.92), 0.03, WOOD_LIGHT)
	_log(Vector3(1.2, 1.95, -0.92), Vector3(1.45, 1.95, -0.92), 0.06, STONE_DARK, 0.0, 4)
	_log(Vector3(1.2, 2.2, -0.92), Vector3(1.45, 2.2, -0.92), 0.06, STONE_DARK, 0.0, 4)


func _hunter_stall() -> void:
	_stall_frame()
	# Sign: a fruit.
	_ball(Vector3(2.6, 2.28, 0.77), Vector3(0.15, 0.15, 0.04), FRUIT[0], 0.05)
	# Baskets of fruit on the counter and in front of it.
	for at in [Vector3(-1.0, 1.09, 0.5), Vector3(-0.2, 1.09, 0.5), Vector3(0.6, 1.09, 0.5),
			Vector3(-0.8, 0.0, 1.1), Vector3(0.6, 0.0, 1.15)]:
		_basket(at)
	for x in [1.2, 1.45]:
		_log(Vector3(x, 1.09, 0.5), Vector3(x, 1.38, 0.5), 0.1, CLAY, 0.07, 7)
	# Snares on the back wall, a net hanging from the left side.
	for x in [-0.8, 0.0, 0.8]:
		var prev := Vector3.ZERO
		for k in 9:
			var a := TAU * k / 8.0
			var p := Vector3(x + cos(a) * 0.25, 2.1 + sin(a) * 0.32, -0.93)
			if k > 0:
				_log(prev, p, 0.02, ROPE, -1.0, 4)
			prev = p
	for k in 5:
		var z := lerpf(-0.9, 0.6, k / 4.0)
		_log(Vector3(-1.95, 2.8, z), Vector3(-1.95, 1.0, z + 0.05), 0.012, ROPE, -1.0, 3)
		_ball(Vector3(-1.95, 0.98, z + 0.05), Vector3.ONE * 0.06, STONE, 0.1)
	for k in 6:
		var y := lerpf(1.1, 2.7, k / 5.0)
		_log(Vector3(-1.95, y, -0.9), Vector3(-1.95, y, 0.65), 0.012, ROPE, -1.0, 3)


func _basket(at: Vector3) -> void:
	_log(at, at + Vector3(0, 0.16, 0), 0.22, STRAW, 0.27, 7)
	for k in 4:
		var a := TAU * k / 4.0 + _rng.randf()
		_ball(at + Vector3(cos(a) * 0.11, 0.2, sin(a) * 0.11), Vector3.ONE * 0.09, FRUIT[_rng.randi() % FRUIT.size()], 0.1)


## The cage rack (its cages open towards +x): two shelves of three wicker cages under a hide roof.
## Cage floors at y 0.2 and 1.03 and z as camp.gd CAGE_Z, centred on CAGE_X.
func _cage_rack() -> void:
	for p in [Vector3(4.68, 0, -3.32), Vector3(5.62, 0, -3.32), Vector3(4.68, 0, -0.9), Vector3(5.62, 0, -0.9)]:
		_post(p, 1.9, 0.08)
	for y in [0.16, 0.99]:
		_box(Vector3(5.15, y, -2.11), Vector3(1.05, 0.08, 2.55), WOOD_LIGHT)
	_roof(Vector3(4.55, 2.08, -3.5), Vector3(4.55, 2.08, -0.72), Vector3(5.8, 1.88, -3.5), Vector3(5.8, 1.88, -0.72),
		4, [HIDE, HIDE_DARK])
	_zigzag(Vector3(5.82, 1.8, -3.5), Vector3(5.82, 1.8, -0.72), 0.25, 7, HIDE_DARK)
	for y in [0.2, 1.03]:
		for z in [-1.4, -2.12, -2.84]:
			_cage(Vector3(5.12, y, z))


func _cage(base: Vector3) -> void:
	_log(base - Vector3(0, 0.03, 0), base + Vector3(0, 0.02, 0), 0.31, WOOD, -1.0, 8)
	_disc(base + Vector3(0, 0.025, 0), 0.25, 8, STRAW)
	var top := 0.5
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.3
		_log(base + d, base + d + Vector3(0, top, 0), 0.016, ROPE, -1.0, 4)
		var e := Vector3(cos(a + TAU / 8.0), 0, sin(a + TAU / 8.0)) * 0.3
		_log(base + d + Vector3(0, top, 0), base + e + Vector3(0, top, 0), 0.018, ROPE, -1.0, 4)
		_log(base + d + Vector3(0, top, 0), base + Vector3(0, top + 0.16, 0), 0.016, ROPE, -1.0, 4)
	_ball(base + Vector3(0, top + 0.17, 0), Vector3.ONE * 0.04, ROPE, 0.1)


## The camp fire: a ring of stones, crossed logs and flames under a tripod with a pot; a clay brazier with
## glowing coals and a grate to its east.
func _campfire() -> void:
	var c := Vector3(-0.08, 0, -0.38)
	_stone_ring(c, 0.78, 11, 0.22)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		_log(c + d * 0.6 + Vector3(0, 0.08, 0), c - d * 0.1 + Vector3(0, 0.3, 0), 0.07, WOOD_DARK)
	for k in 6:
		var a := TAU * k / 6.0
		_ball(c + Vector3(cos(a) * 0.3, 0.06, sin(a) * 0.3), Vector3(0.1, 0.06, 0.1), FIRE, 0.2, true)
	_log(c + Vector3(0, 0.08, 0), c + Vector3(0, 0.85, 0), 0.26, FIRE, 0.0, 5, true)
	_log(c + Vector3(0.12, 0.08, 0.1), c + Vector3(0.15, 0.6, 0.12), 0.16, FIRE, 0.0, 5, true)
	_log(c + Vector3(-0.14, 0.08, -0.08), c + Vector3(-0.18, 0.55, -0.1), 0.15, FIRE, 0.0, 5, true)
	_log(c + Vector3(0, 0.08, 0.02), c + Vector3(0, 0.6, 0.02), 0.16, FIRE_CORE, 0.0, 5, true)
	var apex := c + Vector3(0.05, 2.3, 0.05)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var foot := c + Vector3(cos(a) * 1.15, 0, sin(a) * 1.15)
		_log(foot, apex + (apex - foot).normalized() * 0.3, 0.06, WOOD)
	_ball(apex, Vector3.ONE * 0.11, ROPE, 0.1)
	_log(apex, apex - Vector3(0, 0.75, 0), 0.015, IRON, -1.0, 4)
	_log(c + Vector3(0, 1.0, 0), c + Vector3(0, 1.48, 0), 0.3, IRON, 0.38, 8)
	_disc(c + Vector3(0, 1.485, 0), 0.32, 8, Color(0.62, 0.48, 0.22))
	var b := Vector3(2.15, 0, -0.25)
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		_ball(b + Vector3(cos(a) * 0.38, 0.18, sin(a) * 0.38), Vector3(0.17, 0.2, 0.17), STONE, 0.15)
	_log(b + Vector3(0, 0.3, 0), b + Vector3(0, 0.72, 0), 0.32, CLAY, 0.56, 8)
	for k in 9:
		var a := TAU * k / 9.0
		var r := 0.15 if k % 2 else 0.33
		_ball(b + Vector3(cos(a) * r, 0.75, sin(a) * r), Vector3(0.1, 0.07, 0.1), FIRE if k % 3 else FIRE_CORE, 0.2, true)
	for k in 5:
		var x := b.x - 0.4 + k * 0.2
		_log(Vector3(x, 0.84, b.z - 0.45), Vector3(x, 0.84, b.z + 0.45), 0.02, IRON, -1.0, 4)


## The tavern (front +z): an open hall under a striped hide roof; a bar with a shelf of jars at the back
## right, a stone hearth at the back left (camp.gd TAVERN_HEARTH), a feast table between two benches in
## front (the inner bench top at 0.52, as camp.gd HELPER_SEAT), a mug sign on an arm.
func _tavern() -> void:
	for p in [Vector3(-2.4, 0, -1.5), Vector3(2.4, 0, -1.5), Vector3(-2.4, 0, 1.25), Vector3(2.4, 0, 1.25),
			Vector3(-0.2, 0, -1.5)]:
		_post(p, 3.1, 0.13)
	_log(Vector3(-2.65, 3.0, 1.25), Vector3(2.65, 3.0, 1.25), 0.11, WOOD_DARK)
	_log(Vector3(-2.65, 3.1, -1.5), Vector3(2.65, 3.1, -1.5), 0.11, WOOD_DARK)
	_roof(Vector3(-2.65, 3.4, -1.75), Vector3(2.65, 3.4, -1.75), Vector3(-2.65, 3.1, 1.5), Vector3(2.65, 3.1, 1.5),
		6, [HIDE, HIDE_RED, HIDE, HIDE_DARK])
	_zigzag(Vector3(-2.65, 3.0, 1.52), Vector3(2.65, 3.0, 1.52), 0.42, 11, HIDE_DARK)
	_zigzag(Vector3(2.67, 3.2, 1.5), Vector3(2.67, 3.3, -1.75), 0.3, 6, HIDE)
	_zigzag(Vector3(-2.67, 3.3, -1.75), Vector3(-2.67, 3.2, 1.5), 0.3, 6, HIDE)
	# Back wall of planks behind the bar, a shelf of jars on it.
	for k in 6:
		_box(Vector3(0.0 + k * 0.38 + 0.19, 1.15, -1.5), Vector3(0.36, 2.3, 0.08), WOOD if k % 2 else WOOD_DARK)
	_box(Vector3(1.15, 1.65, -1.36), Vector3(2.3, 0.07, 0.3), WOOD_LIGHT)
	for k in 4:
		var x := 0.35 + k * 0.55
		_log(Vector3(x, 1.69, -1.36), Vector3(x, 1.95 + _rng.randf_range(0.0, 0.12), -1.36), 0.11, CLAY, 0.07, 7)
	# The bar and a stool.
	_box(Vector3(0.95, 0.52, -0.7), Vector3(2.5, 1.04, 0.75), WOOD)
	_box(Vector3(0.95, 1.08, -0.7), Vector3(2.75, 0.1, 0.92), WOOD_LIGHT)
	_log(Vector3(1.8, 1.13, -0.65), Vector3(1.8, 1.42, -0.65), 0.1, CLAY, 0.07, 7)
	for x in [0.4, 0.8, 1.3]:
		_log(Vector3(x, 1.13, -0.55), Vector3(x, 1.25, -0.55), 0.05, CLAY, 0.06, 6)
	_log(Vector3(1.9, 0, 0.05), Vector3(1.9, 0.48, 0.05), 0.19, WOOD_LIGHT, 0.17, 7)
	# The hearth: two stone cheeks, a lintel and a chimney, a log and flames inside.
	_box(Vector3(-2.05, 0.4, -1.0), Vector3(0.38, 0.8, 0.55), STONE)
	_box(Vector3(-1.2, 0.4, -1.0), Vector3(0.38, 0.8, 0.55), STONE_DARK)
	_box(Vector3(-1.62, 0.4, -1.2), Vector3(0.6, 0.8, 0.15), DARK)
	_box(Vector3(-1.62, 0.98, -1.0), Vector3(1.35, 0.36, 0.6), STONE)
	_box(Vector3(-1.62, 1.6, -1.1), Vector3(0.75, 0.9, 0.4), STONE_DARK)
	_box(Vector3(-1.62, 0.04, -0.85), Vector3(1.3, 0.08, 0.5), STONE)
	_log(Vector3(-1.9, 0.12, -0.95), Vector3(-1.35, 0.14, -0.95), 0.07, WOOD_DARK)
	_log(Vector3(-1.63, 0.12, -0.92), Vector3(-1.63, 0.6, -0.92), 0.16, FIRE, 0.0, 5, true)
	_log(Vector3(-1.5, 0.12, -0.9), Vector3(-1.5, 0.45, -0.9), 0.1, FIRE_CORE, 0.0, 5, true)
	_log(Vector3(-2.2, 0, -0.35), Vector3(-2.2, 0.45, -0.35), 0.13, CLAY, 0.08, 7)
	# The feast table and its benches, food on it.
	_box(Vector3(-0.18, 0.85, 1.11), Vector3(2.9, 0.1, 0.85), WOOD_LIGHT)
	for x in [-1.3, 0.95]:
		_box(Vector3(x, 0.4, 1.11), Vector3(0.14, 0.8, 0.65), WOOD)
	for z in [0.37, 1.85]:
		_box(Vector3(-0.18, 0.47, z), Vector3(3.1, 0.1, 0.32), WOOD_LIGHT)
		for x in [-1.45, 0.25, 1.1]:
			_log(Vector3(x, 0, z), Vector3(x, 0.42, z), 0.11, WOOD, 0.1)
	for k in 4:
		var at := Vector3(-1.2 + k * 0.7, 0.9, 1.1 + _rng.randf_range(-0.15, 0.15))
		_ball(at + Vector3(0, 0.03, 0), Vector3(0.18, 0.06, 0.18), CLAY, 0.05)
		_ball(at + Vector3(0, 0.1, 0), Vector3(0.11, 0.07, 0.11), FRUIT[k % FRUIT.size()] if k % 2 else STRAW, 0.15)
	# The mug sign on an arm out of the front-right post.
	_log(Vector3(2.4, 2.85, 1.25), Vector3(3.05, 2.85, 1.25), 0.07, WOOD_DARK)
	_log(Vector3(2.78, 2.85, 1.25), Vector3(2.78, 2.62, 1.25), 0.02, ROPE)
	_box(Vector3(2.78, 2.35, 1.25), Vector3(0.62, 0.52, 0.08), WOOD_LIGHT)
	_box(Vector3(2.74, 2.35, 1.3), Vector3(0.2, 0.28, 0.03), HIDE)
	_box(Vector3(2.89, 2.37, 1.3), Vector3(0.06, 0.18, 0.03), HIDE)


## A ridge tent (A-frame): two striped hide sides from the ridge to the ground, a dark door in the front
## gable, crossed poles at both ends.
func _aframe_hide_tent() -> void:
	var top := 2.4
	var half := 1.95
	var z0 := -2.05
	var z1 := 2.05
	for side in [-1.0, 1.0]:
		_roof(Vector3(0, top, z0), Vector3(0, top, z1), Vector3(side * half, 0.02, z0), Vector3(side * half, 0.02, z1),
			4, [HIDE, HIDE_DARK] if side < 0 else [HIDE_DARK, HIDE], 0.07)
	_sheet([Vector3(-half, 0.02, z0 + 0.05), Vector3(half, 0.02, z0 + 0.05), Vector3(0, top - 0.05, z0 + 0.05)], HIDE)
	_sheet([Vector3(-half * 0.95, 0.02, z1 - 0.05), Vector3(-0.1, 0.02, z1 - 0.05), Vector3(0, top - 0.1, z1 - 0.05)], HIDE)
	_sheet([Vector3(half * 0.95, 0.02, z1 - 0.05), Vector3(0.1, 0.02, z1 - 0.05), Vector3(0, top - 0.1, z1 - 0.05)], HIDE)
	_sheet([Vector3(-0.75, 0.02, z1 - 0.15), Vector3(0.75, 0.02, z1 - 0.15), Vector3(0, top * 0.75, z1 - 0.15)], DARK)
	_sheet([Vector3(-0.1, 0.02, z1 - 0.04), Vector3(-0.75, 0.02, z1 + 0.25), Vector3(0, top * 0.75, z1 - 0.04)], HIDE_DARK)
	_log(Vector3(0, top + 0.05, z0 - 0.15), Vector3(0, top + 0.05, z1 + 0.15), 0.07, WOOD_DARK)
	for z in [z0 - 0.08, z1 + 0.08]:
		for side in [-1.0, 1.0]:
			_log(Vector3(side * (half + 0.05), 0, z), Vector3(-side * 0.3, top + 0.4, z), 0.07, WOOD)
	for z in [z0 + 0.6, 0.0, z1 - 0.6]:
		for side in [-1.0, 1.0]:
			_ball(Vector3(side * (half + 0.1), 0.06, z), Vector3(0.13, 0.08, 0.13), STONE, 0.2)


## A big round tent (yurt): a striped wall, a rope band, a cone roof with poles out of its top, a door
## on the +z facet.
func _large_hide_tent() -> void:
	var sides := 10
	var turn := PI / 2.0 - PI / sides
	var wall := 1.45
	var rings: Array = _band(Vector3.ZERO, 3.45, 3.35, 0.0, wall, sides, [HIDE, HIDE_DARK], turn)
	_band(Vector3.ZERO, 3.4, 3.4, wall - 0.15, wall - 0.05, sides, [ROPE], turn)
	_band(Vector3.ZERO, 3.8, 0.35, wall - 0.1, 3.4, sides, [HIDE_DARK, HIDE, HIDE_RED, HIDE], turn)
	_band(Vector3.ZERO, 0.35, 0.0, 3.4, 3.5, sides, [WOOD_DARK], turn)
	_zigzag_ring(Vector3.ZERO, 3.8, wall - 0.12, sides * 2, 0.22, HIDE)
	for k in 5:
		var a := TAU * k / 5.0
		var d := Vector3(cos(a), 0, sin(a))
		_log(d * 0.15 + Vector3(0, 3.1, 0), d * 0.4 + Vector3(0, 3.75, 0), 0.05, WOOD)
	_door(rings[0][0], rings[0][1], rings[1][0], rings[1][1], 0.32, 0.68, 0.9)


## A door on a wall facet (bottom corners b0, b1, top corners t0, t1): a dark opening from u0 to u1 along
## the facet, `height` of the way up, with a rolled-up flap above it.
func _door(b0: Vector3, b1: Vector3, t0: Vector3, t1: Vector3, u0: float, u1: float, height: float) -> void:
	var out := ((b1 - b0).cross(t0 - b0)).normalized()
	if out.dot((b0 + b1) * Vector3(1, 0, 1)) < 0.0:
		out = -out
	var p0 := b0.lerp(b1, u0) + out * 0.03
	var p1 := b0.lerp(b1, u1) + out * 0.03
	var q0 := p0.lerp(t0.lerp(t1, u0) + out * 0.03, height)
	var q1 := p1.lerp(t0.lerp(t1, u1) + out * 0.03, height)
	_quad(p0, p1, q1, q0, DARK, out)
	_log(q0 + out * 0.08, q1 + out * 0.08, 0.1, HIDE_DARK)


func _zigzag_ring(at: Vector3, r: float, y: float, teeth: int, depth: float, col: Color) -> void:
	for k in teeth:
		var a := TAU * k / teeth
		var b := TAU * (k + 1) / teeth
		_zigzag(at + Vector3(cos(a) * r, y, sin(a) * r), at + Vector3(cos(b) * r, y, sin(b) * r), depth, 1, col)


## A cone tent (teepee): striped facets in two bands, a dark door on the +z facet, poles out of the top.
func _round_hide_tent() -> void:
	var sides := 9
	var turn := PI / 2.0 - PI / sides
	var low: Array = _band(Vector3.ZERO, 1.88, 1.34, 0.0, 0.7, sides, [HIDE_RED, HIDE_DARK], turn)
	_band(Vector3.ZERO, 1.34, 0.0, 0.7, 2.45, sides, [HIDE, HIDE_DARK], turn)
	_band(Vector3.ZERO, 1.44, 1.37, 0.6, 0.69, sides, [ROPE], turn)
	_door(low[0][0], low[0][1], Vector3(0, 2.45, 0), Vector3(0, 2.45, 0), 0.3, 0.7, 0.55)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		_log(d * 0.05 + Vector3(0, 2.0, 0), d * 0.35 + Vector3(0, 2.7, 0), 0.04, WOOD)
	for k in 6:
		var a := TAU * k / 6.0 + 0.2
		_ball(Vector3(cos(a) * 1.95, 0.05, sin(a) * 1.95), Vector3(0.12, 0.07, 0.12), STONE, 0.2)


## The boar pen: a post-and-rail fence (front rail top at camp.gd RAIL_TOP, z RAIL_Z) with a braced gate,
## a lean-to shelter on straw in the back-left corner, a trough on the left, a stone water basin back right.
func _boar_pen() -> void:
	var x0 := -4.55
	var x1 := 4.55
	var z0 := -3.45
	var z1 := 3.38
	var fence := [[Vector3(x0, 0, z1), Vector3(-1.0, 0, z1)], [Vector3(0.95, 0, z1), Vector3(x1, 0, z1)],
		[Vector3(x1, 0, z1), Vector3(x1, 0, z0)], [Vector3(x1, 0, z0), Vector3(x0, 0, z0)], [Vector3(x0, 0, z0), Vector3(x0, 0, z1)]]
	for run: Array in fence:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var posts := maxi(1, roundi(a.distance_to(b) / 2.3))
		for k in posts + 1:
			var p := a.lerp(b, float(k) / posts)
			_post(p, 1.25, 0.13)
			_log(p + Vector3(0, 0.88, 0), p + Vector3(0, 0.98, 0), 0.16, ROPE)
		for y in [0.45, 0.93]:
			_log(a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.065, WOOD_LIGHT if y > 0.5 else WOOD)
	# The gate: three slats and a brace between the gate posts.
	for y in [0.3, 0.65, 0.95]:
		_box(Vector3(-0.02, y, z1), Vector3(1.9, 0.12, 0.06), WOOD_LIGHT)
	_box(Vector3(-0.02, 0.62, z1 + 0.05), Vector3(2.1, 0.1, 0.05), WOOD, 0.0, 0.33)
	# The shelter.
	for p in [Vector3(-3.35, 0, -3.2), Vector3(-1.2, 0, -3.2), Vector3(-3.35, 0, -1.55), Vector3(-1.2, 0, -1.55)]:
		_post(p, 1.45, 0.09)
	_box(Vector3(-2.28, 0.6, -3.22), Vector3(2.15, 1.2, 0.08), WOOD_DARK)
	_box(Vector3(-3.37, 0.6, -2.38), Vector3(0.08, 1.2, 1.65), WOOD)
	_roof(Vector3(-3.55, 1.75, -3.4), Vector3(-1.0, 1.75, -3.4), Vector3(-3.55, 1.5, -1.35), Vector3(-1.0, 1.5, -1.35),
		3, [HIDE, HIDE_DARK])
	_zigzag(Vector3(-3.55, 1.42, -1.33), Vector3(-1.0, 1.42, -1.33), 0.25, 6, HIDE_DARK)
	_box(Vector3(-2.28, 0.03, -2.38), Vector3(1.9, 0.06, 1.5), STRAW)
	# The trough and the water basin.
	_box(Vector3(-3.85, 0.05, 0.35), Vector3(0.62, 0.1, 1.5), WOOD_DARK)
	for s in [-1.0, 1.0]:
		_box(Vector3(-3.85 + s * 0.27, 0.2, 0.35), Vector3(0.08, 0.3, 1.5), WOOD)
		_box(Vector3(-3.85, 0.2, 0.35 + s * 0.71), Vector3(0.62, 0.3, 0.08), WOOD)
	_box(Vector3(-3.85, 0.18, 0.35), Vector3(0.46, 0.06, 1.34), STRAW)
	_stone_ring(Vector3(2.4, 0, -2.35), 0.55, 9, 0.17)
	_disc(Vector3(2.4, 0.13, -2.35), 0.5, 9, WATER)
	for p in [Vector3(-4.0, 0, 2.6), Vector3(3.9, 0, 2.8), Vector3(3.8, 0, -0.5), Vector3(-0.5, 0, -3.0)]:
		_ball(p + Vector3(0, 0.05, 0), Vector3(0.18, 0.1, 0.16), STONE_DARK, 0.2)


## The well: a ring of stone blocks round dark water, two posts with a gable hide roof, a winch with a
## crank and a bucket on its rope.
func _tribal_well() -> void:
	var blocks := 10
	for k in blocks:
		var a := TAU * (k + 0.5) / blocks
		_box(Vector3(cos(a) * 0.78, 0.3, sin(a) * 0.78), Vector3(0.28, 0.6, 0.5), STONE if k % 2 else STONE_DARK, -a)
		_box(Vector3(cos(a) * 0.78, 0.64, sin(a) * 0.78), Vector3(0.34, 0.1, 0.52), STONE, -a + 0.05)
	_disc(Vector3(0, 0.3, 0), 0.68, 10, DARK)
	_disc(Vector3(0, 0.32, 0), 0.6, 10, WATER * 0.75)
	for x in [-1.0, 1.0]:
		_post(Vector3(x, 0, 0), 2.15, 0.1)
	_log(Vector3(0, 2.3, -0.05), Vector3(0, 2.3, 0.05), 0.01, WOOD)
	for side in [-1.0, 1.0]:
		_roof(Vector3(-1.25, 2.3, 0), Vector3(1.25, 2.3, 0), Vector3(-1.25, 1.88, side * 0.75), Vector3(1.25, 1.88, side * 0.75),
			3, [HIDE, HIDE_DARK] if side < 0 else [HIDE_DARK, HIDE], 0.07)
		_zigzag(Vector3(-1.25, 1.82, side * 0.77), Vector3(1.25, 1.82, side * 0.77), 0.18, 6, HIDE_DARK)
	_log(Vector3(-1.32, 2.33, 0), Vector3(1.32, 2.33, 0), 0.07, WOOD_DARK)
	_log(Vector3(-1.15, 1.3, 0), Vector3(1.22, 1.3, 0), 0.07, WOOD_LIGHT)
	_log(Vector3(-0.2, 1.3, 0), Vector3(0.22, 1.3, 0), 0.11, ROPE, -1.0, 7)
	_box(Vector3(1.24, 1.15, 0), Vector3(0.07, 0.36, 0.1), WOOD)
	_log(Vector3(1.22, 0.98, 0), Vector3(1.42, 0.98, 0), 0.04, WOOD_LIGHT)
	_log(Vector3(0.18, 1.24, 0), Vector3(0.18, 0.9, 0), 0.015, ROPE, -1.0, 4)
	_log(Vector3(0.18, 0.62, 0), Vector3(0.18, 0.88, 0), 0.14, WOOD, 0.17, 7)
	_log(Vector3(0.18, 0.72, 0), Vector3(0.18, 0.77, 0), 0.165, ROPE, -1.0, 7)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		_ball(Vector3(cos(a) * 1.25, 0.05, sin(a) * 1.25), Vector3(0.14, 0.08, 0.13), STONE, 0.2)


## The Start hunt signpost: a post with three arrow boards, the top and bottom pointing +x, the middle -x.
func _direction_sign() -> void:
	_log(Vector3(0, 0, 0), Vector3(0.03, 2.65, 0), 0.1, WOOD_DARK, 0.08)
	_ball(Vector3(0, 0.07, 0), Vector3(0.3, 0.13, 0.26), STONE, 0.2)
	_log(Vector3(0, 0.12, 0), Vector3(0, 0.26, 0), 0.13, ROPE)
	var arrows := [[2.25, 1.0, WOOD_LIGHT], [1.78, -1.0, HIDE_DARK], [1.3, 1.0, WOOD_LIGHT]]
	for arrow: Array in arrows:
		var y: float = arrow[0]
		var dir: float = arrow[1]
		_box(Vector3(dir * 0.45, y, 0.13), Vector3(1.05, 0.32, 0.08), arrow[2], 0.0, _rng.randf_range(-0.05, 0.05))
		var tip := [Vector3(dir * 0.97, y + 0.26, 0.09), Vector3(dir * 0.97, y - 0.26, 0.09), Vector3(dir * 1.3, y, 0.09)]
		_hex([tip[0], tip[1], tip[2], tip[2], tip[0] + Vector3(0, 0, 0.08), tip[1] + Vector3(0, 0, 0.08),
			tip[2] + Vector3(0, 0, 0.08), tip[2] + Vector3(0, 0, 0.08)], arrow[2])
		_log(Vector3(-0.12, y, 0.17), Vector3(0.12, y, 0.17), 0.04, ROPE, -1.0, 4)


# --- output --------------------------------------------------------------------------------------------------

func _save(name: String) -> void:
	_tool.index()
	var mesh := _tool.commit()
	mesh.surface_set_material(0, _body_material)
	var tris := mesh.surface_get_array_index_len(0) / 3
	if _glowing:
		_glow.index()
		_glow.commit(mesh)
		mesh.surface_set_material(1, _glow_material)
		tris += mesh.surface_get_array_index_len(1) / 3
	var root := Node3D.new()
	root.name = name.to_pascal_case()
	var node := MeshInstance3D.new()
	node.name = "Mesh"
	node.mesh = mesh
	root.add_child(node)
	node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene, OUT + name + ".scn", ResourceSaver.FLAG_COMPRESS)
	print("%s: %d triangles, %s" % [name, tris, mesh.get_aabb()])
	root.free()
