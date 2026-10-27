extends Node3D

## First-person view of what the hunter holds (playtest 2026-10-27): one simple model per weapon,
## a quick strike, and the spear raised over the shoulder while aiming a throw.

const REST := Vector3(0.3, -0.35, -0.5)
## Aiming: raised as for a swing; pulled further back the stronger the throw.
const RAISED := Vector3(0.3, -0.05, -0.3)
const PULL_BACK := 0.25
const RAISED_TILT := 0.25
const STAB_REACH := 0.45
const STAB_SECONDS := 0.18
const FOLLOW_RATE := 14.0

var _striking := false

## Children in Loadout.Weapon order: spear, net, club, sling, bow, knife.
@onready var _models: Array[Node] = [$Spear, $Net, $Club, $Sling, $Bow, $Knife]


## weapon: the selected Loadout.Weapon; armed: false when it is spent (spear thrown, no nets or arrows).
## Aiming with power 0..1 raises the spear.
func pose(weapon: int, armed: bool, aiming: bool, power: float, delta: float) -> void:
	for i in _models.size():
		_models[i].visible = armed and i == weapon
	if _striking:
		return
	var target := RAISED + Vector3(0.0, 0.0, PULL_BACK * power) if aiming else REST
	var t := minf(1.0, FOLLOW_RATE * delta)
	position = position.lerp(target, t)
	rotation.x = lerpf(rotation.x, RAISED_TILT if aiming else 0.0, t)


## A short jab forward and back (stab, club swing, net cast, sling or bow shot).
func strike() -> void:
	_striking = true
	var jab := create_tween()
	jab.tween_property(self, "position", REST + Vector3(0.0, 0.05, -STAB_REACH), STAB_SECONDS * 0.4)
	jab.tween_property(self, "position", REST, STAB_SECONDS * 0.6)
	jab.finished.connect(func() -> void: _striking = false)
