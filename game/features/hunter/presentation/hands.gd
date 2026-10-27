extends Node3D

## First-person view of what the hunter holds (playtest 2026-10-27): the spear or a net,
## a quick stab, and the spear raised over the shoulder while aiming a throw.

const REST := Vector3(0.3, -0.35, -0.5)
## Aiming: raised as for a swing; pulled further back the stronger the throw.
const RAISED := Vector3(0.3, -0.05, -0.3)
const PULL_BACK := 0.25
const RAISED_TILT := 0.25
const STAB_REACH := 0.45
const STAB_SECONDS := 0.18
const FOLLOW_RATE := 14.0

var _striking := false

@onready var _spear: Node3D = $Spear
@onready var _net: Node3D = $Net


## spear and net: what is in hand right now; aiming with power 0..1 raises the spear.
func pose(spear: bool, net: bool, aiming: bool, power: float, delta: float) -> void:
	_spear.visible = spear
	_net.visible = net
	if _striking:
		return
	var target := RAISED + Vector3(0.0, 0.0, PULL_BACK * power) if aiming else REST
	var t := minf(1.0, FOLLOW_RATE * delta)
	position = position.lerp(target, t)
	rotation.x = lerpf(rotation.x, RAISED_TILT if aiming else 0.0, t)


## A short jab forward and back (stab, club swing or net cast).
func strike() -> void:
	_striking = true
	var jab := create_tween()
	jab.tween_property(self, "position", REST + Vector3(0.0, 0.05, -STAB_REACH), STAB_SECONDS * 0.4)
	jab.tween_property(self, "position", REST, STAB_SECONDS * 0.6)
	jab.finished.connect(func() -> void: _striking = false)
