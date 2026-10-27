extends StaticBody3D

## Generous hit volume around a boar (playtest 2026-10-27): weapons hit it, nothing moves against it
## (physics layer 6 only). Passes hits on to the boar.


func spear_hit(amount: int) -> void:
	get_parent().spear_hit(amount)


func net_hit() -> void:
	get_parent().net_hit()


func knock(impulse: Vector3, damage: int = 0) -> void:
	get_parent().knock(impulse, damage)
