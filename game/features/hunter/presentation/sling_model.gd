extends Node3D

## The slingshot held in first person (owner's model Slingshot_No_Bands.glb) with procedural bands (owner,
## 2026-11-23): at rest the leather pouch hangs on the slack bands at the slingshot's mid-height; when the draw
## starts a stone is tossed up into the pouch from below, as if from a pocket, then the pouch pulls back.
## Model axes: handle down, fork up along Y, bands tied on the +Z side; the hunter is at +Z, shots fly to -Z.

const Strand = preload("res://game/features/hunter/presentation/strand.gd")
const REST := Vector3(0.0, 0.02, 0.1)  # the hanging pouch
const HANG_TILT := -1.2  # the hanging pouch folds down, radians about X
const PULL := 0.9  # how far back from the fork tips the pouch is pulled at full draw, model units
const POCKET := Vector3(0.15, -0.7, 0.45)  # where the tossed stone starts
const TOSS_SECONDS := 0.25
const TOSS_HEIGHT := 0.3
const FOLLOW_RATE := 30.0
const BAND := Color(0.42, 0.26, 0.16)

var _draw := 0.0
var _toss := 1.0  # 0..1 while the stone flies into the pouch
var _was_drawing := false
var _left: MeshInstance3D
var _right: MeshInstance3D
@onready var _pouch: Node3D = $Model/Leather_Pouch
@onready var _fork_left: Node3D = $Model/Band_Fork_L
@onready var _fork_right: Node3D = $Model/Band_Fork_R


func _ready() -> void:
	_left = Strand.make(self, 0.016, BAND)
	_right = Strand.make(self, 0.016, BAND)
	pose(false, false, 0.0, 1.0)


## loaded: a stone is at hand (any left); drawing with power 0..1 tosses one into the pouch and pulls it back.
func pose(loaded: bool, drawing: bool, power: float, delta: float) -> void:
	drawing = drawing and loaded
	if drawing and not _was_drawing:
		_toss = 0.0
	_was_drawing = drawing
	_toss = minf(1.0, _toss + delta / TOSS_SECONDS)
	var target := power if drawing and _toss >= 1.0 else 0.0
	_draw = lerpf(_draw, target, minf(1.0, FOLLOW_RATE * delta))
	var tips := (_fork_left.position + _fork_right.position) / 2.0
	var amount := minf(1.0, _draw * 4.0)  # the pouch rises level with the tips early in the draw
	_pouch.position = REST.lerp(tips, amount) + Vector3(0.0, 0.0, PULL * _draw)
	_pouch.rotation = Vector3(HANG_TILT * (1.0 - amount), 0.0, 0.0)
	var left := _pouch.transform * ($Model/Leather_Pouch/Band_Pouch_L as Node3D).position
	var right := _pouch.transform * ($Model/Leather_Pouch/Band_Pouch_R as Node3D).position
	Strand.stretch(_left, left, _fork_left.position)
	Strand.stretch(_right, right, _fork_right.position)
	$Stone.visible = drawing
	var seat := _pouch.position - Vector3(0.0, 0.05, 0.0)  # the stone model stands on its origin
	$Stone.position = POCKET.lerp(seat, _toss) + Vector3(0.0, TOSS_HEIGHT * sin(PI * _toss), 0.0)
