extends Node3D

## The bow held in first person (owner's model Bow_No_String.glb) with a procedural string (owner, 2026-11-23):
## at rest the string hangs straight and slack with an arrow nocked on it; drawing pulls the string's middle
## back with the arrow; with no arrows left only the bow and its slack string show.
## Model axes: the bow stands along Y, the grip bulges to -X (where the arrow points), the string runs at x = 0.

const Strand = preload("res://game/features/hunter/presentation/strand.gd")
const DRAW := 0.55  # how far the string's middle is pulled back at full draw, model units
const FOLLOW_RATE := 30.0  # fast, so a release snaps the string back
const ARROW_NOCK := 0.41  # the arrow model's nock end lies this far behind its origin
const ARROW_SIDE := 0.05  # the arrow rests beside the grip, not through it
const STRING := Color(0.93, 0.88, 0.72)

var _draw := 0.0
var _upper: MeshInstance3D
var _lower: MeshInstance3D
@onready var _top: Node3D = $Model/String_Upper
@onready var _bottom: Node3D = $Model/String_Lower


func _ready() -> void:
	_upper = Strand.make(self, 0.007, STRING)
	_lower = Strand.make(self, 0.007, STRING)
	pose(true, false, 0.0, 1.0)


## nocked: an arrow is on the string (any left); drawing with power 0..1 pulls it back.
func pose(nocked: bool, drawing: bool, power: float, delta: float) -> void:
	_draw = lerpf(_draw, power if nocked and drawing else 0.0, minf(1.0, FOLLOW_RATE * delta))
	var nock := (_top.position + _bottom.position) / 2.0 + Vector3(DRAW * _draw, 0.0, 0.0)
	Strand.stretch(_upper, nock, _top.position)
	Strand.stretch(_lower, _bottom.position, nock)
	$Arrow.visible = nocked
	$Arrow.position = nock + Vector3(-ARROW_NOCK, 0.0, ARROW_SIDE)
