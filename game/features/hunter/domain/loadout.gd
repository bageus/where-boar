extends RefCounted

## What the hunter carries: one spear and a few nets (M003, M004).

## ASSUMPTION: nets per hunt, balanced in phase 2 (D013).
const START_NETS := 3

var spear_in_hand := true
var nets := START_NETS


func throw_spear() -> bool:
	if not spear_in_hand:
		return false
	spear_in_hand = false
	return true


func pick_spear() -> void:
	spear_in_hand = true


func throw_net() -> bool:
	if nets == 0:
		return false
	nets -= 1
	return true


## A net that missed can be picked up again (M004, ASSUMPTION).
func pick_net() -> void:
	nets += 1
