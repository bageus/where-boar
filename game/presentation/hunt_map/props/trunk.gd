extends RefCounted

## Where a tree model's trunk stands. Many models (curved palms, spruces) keep the trunk off the origin,
## so a collision shape at the origin lets the hunter and boars walk through the real trunk.


## Centre and half-width (model units) of the lowest tenth of the mesh, across all its surfaces.
## Returns Vector3(x, half_width, z).
static func base(mesh: Mesh) -> Vector3:
	var aabb := mesh.get_aabb()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in mesh.get_surface_count():
		for v: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if v.y < aabb.position.y + aabb.size.y * 0.1:
				lo = lo.min(Vector2(v.x, v.z))
				hi = hi.max(Vector2(v.x, v.z))
	if lo.x == INF:
		return Vector3.ZERO
	var c := (lo + hi) * 0.5
	return Vector3(c.x, maxf(hi.x - lo.x, hi.y - lo.y) * 0.5, c.y)
