extends RefCounted

## Shared finishing pass for the PEAK-style bakes (owner, 2026-11-02: the models looked assembled from
## separate chunks). Smooths normals across edges flatter than `angle` degrees, so six-sided logs, lumps and
## bevelled boxes shade round while real corners (caps, box edges) stay crisp, and sets the soft
## wrap-around lighting that keeps the shadow side from turning into hard dark facets.
## Use: const PeakSmooth := preload("res://tools/peak_smooth.gd"); mesh = PeakSmooth.smooth(mesh)

const ANGLE := 65.0


## A copy of `mesh` with every surface's normals smoothed (vertex colours, materials and positions kept).
static func smooth(mesh: ArrayMesh, angle := ANGLE) -> ArrayMesh:
	var out := ArrayMesh.new()
	var limit := cos(deg_to_rad(angle))
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			index = PackedInt32Array(range(verts.size()))
		# Face normals (area weighted) and, per snapped position, the faces touching it.
		var faces: Array[Vector3] = []
		var by_point := {}
		for f in range(0, index.size(), 3):
			var a := verts[index[f]]
			var n := (verts[index[f + 2]] - a).cross(verts[index[f + 1]] - a)
			if not normals.is_empty():  # trust the baked side when the winding disagrees
				var was := normals[index[f]] + normals[index[f + 1]] + normals[index[f + 2]]
				if n.dot(was) < 0.0:
					n = -n
			faces.append(n)
			for m in 3:
				var key := _key(verts[index[f + m]])
				if not by_point.has(key):
					by_point[key] = []
				by_point[key].append(f / 3)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in range(0, index.size(), 3):
			var own := faces[f / 3].normalized()
			for m in 3:
				var v := index[f + m]
				var sum := Vector3.ZERO
				for other: int in by_point[_key(verts[v])]:
					if faces[other].normalized().dot(own) >= limit:
						sum += faces[other]
				if not colours.is_empty():
					tool.set_color(colours[v])
				tool.set_normal(sum.normalized() if sum.length_squared() > 0.0 else own)
				tool.add_vertex(verts[v])
		tool.index()
		tool.commit(out)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out


## Soft lighting for a lit PEAK material: light wraps past the terminator instead of a hard dark side.
static func soften(mat: BaseMaterial3D) -> BaseMaterial3D:
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return mat


static func _key(p: Vector3) -> Vector3i:
	return Vector3i((p * 2000.0).round())
