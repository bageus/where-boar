extends Node3D

## The owner's rigged net (assets/models/boar_net_rigged.glb, a 9 x 7 grid of bones N_<x>_<z>), owner 2026-10-30:
## hangs from the hand, opens flat in flight and drapes over a caught boar's shape, riding its fall.

const COLUMNS := 9
const ROWS := 7
const OPEN_SECONDS := 0.4
const CLEARANCE := 0.06  # net above the fur, boar model units: the mesh sags between bones
const CELLS := 24  # resolution of the boar's top-down silhouette along its length
const CREASE_CELLS := 3  # dips narrower than this many cells (between the hams, behind the head) are bridged

## Top-down silhouettes of boar meshes, by mesh: built once from the vertices.
static var _silhouettes := {}

var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _bones := PackedInt32Array()
## While draped: the boar skeleton, and per net bone the boar bone it rides on and the offset from it.
var _boar: Skeleton3D
var _anchors := PackedInt32Array()
var _offsets := PackedVector3Array()


func _ready() -> void:
	_skeleton = find_children("*", "Skeleton3D", true, false)[0]
	_player = find_children("*", "AnimationPlayer", true, false)[0]
	for z in ROWS:
		for x in COLUMNS:
			_bones.append(_skeleton.find_bone("N_%d_%d" % [x, z]))
	hang()


## Held by its top edge, hanging down.
func hang() -> void:
	_player.play("Hold_Two_Hands_demo")
	_player.seek(_player.current_animation_length, true)


## Thrown: spreads from the hanging bunch to a flat sheet.
func open() -> void:
	_player.play("Settle_Flat_demo", -1, _player.get_animation("Settle_Flat_demo").length / OPEN_SECONDS)


## Caught a boar: lies over its back and hangs down its sides to the ground, following its bones from now on.
func wrap(boar_model: Node3D) -> void:
	var skeletons := boar_model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_boar = skeletons[0]
	var mesh: MeshInstance3D = _boar.find_children("*", "MeshInstance3D", false, false)[0]
	var sil := _silhouette(mesh)
	_player.active = false
	var points := _drape(sil)
	var movable := PackedInt32Array()
	for b in _boar.get_bone_count():
		if not _boar.get_bone_name(b).begins_with("leg_") and not _boar.get_bone_name(b).begins_with("shin_"):
			movable.append(b)
	# Points on the ground stay with the root bone, so the folding front legs do not lift them.
	var root := _boar.get_parentless_bones()[0]
	for p in points:
		var anchor := root
		if p.y > sil.ground + 0.01:
			var best := INF
			for b in movable:
				var d := _boar.get_bone_global_rest(b).origin.distance_squared_to(p)
				if d < best:
					best = d
					anchor = b
		_anchors.append(anchor)
		_offsets.append(_boar.get_bone_global_rest(anchor).affine_inverse() * p)
	_follow()


func _process(_delta: float) -> void:
	if _boar != null:
		_follow()


func _follow() -> void:
	if not is_instance_valid(_boar):
		_boar = null
		return
	var to_net := _skeleton.global_transform.affine_inverse() * _boar.global_transform
	for i in _bones.size():
		var p := to_net * (_boar.get_bone_global_pose(_anchors[i]) * _offsets[i])
		_skeleton.set_bone_global_pose(_bones[i], Transform3D(Basis(), p))


## Net bone positions in boar skeleton space: a centre line along the back from snout to tail, then each row
## across the back and down both sides to the ground. The net stretches to the boar's size.
func _drape(sil: Dictionary) -> PackedVector3Array:
	var size: Vector3 = sil.size
	var along := size.z * 0.98 / (ROWS - 1)
	var across := (size.x + 1.6 * size.y) / (COLUMNS - 1)
	var centre := Vector3(sil.origin.x + size.x / 2.0, 0.0, sil.origin.y + size.z / 2.0)
	centre.y = _top(sil, centre.x, centre.z)
	var spine := _walk(sil, centre, Vector3.BACK, along, ROWS / 2)
	spine.reverse()
	spine.append(centre)
	spine.append_array(_walk(sil, centre, Vector3.FORWARD, along, ROWS / 2))
	var points := PackedVector3Array()
	points.resize(ROWS * COLUMNS)
	var half := COLUMNS / 2
	for z in ROWS:
		var left := _walk(sil, spine[z], Vector3.LEFT, across, half)
		var right := _walk(sil, spine[z], Vector3.RIGHT, across, half)
		points[z * COLUMNS + half] = spine[z]
		for k in half:
			points[z * COLUMNS + half - 1 - k] = left[k]
			points[z * COLUMNS + half + 1 + k] = right[k]
	return points


