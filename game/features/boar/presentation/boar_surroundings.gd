extends RefCounted

## Reads a boar's herd mates and nearby bait nodes into plain positions for BoarSenses.

const Boar = preload("res://game/features/boar/domain/boar.gd")
const BoarSenses = preload("res://game/features/boar/domain/boar_senses.gd")


## XZ positions of the boar's living herd mates; only fleeing or panicking ones when scared_only.
static func herd_positions(body: Node3D, scared_only: bool) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for mate in body.herd:
		if mate == body or not is_instance_valid(mate):
			continue
		if scared_only and mate.boar.state not in [Boar.State.FLEE, Boar.State.PANIC]:
			continue
		spots.append(Vector2(mate.global_position.x, mate.global_position.z))
	return spots


## Heading back to the herd centre for a stray, or ZERO.
static func herd_cohesion(body: Node3D, pos: Vector2, spread: float) -> Vector2:
	var mates := herd_positions(body, false)
	if mates.is_empty():
		return Vector2.ZERO
	var centre := Vector2.ZERO
	for mate in mates:
		centre += mate
	return BoarSenses.cohesion_heading(pos, centre / mates.size(), spread)


## Bait nodes still on the ground as Vector3(x, z, pull radius).
static func bait_spots(baits: Array[Node3D]) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for bait in baits:
		if is_instance_valid(bait):
			spots.append(Vector3(bait.global_position.x, bait.global_position.z, bait.attract_radius))
	return spots
