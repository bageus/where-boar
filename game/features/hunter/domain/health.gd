extends RefCounted

## Hunter health (section 10): rams hurt, zero sends the hunter back to camp. Full again every hunt;
## camp meals raise the maximum for the hunt (issue #9).

## ASSUMPTION (D013).
const MAX := 100

## MAX plus the meals eaten before the hunt.
var max_value := MAX
var value := MAX
## Forge armor worn this hunt (issue #11): damage it can still take before health does.
var armor := 0
## The shaman's blessing (issue #20): share added to the maximum when the meals are eaten.
var blessing := 0.0


func take(damage: int) -> void:
	var absorbed := mini(armor, damage)
	armor -= absorbed
	value = maxi(0, value - (damage - absorbed))


func is_down() -> bool:
	return value == 0


## The hired healer (issue #12) tops health up again, never past the maximum.
func heal(amount: int) -> void:
	value = mini(max_value, value + maxi(0, amount))


## Camp meals (issue #9) raise the maximum for this hunt and start it full.
func eat(bonus: int) -> void:
	max_value = roundi((MAX + bonus) * (1.0 + blessing))
	value = max_value
