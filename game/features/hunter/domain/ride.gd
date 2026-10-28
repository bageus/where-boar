extends RefCounted

## Riding a saddled boar (D021, owner's choice "верхом"): the mount's type sets speed and perk;
## no stamina is spent; every weapon works from the saddle.

const BoarType = preload("res://game/features/boar/public/boar_type.gd")
const Loadout = preload("res://game/features/hunter/domain/loadout.gd")

## Mount types that can be saddled (D021: three kinds).
const MOUNT_TYPES := ["runner_grey", "aggressive_red", "armored_black"]

## Boars with at least this much health knock a rider out of the saddle when they ram (owner, 2026-10-28).
const UNSEAT_HEALTH := 4

var type: BoarType = null


func is_riding() -> bool:
	return type != null


func mount(boar_type: BoarType) -> void:
	type = boar_type


func dismount() -> void:
	type = null


func speed(on_foot: float) -> float:
	return type.flee_speed if type else on_foot


## Every weapon works from the saddle (owner, 2026-10-27); kept as the one place to restrict it again.
func allows(_weapon: Loadout.Weapon, _aiming: bool) -> bool:
	return true


## The armored mount barely moves when rammed, so its rider is not knocked off.
func shrugs_off_knock() -> bool:
	return type != null and type.knock_scale < 0.5


## A large boar's ram throws the rider off, unless the mount is armored.
func is_unseated_by(rammer: BoarType) -> bool:
	return type != null and not shrugs_off_knock() and rammer.max_health >= UNSEAT_HEALTH


## The angry mount rams boars it runs into.
func rams() -> bool:
	return type != null and type.aggression >= 0.9
