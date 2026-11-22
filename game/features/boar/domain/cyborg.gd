class_name Cyborg
extends RefCounted

## Cyborg ("terminator") boar (owner, 2026-11-22): hunts the hunter instead of fleeing.
## Armour soaks hits before health; a turret on its back turns up to 90 degrees each side of the body
## and fires every 4-5 s; it walks slower than the hunter, so the hunter can outrun it or hide in bushes
## and tall grass. Seen hiding, the cyborg walks to the spot and searches there. Engine-light: the scene
## feeds positions, sight and delta; this class decides.

enum State { PATROL, NOTICE, CHASE, SEARCH, DEAD }
## The mark over its head (owner, 2026-11-22): magnifier while it searches, "?" while unsure, an eye once it hunts.
enum Mark { SEARCH, DOUBT, SURE }
enum Gun { CANNON, MACHINEGUN }

## Slower than the hunter's walk (4 m/s) and far slower than any boar (owner: "скорость ниже").
const PATROL_SPEED := 1.5
const CHASE_SPEED := 3.5
## The turret's reach to each side of the body's facing (owner: 90 degrees left and right).
const TURRET_HALF_ARC_DEG := 90.0
## Turret turn rate, degrees per second (ASSUMPTION).
const TURRET_TURN_DEG := 120.0
## The turret fires only when aimed within this many degrees of the target (ASSUMPTION).
const AIM_TOLERANCE_DEG := 6.0
## Cooldown between shots (cannon) or bursts (machinegun), seconds (owner: 4-5 s).
const COOLDOWN_MIN := 4.0
const COOLDOWN_MAX := 5.0
## Machinegun burst: rounds and the gap between them (ASSUMPTION).
const BURST_ROUNDS := 5
const BURST_GAP := 0.12
## Projectile speeds, m/s: fast, but at 20 m the hunter has about a second to duck or step aside (owner).
const CANNON_SHOT_SPEED := 16.0
const BULLET_SPEED := 22.0
const CANNON_DAMAGE := 30
const BULLET_DAMAGE := 8
## How far it notices the hunter and how far it shoots, metres (ASSUMPTION).
const SIGHT_RANGE := 30.0
const FIRE_RANGE := 25.0
## In SEARCH it finds a hunter hiding this close even in cover, metres (ASSUMPTION).
const SEARCH_FIND_RADIUS := 2.0
## How long it searches the last seen spot before it gives up and patrols again, seconds (ASSUMPTION).
const SEARCH_TIME := 8.0
## It stands and stares this long at a hunter it spotted before it is sure and attacks, seconds (ASSUMPTION).
const NOTICE_TIME := 1.0
## Having lost the hunter, it wonders ("?") this long before it searches (magnifier), seconds (ASSUMPTION).
const DOUBT_TIME := 1.5
## Close enough to stop walking toward the target, metres.
const CHASE_STOP := 6.0

var gun: Gun
var armor: int
var health: int
var state: State = State.PATROL
## Where the hunter was last seen; SEARCH walks there.
var last_seen := Vector2.ZERO
## Turret yaw relative to the body, radians, within +-TURRET_HALF_ARC_DEG.
var turret_yaw := 0.0
var _cooldown := 0.0
var _burst_left := 0
var _burst_timer := 0.0
var _search_left := 0.0
var _notice_left := 0.0
var _lost_for := 0.0


func _init(p_gun: Gun, p_armor: int, p_health: int) -> void:
	gun = p_gun
	armor = p_armor
	health = p_health


func is_dead() -> bool:
	return state == State.DEAD


## Armour takes the hit first; whatever it cannot hold goes to health (owner). A hit also tells it where the
## shooter is, so a patrolling cyborg turns to hunt.
func take_hit(damage: int, from := Vector2.INF) -> void:
	if is_dead():
		return
	var soaked := mini(armor, damage)
	armor -= soaked
	health = maxi(0, health - (damage - soaked))
	if health == 0:
		state = State.DEAD
		_burst_left = 0
		return
	if from != Vector2.INF and state == State.PATROL:
		_lose(from)