## Steps of a cloth strip from start along dir: lies on the body where it reaches it, else hangs down to the ground.
func _walk(sil: Dictionary, start: Vector3, dir: Vector3, step: float, count: int) -> PackedVector3Array:
	var points := PackedVector3Array()
	var p := start
	for k in count:
		var ahead := p + dir * step
		var top := _top(sil, ahead.x, ahead.z)
		if top > sil.ground or p.y <= sil.ground:
			p = Vector3(ahead.x, top, ahead.z)
		else:
			p = Vector3(p.x, maxf(sil.ground, p.y - step), p.z) + dir * step * 0.2
		points.append(p)
	return points


## Height the net rests at above (x, z): the boar's back plus clearance, or the ground beside it.
func _top(sil: Dictionary, x: float, z: float) -> float:
	var ix := floori((x - sil.origin.x) / sil.cell)
	var iz := floori((z - sil.origin.y) / sil.cell)
	if ix < 0 or iz < 0 or ix >= sil.nx or iz >= sil.nz:
		return sil.ground
	var height: float = sil.heights[iz * sil.nx + ix]
	return height + CLEARANCE if height > sil.ground + 0.01 else sil.ground


## The highest vertex in each cell of a top-down grid over the mesh, in its skeleton's space (rest pose).
static func _silhouette(mesh: MeshInstance3D) -> Dictionary:
	if _silhouettes.has(mesh.mesh):
		return _silhouettes[mesh.mesh]
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		vertices[i] = mesh.transform * vertices[i]
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		bounds = bounds.expand(v)
	var cell := bounds.size.z / CELLS
	var nx := ceili(bounds.size.x / cell) + 1
	var nz := CELLS + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	heights.fill(-INF)
	# Every cell centre under a triangle takes the triangle's height there: low-poly backs have few vertices.
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var b := vertices[indices[t + 1]]
		var c := vertices[indices[t + 2]]
		var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		if absf(area) < 1e-9:
			continue
		var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		for iz in range(floori((low.y - bounds.position.z) / cell), floori((high.y - bounds.position.z) / cell) + 1):
			for ix in range(floori((low.x - bounds.position.x) / cell), floori((high.x - bounds.position.x) / cell) + 1):
				var x := bounds.position.x + (ix + 0.5) * cell
				var z := bounds.position.z + (iz + 0.5) * cell
				var u := ((b.x - x) * (c.z - z) - (c.x - x) * (b.z - z)) / area
				var v := ((c.x - x) * (a.z - z) - (a.x - x) * (c.z - z)) / area
				if u < 0.0 or v < 0.0 or u + v > 1.0 or ix < 0 or iz < 0 or ix >= nx or iz >= nz:
					continue
				var i := iz * nx + ix
				heights[i] = maxf(heights[i], a.y * u + b.y * v + c.y * (1.0 - u - v))
	heights = _close(heights, nx, nz, bounds.position.y)
	var sil := {"origin": Vector2(bounds.position.x, bounds.position.z), "cell": cell, "nx": nx, "nz": nz,
		"heights": heights, "ground": bounds.position.y, "size": bounds.size}
	_silhouettes[mesh.mesh] = sil
	return sil


## Morphological closing (max then min over a square of CREASE_CELLS): fills narrow dips, keeps the outline.
static func _close(heights: PackedFloat32Array, nx: int, nz: int, ground: float) -> PackedFloat32Array:
	var filled := heights.duplicate()
	for i in filled.size():
		filled[i] = maxf(filled[i], ground)
	return _filter(_filter(filled, nx, nz, true), nx, nz, false)


static func _filter(heights: PackedFloat32Array, nx: int, nz: int, take_max: bool) -> PackedFloat32Array:
	var out := heights.duplicate()
	for iz in nz:
		for ix in nx:
			var best := heights[iz * nx + ix]
			for dz in range(-CREASE_CELLS, CREASE_CELLS + 1):
				for dx in range(-CREASE_CELLS, CREASE_CELLS + 1):
					var x := clampi(ix + dx, 0, nx - 1)
					var z := clampi(iz + dz, 0, nz - 1)
					best = maxf(best, heights[z * nx + x]) if take_max else minf(best, heights[z * nx + x])
			out[iz * nx + ix] = best
	return out
