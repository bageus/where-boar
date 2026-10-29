extends CharacterBody3D

## A wild rooster or turkey on the hunt map (D024): wanders, runs from a close hunter crying out,
## caught by a net or by hand (E) when the hunter gets close enough. Shows the owner's thin bird model
## (bird_model.gd) that idles, pecks, walks and runs.

const Sfx = preload("res://game/core/sfx/public/sfx.gd")

## Fact: a net caught this animal; it goes to the camp pen.
signal caught(animal_id: String)
## Fact: a weapon killed this animal (owner, 2026-10-27); nothing goes to the pen.
signal killed(animal_id: String)

# ASSUMPTION numbers (D013): slower than a sprinting hunter (7 m/s).
const WANDER_SPEED := 1.0
const RUN_SPEED := 5.0
const SHY_RADIUS := 6.0
const TURN_SECONDS := 2.0
## How close the hunter must be to grab it with E (playtest 2026-10-27, ASSUMPTION).
const CATCH_RADIUS := 1.8
const CALL_SECONDS := 1.2
## A calm bird clucks or gobbles quietly this often (ASSUMPTION).
const IDLE_MIN_SECONDS := 6.0
const IDLE_MAX_SECONDS := 15.0
## Share of wander turns spent standing and pecking the ground (ASSUMPTION).
const PECK_CHANCE := 0.4
const MODEL_WALK_SPEED := 1.0  # ground speed the walk cycle was keyed for, m/s (ASSUMPTION)
const MODEL_RUN_SPEED := 4.0

@export var animal_id := "rooster"
## Model scenes; one is picked when the animal is made.
@export var models: Array[PackedScene] = []

## Injected by the map.
var hunter: Node3D

var _heading := Vector2.ZERO
var _turn_left := 0.0
var _call_left := 0.0
var _idle_left := randf_range(0.0, IDLE_MAX_SECONDS)
var _pecking := false
var _player: AnimationPlayer


func _ready() -> void:
	$Call.stream = Sfx.stream(animal_id + "_call")
	var model: Node3D = models.pick_random().instantiate()
	model.name = "Model"
	add_child(model)
	_player = model.find_child("AnimationPlayer") as AnimationPlayer
	for anim in ["idle", "walk", "run", "peck"]:
		_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_player.play("idle")
	_player.seek(randf() * _player.current_animation_length)  # birds in a group do not move in step


## The hunter pressed E nearby; true when it was close enough to grab.
func try_grab(hunter_pos: Vector3) -> bool:
	if global_position.distance_to(hunter_pos) > CATCH_RADIUS:
		return false
	net_hit()
	return true


## Any weapon hit kills a bird.
func spear_hit(_amount: int) -> void:
	killed.emit(animal_id)
	queue_free()


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
		_pecking = false
		_call_left -= delta
		if _call_left <= 0.0:
			_call_left = CALL_SECONDS
			$Call.play()
			if randf() < 0.3:  # a second voice over the first now and then
				Sfx.play(self, animal_id + "_call", -4.0, 30.0, randf_range(0.1, 0.3))
	else:
		_idle_left -= delta
		if _idle_left <= 0.0:
			_idle_left = randf_range(IDLE_MIN_SECONDS, IDLE_MAX_SECONDS)
			if randf() < 0.6:  # not every time (owner, 2026-10-29)
				Sfx.play(self, animal_id + "_idle", -10.0, 20.0)
		_turn_left -= delta
		if _turn_left <= 0.0:
			_heading = Vector2.from_angle(randf() * TAU)
			_turn_left = TURN_SECONDS
			_pecking = randf() < PECK_CHANCE
		if _pecking:
			speed = 0.0
	velocity.x = _heading.x * speed
	velocity.z = _heading.y * speed
	move_and_slide()
	_animate(speed)


## Faces the heading (models look along -Z) and plays the animation for the ground speed.
func _animate(speed: float) -> void:
	if speed > 0.0:
		rotation.y = atan2(-_heading.x, -_heading.y)
	var anim := ("peck" if _pecking else "idle") if speed == 0.0 else ("walk" if speed < RUN_SPEED else "run")
	_player.play(anim, 0.2)
	_player.speed_scale = 1.0 if speed == 0.0 else speed / (MODEL_WALK_SPEED if anim == "walk" else MODEL_RUN_SPEED)
