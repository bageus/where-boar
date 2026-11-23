extends Node

## A penned boar potters about its spot: walks to a nearby point, then stands and eats for a few seconds.
## Radius is in the pen model's units (the boar's parent is scaled), kept small to stay clear of the fence and trough.

const RADIUS := 1.0
const EAT_SECONDS := Vector2(3.0, 7.0)

var boar: Node3D
var _home: Vector3


func _ready() -> void:
	_home = boar.position
	_loop()


func _loop() -> void:
	var scale_up: float = boar.get_parent().scale.x
	await get_tree().create_timer(randf_range(0.0, 4.0)).timeout
	while is_inside_tree():
		var target := _home + Vector3(randf_range(-RADIUS, RADIUS), 0.0, randf_range(-RADIUS, RADIUS))
		var offset := target - boar.position
		boar.rotation.y = atan2(offset.x, offset.z)  # the boar faces +z
		var seconds: float = offset.length() * scale_up / boar.WALK_SPEED
		boar.move(boar.WALK_SPEED)
		var tween := create_tween()
		tween.tween_property(boar, "position", target, seconds)
		await tween.finished
		var until := Time.get_ticks_msec() + int(randf_range(EAT_SECONDS.x, EAT_SECONDS.y) * 1000.0)
		while Time.get_ticks_msec() < until and is_inside_tree():
			boar.move(0.0, true)
			await get_tree().create_timer(1.0).timeout
