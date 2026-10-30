class_name BoarType
extends Resource

## Authored boar type (section 15): looks, numbers and rewards. Treated as immutable at runtime.

## Stable id used in results and rewards, e.g. "common_brown".
@export var id := ""
@export var display_name := ""
@export var color := Color(0.42, 0.27, 0.16)
## Rigged model with idle, walk, run, attack and death (tools/rig_boars.py).
@export var model: PackedScene
## Relative spawn weight; rarer types have smaller weights.
@export var spawn_weight := 1.0
@export var max_health := 3
@export var damage := 1
@export var flee_speed := 8.0
@export var panic_speed := 10.0
@export var perception_radius := 12.0
## Chance that a panicking boar turns and charges (D018).
@export_range(0.0, 1.0) var aggression := 0.35
## Share of a ram's knockback this boar takes; armored boars barely move.
@export_range(0.0, 1.0) var knock_scale := 1.0
@export var reward_dead := 2
@export var reward_captured := 4
