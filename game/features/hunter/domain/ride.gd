extends RefCounted

## Riding a saddled boar (D021, owner's choice "верхом"): the mount's type sets speed and perk;
## no stamina is spent and only the spear stab works from the saddle.

const BoarType = preload("res://game/features/boar/public/boar_type.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")

## Mount types that can be saddled (D021: three kinds).
const MOUNT_TYPES := ["runner_grey", "aggressive_red", "armored_black"]

var type: BoarType = null


func is_riding() -> bool:
	return type != null


func mount(boar_type: BoarType) -> void:
	type = boar_type


func dismount() -> void:
	type = null


func speed(on_foot: float) -> float:
	return type.flee_speed if type else on_foot


## From the saddle the rider stabs with the spear, shoots the bow and casts nets (owner, 2026-10-27);
## no spear throws, club swings or sling shots.
func allows(weapon: Loadout.Weapon, aiming: bool) -> bool:
	if not type:
		return true
	return weapon in [Loadout.Weapon.BOW, Loadout.Weapon.NET] or (weapon == Loadout.Weapon.SPEAR and not aiming)


## The armored mount barely moves when rammed, so its rider is not knocked off.
func shrugs_off_knock() -> bool:
	return type != null and type.knock_scale < 0.5


## The angry mount rams boars it runs into.
func rams() -> bool:
	return type != null and type.aggression >= 0.9
