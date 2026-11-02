extends RefCounted

## Reads a boar's herd mates, nearby bait nodes, tall grass and sight lines into plain values for the domain.

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarSenses = preload("res://game/features/boar/domain/boar_senses.gd")


## XZ positions of the boar's living herd mates; only fleeing, panicking or charging ones when scared_only,
## only those within within metres when given.
static func herd_positions(body: Node3D, scared_only: bool, within := INF) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for mate in body.herd:
		if mate == body or not is_instance_valid(mate):
			continue
		if body.global_position.distance_to(mate.global_position) > within:
			continue
		# A boar hiding in tall grass is quiet: it does not scare its mates.
		if scared_only and (mate.boar.state not in [Boar.State.FLEE, Boar.State.PANIC, Boar.State.CHARGE] \
				or mate.is_hiding()):
			continue
		spots.append(Vector2(mate.global_position.x, mate.global_position.z))
	return spots


## Heading back to the centre of the herd mates in reach for a stray, or ZERO.
## Split groups that come within reach of each other merge back (playtest 2026-10-27).
static func herd_cohesion(body: Node3D, pos: Vector2, spread: float, reach: float) -> Vector2:
	var mates := herd_positions(body, false, reach)
	if mates.is_empty():
		return Vector2.ZERO
	var centre := Vector2.ZERO
	for mate in mates:
		centre += mate
	return BoarSenses.cohesion_heading(pos, centre / mates.size(), spread)


## Bait nodes still on the ground as Vector3(x, z, pull radius).
static func bait_spots(baits: Array) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for bait in baits:
		if is_instance_valid(bait):
			spots.append(Vector3(bait.global_position.x, bait.global_position.z, bait.attract_radius))
	return spots


## XZ position of the nearest living herd mate within reach, or Vector2.INF if there is none.
static func nearest_mate(body: Node3D, pos: Vector2, reach: float) -> Vector2:
	var best := Vector2.INF
	for mate in herd_positions(body, false, reach):
		if pos.distance_to(mate) < pos.distance_to(best):
			best = mate
	return best


## Nearest tall-grass patch within reach of the boar as Vector3(x, z, radius); radius 0 when there is none.
## Patches are cylinder shapes of a cover body in the "tall_grass" group (hunt map terrain).
static func tall_grass_near(body: Node3D, reach: float, cover_layer: int) -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = reach
	query.transform = Transform3D(Basis(), body.global_position)
	query.collision_mask = cover_layer
	var pos := Vector2(body.global_position.x, body.global_position.z)
	var best := Vector3.ZERO
	var best_gap := INF
	for hit in body.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var cover: CollisionObject3D = hit.collider
		if not cover.is_in_group("tall_grass"):
			continue
		var owner_node = cover.shape_owner_get_owner(cover.shape_find_owner(hit.shape))
		if not owner_node is CollisionShape3D or not owner_node.shape is CylinderShape3D:
			continue
		var centre := Vector2(owner_node.global_position.x, owner_node.global_position.z)
		var r: float = owner_node.shape.radius
		var gap := pos.distance_to(centre) - r
		if gap < best_gap:
			best_gap = gap
			best = Vector3(centre.x, centre.y, r)
	return best


## Whether the boar sees the hunter: not when he is inside cover, nor when cover or a wall is in between.
## The point check matters when the boar stands in the same patch: the ray would start inside it and miss it.
static func sight_clear(body: CharacterBody3D, hunter: CollisionObject3D, eye_rise: float, hunter_rise: float,
		cover_layer: int) -> bool:
	var space := body.get_world_3d().direct_space_state
	var point := PhysicsPointQueryParameters3D.new()
	point.position = hunter.global_position + Vector3.UP * hunter_rise
	point.collision_mask = cover_layer
	if not space.intersect_point(point, 1).is_empty():
		return false
	var query := PhysicsRayQueryParameters3D.create(body.global_position + Vector3.UP * eye_rise,
			hunter.global_position + Vector3.UP * hunter_rise, body.collision_mask | cover_layer, [body.get_rid(), hunter.get_rid()])
	return space.intersect_ray(query).is_empty()


## Boars whose hitbox (on hitbox_layer) is within radius of point.
static func hitboxes_near(world: World3D, point: Vector3, radius: float, hitbox_layer: int) -> Array[Node]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.transform = Transform3D(Basis(), point)
	query.collision_mask = hitbox_layer  # hitboxes only; the terrain alone would fill the results
	var boars: Array[Node] = []
	for hit in world.direct_space_state.intersect_shape(query):
		boars.append(hit.collider.get_parent())
	return boars


## A snared boar is freed by a free boar running close by (owner, 2026-10-30).
static func rescued(body: Node3D, radius: float, min_speed: float) -> bool:
	for other in body.get_parent().get_children():
		if other != body and other.get_script() == body.get_script() and other.boar.is_free() \
				and Vector2(other.velocity.x, other.velocity.z).length() >= min_speed \
				and other.global_position.distance_to(body.global_position) <= radius:
			return true
	return false


## Other boars that see body (in their view and perception radius).
static func witnesses(body: Node3D) -> Array[Node]:
	var pos := Vector2(body.global_position.x, body.global_position.z)
	var seen: Array[Node] = []
	for other in body.get_parent().get_children():
		if other == body or not other.has_method("saw_kill"):
			continue
		var other_pos := Vector2(other.global_position.x, other.global_position.z)
		var facing := Vector2(-other.global_basis.z.x, -other.global_basis.z.z)
		if other_pos.distance_to(pos) <= other.boar_type.perception_radius and BoarSenses.in_view(other_pos, facing, pos):
			seen.append(other)
	return seen


## Whether a wall, fence or cliff face stands within reach of the boar along dir (XZ plane);
## other creatures and gentle slopes do not count.
static func wall_toward(body: CharacterBody3D, dir: Vector2, reach: float, rise: float) -> bool:
	var from := body.global_position + Vector3.UP * rise
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(dir.x, 0.0, dir.y) * reach,
			body.collision_mask, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and absf(hit.normal.y) < 0.5 and not hit.collider.has_method("knock")
