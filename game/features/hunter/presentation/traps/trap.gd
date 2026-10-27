extends Area3D

## A placed trap (M015, D023): pit and snare hold a boar, the tripwire knocks one down, the cage captures one.
## Each trap works once.

const BoarBody = preload("res://game/features/boar/public/boar_body.gd")

## ASSUMPTION (D013).
const TRIP_STUN_SECONDS := 3.0

@export_enum("pit", "snare", "tripwire", "cage") var kind := "pit"

var _used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _used or not body is BoarBody or not body.boar.is_free():
		return
	_used = true
	match kind:
		"pit":
			body.fall_in_pit()
		"snare":
			body.snare()
		"tripwire":
			body.trip(TRIP_STUN_SECONDS)
			queue_free()
		"cage":
			body.cage_capture()
			$Bars.show()
