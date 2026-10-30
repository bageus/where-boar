extends Area3D

## A placed trap (M015, owner 2026-10-30), each works once and only on boars, never on hunters, helpers or birds:
## - pit: a boar that steps on the leaves drops in at once and stays till the hunt ends;
## - snare: the loop pulls tight and holds the boar until another boar runs past it or the hunter takes it (E);
## - tripwire: the boar falls and lies stunned, the hunter can take it (E) meanwhile;
## - cage: the gate drops once the boar is half inside, and it stays caught.

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")

## Owner, 2026-10-30.
const TRIP_STUN_SECONDS := 30.0
const WIRE_MIN_LENGTH := 1.0
const WIRE_MAX_LENGTH := 10.0
## Rope length until the hunter pulls the second peg, and of a wire the trap setter puts down (ASSUMPTION).
const WIRE_LENGTH := 3.0
## Half length of the tripline model's rope, metres: vertices farther out are the pegs.
const WIRE_PEG_FROM := 0.45

@export_enum("pit", "snare", "tripwire", "cage") var kind := "pit"
## Pit only: radius of the opening; the map cuts the ground away under it.
@export var hole_radius := 0.0
## Pit only: how far a boar drops, metres.
@export var depth := 0.0

## Tripwire: where the first peg went in; the hunter moves the second one with stretch_to().
var wire_start := Vector3.ZERO

var _used := false
var _held: BoarBody
var _player: AnimationPlayer
var _wire: MeshInstance3D
var _wire_mesh: Mesh


func _ready() -> void:
	_player = find_child("AnimationPlayer") as AnimationPlayer
	if kind == "pit":
		# The pit itself stays solid while it is dug; only the leaves and the rim show as a ghost.
		for part in ["PitWalls", "PitFloor"]:
			find_child(part).set_meta("solid", true)
	elif kind == "tripwire":
		_wire = find_child("Static") as MeshInstance3D
		_wire_mesh = _wire.mesh
		wire_start = global_position - global_basis.x * WIRE_LENGTH * 0.5
		stretch_to(global_position + global_basis.x * WIRE_LENGTH * 0.5)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _used or not body is BoarBody or not body.boar.is_free():
		return
	_used = true
	match kind:
		"pit":
			body.fall_in_pit(global_position, depth)
			_player.play("Pit_Break")
		"snare":
			body.snare()
			_held = body
			_player.play("Snare_Close")
		"tripwire":
			body.trip(TRIP_STUN_SECONDS)
		"cage":
			body.cage_capture()
			_player.play("Cage_Close")


## The loop opens again once a passing boar has freed the one it held.
func _physics_process(_delta: float) -> void:
	if _held and is_instance_valid(_held) and _held.boar.is_free():
		_held = null
		_player.play("Snare_Reset")


## Tripwire: the second peg goes towards end, at most WIRE_MAX_LENGTH from the first; the rope stretches between.
func stretch_to(end: Vector3) -> void:
	var span := Vector3(end.x - wire_start.x, 0.0, end.z - wire_start.z)
	var length := clampf(span.length(), WIRE_MIN_LENGTH, WIRE_MAX_LENGTH)
	var x := span.normalized() if span.length() > 0.01 else global_basis.x
	global_transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), wire_start + x * length * 0.5)
	($Collision.shape as BoxShape3D).size.x = length
	var arrays := _wire_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var extra := (length - _wire_mesh.get_aabb().size.x) * 0.5
	for i in verts.size():
		var v := verts[i]
		# Pegs move out whole; the rope between them stretches.
		v.x = v.x + signf(v.x) * extra if absf(v.x) > WIRE_PEG_FROM else v.x * (WIRE_PEG_FROM + extra) / WIRE_PEG_FROM
		verts[i] = v
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _wire_mesh.surface_get_material(0))
	_wire.mesh = mesh
