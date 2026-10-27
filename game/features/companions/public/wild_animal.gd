extends CharacterBody3D

## A wild rooster or turkey on the hunt map (D024): wanders, runs from a close hunter, caught by a net.

## Fact: a net caught this animal; it goes to the camp pen.
signal caught(animal_id: String)

# ASSUMPTION numbers (D013): slower than a sprinting hunter (7 m/s).
const WANDER_SPEED := 1.0
const RUN_SPEED := 5.0
const SHY_RADIUS := 6.0
const TURN_SECONDS := 2.0

@export var animal_id := "rooster"

## Injected by the map.
var hunter: Node3D

var _heading := Vector2.ZERO
var _turn_left := 0.0


## Same entry point the net uses on boars.
func net_hit() -> void:
	caught.emit(animal_id)
	queue_free()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var pos := Vector2(global_position.x, global_position.z)
	var away := pos - Vector2(hunter.global_position.x, hunter.global_position.z)
	var speed := WANDER_SPEED
	if away.length() < SHY_RADIUS:
		_heading = away.normalized()
		speed = RUN_SPEED
	else:
		_turn_left -= delta
		if _turn_left <= 0.0:
			_heading = Vector2.from_angle(randf() * TAU)
			_turn_left = TURN_SECONDS
	velocity.x = _heading.x * speed
	velocity.z = _heading.y * speed
	move_and_slide()
