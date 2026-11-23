extends RefCounted

## Hunter health (section 10): rams hurt, zero sends the hunter back to camp. Full again every hunt.

## ASSUMPTION (D013).
const MAX := 100

var value := MAX
## Forge armor worn this hunt (issue #11): damage it can still take before health does.
var armor := 0


func take(damage: int) -> void:
	var absorbed := mini(armor, damage)
	armor -= absorbed
	value = maxi(0, value - (damage - absorbed))


func is_down() -> bool:
	return value == 0


## The hired healer (issue #12) tops health up again, never past MAX.
func heal(amount: int) -> void:
	value = mini(MAX, value + maxi(0, amount))