## One think step. sees: the hunter is in line of sight and not in cover (the scene checks).
## Returns the point to walk to, or Vector2.INF to stand (patrol is left to the scene).
func think(delta: float, pos: Vector2, hunter_pos: Vector2, sees: bool) -> Vector2:
	if is_dead():
		return Vector2.INF
	var dist := pos.distance_to(hunter_pos)
	_lost_for += delta
	if (sees and dist <= SIGHT_RANGE) or (state == State.SEARCH and dist <= SEARCH_FIND_RADIUS):
		last_seen = hunter_pos
		if state != State.CHASE and state != State.NOTICE:
			state = State.NOTICE
			_notice_left = NOTICE_TIME
		_notice_left -= delta
		if state == State.NOTICE and (_notice_left <= 0.0 or dist <= SEARCH_FIND_RADIUS):
			state = State.CHASE
	elif state in [State.CHASE, State.NOTICE]:
		# Lost sight (cover or behind something): go to where it last saw the hunter and search.
		_lose(last_seen)
	match state:
		State.NOTICE:
			return Vector2.INF
		State.CHASE:
			return Vector2.INF if dist <= CHASE_STOP else hunter_pos
		State.SEARCH:
			if pos.distance_to(last_seen) <= 1.0:
				_search_left -= delta
				if _search_left <= 0.0:
					state = State.PATROL
			return last_seen
	return Vector2.INF


func _lose(at: Vector2) -> void:
	last_seen = at
	state = State.SEARCH
	_search_left = SEARCH_TIME
	_lost_for = 0.0


func mark() -> Mark:
	if state == State.CHASE:
		return Mark.SURE
	if state == State.NOTICE or (state == State.SEARCH and _lost_for < DOUBT_TIME):
		return Mark.DOUBT
	return Mark.SEARCH


func speed() -> float:
	return CHASE_SPEED if state in [State.CHASE, State.SEARCH] else PATROL_SPEED


## Yaw (radians, relative to the body) the turret should point at target, clamped to its arc.
static func turret_target(pos: Vector2, facing: Vector2, target: Vector2) -> float:
	var rel := facing.angle_to(target - pos)
	var arc := deg_to_rad(TURRET_HALF_ARC_DEG)
	return clampf(rel, -arc, arc)


## Turns the turret toward the hunter and fires when ready. Returns how many rounds leave the barrel
## this step (0 or 1); the scene spawns them from the turret along body facing rotated by turret_yaw.
## roll in [0, 1) picks the cooldown.
func update_turret(delta: float, pos: Vector2, facing: Vector2, hunter_pos: Vector2, roll: float) -> int:
	if is_dead():
		return 0
	_cooldown = maxf(0.0, _cooldown - delta)
	var aim := turret_target(pos, facing, hunter_pos) if state == State.CHASE else 0.0
	turret_yaw = move_toward(turret_yaw, aim, deg_to_rad(TURRET_TURN_DEG) * delta)
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer > 0.0:
			return 0
		_burst_left -= 1
		_burst_timer = BURST_GAP
		return 1
	if state != State.CHASE or _cooldown > 0.0 or pos.distance_to(hunter_pos) > FIRE_RANGE:
		return 0
	var off := absf(facing.angle_to(hunter_pos - pos) - turret_yaw)
	if off > deg_to_rad(AIM_TOLERANCE_DEG):
		return 0  # out of the arc or still turning
	_cooldown = lerpf(COOLDOWN_MIN, COOLDOWN_MAX, roll)
	if gun == Gun.MACHINEGUN:
		_burst_left = BURST_ROUNDS - 1
		_burst_timer = BURST_GAP
	return 1


func shot_speed() -> float:
	return CANNON_SHOT_SPEED if gun == Gun.CANNON else BULLET_SPEED


func shot_damage() -> int:
	return CANNON_DAMAGE if gun == Gun.CANNON else BULLET_DAMAGE
