extends Area3D

## A placed trap (M015, owner 2026-10-30), each works once and only on boars, never on hunters, helpers or birds:
## - pit: a boar that steps on the leaves drops in at once and stays till the hunt ends;
## - snare: the loop pulls tight and holds the boar until another boar runs past it or the hunter takes it (E);
## - tripwire: the boar falls and lies stunned, the hunter can take it (E) meanwhile;
## - cage: the gate drops once the boar is half inside, and it stays caught. A fruit lies inside: calm boars smell
##   it like bait and walk in (owner, 2026-11-05).

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")
const Sfx = preload("res://game/core/sfx/public/sfx.gd")
const CageFruit = preload("res://assets/models/peak_fruit/04_apple.tscn")

## Owner, 2026-10-30.
const TRIP_STUN_SECONDS := 30.0
const WIRE_MIN_LENGTH := 1.0
const WIRE_MAX_LENGTH := 10.0
## Rope length until the hunter pulls the second peg, and of a wire the trap setter puts down (ASSUMPTION).
const WIRE_LENGTH := 3.0
## Half length of the tripline model's rope, metres: vertices farther out are the pegs.
const WIRE_PEG_FROM := 0.45
## How far calm boars smell the fruit in a built cage, metres (ASSUMPTION, D013: like an apple bait).
const CAGE_PULL := 18.0
## Boars read baits from this group besides the bait the hunter drops (boar_body.gd).
const BAITS_GROUP := "baits"

@export_enum("pit", "snare", "tripwire", "cage") var kind := "pit"
## Pit only: radius of the opening; the map cuts the ground away under it.
@export var hole_radius := 0.0
## Pit only: how far a boar drops, metres.
@export var depth := 0.0

## Tripwire: where the first peg went in; the hunter moves the second one with stretch_to().
var wire_start := Vector3.ZERO
## Cage only: bait pull radius, 0 while it is a ghost or once it has caught a boar.
var attract_radius := 0.0

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
	elif kind == "cage":
		_put_fruit()
		add_to_group(BAITS_GROUP)
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
			Sfx.play(self, "snare", 0.0, 30.0)
		"tripwire":
			body.trip(TRIP_STUN_SECONDS)
			Sfx.play(self, "tripwire", 0.0, 30.0)
		"cage":
			body.cage_capture()
			_player.play("Cage_Close")
			Sfx.play(self, "cage_slam", 0.0, 40.0)


## The fruit at the back of the cage, painted from its vertex colours like dropped bait (bait.gd).
func _put_fruit() -> void:
	var fruit: Node3D = CageFruit.instantiate()
	fruit.position = Vector3(0.0, 0.0, -0.6)
	fruit.scale = Vector3.ONE * 1.5
	add_child(fruit)
	for mesh: MeshInstance3D in fruit.find_children("*", "MeshInstance3D"):
		var paint := StandardMaterial3D.new()
		paint.vertex_color_use_as_albedo = true
		mesh.material_override = paint


## The loop opens again once a passing boar has freed the one it held; a built, empty cage draws boars.
func _physics_process(_delta: float) -> void:
	if kind == "cage":
		attract_radius = CAGE_PULL if monitoring and not _used else 0.0
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
