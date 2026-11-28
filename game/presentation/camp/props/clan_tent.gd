extends RefCounted

## The clan tent (issue #23): stands apart once a clan is founded; the hunter walks in to the stew cauldron
## and the clan totem (one E window for both), a second chest stands by the door. It grows and its sign
## takes the tier colour as the clan's rating climbs.

const Station = preload("res://game/presentation/camp/props/station.tscn")
const BUILDINGS := "res://assets/models/buildings/"
const TENT = preload(BUILDINGS + "Clan tent/Prehistoric_Ochre_Clan_Tent.glb")
const CAULDRON = preload(BUILDINGS + "Tripod_Cauldron_and_Hearth.glb")
const HearthFire = preload("res://game/presentation/camp/props/hearth_fire.gd")
const TOTEM = preload(BUILDINGS + "Chunky_Boar_Log_Totem.glb")
const CHEST = preload(BUILDINGS + "Primitive_Stick_Chest.glb")
## Free ground between the campfire, the hunting hut and the tavern; the door faces the campfire.
const SPOT := Vector3(8.0, 0.0, 6.0)
const YAW := -2.2
const CHEST_SPOT := Vector3(11.8, 0.0, 8.2)
## Inside, in the tent model's units: the cauldron in the middle, the totem at the back.
const CAULDRON_AT := Vector3(-0.3, 0.0, 0.0)
const TOTEM_AT := Vector3(-0.3, 0.0, -1.7)
## Sign colours by clan level: New, Common, Uncommon, Rare, Epic, Legendary.
const TIER_COLORS: Array[Color] = [Color.WHITE, Color(0.85, 0.85, 0.85), Color(0.45, 1.0, 0.4), Color(0.4, 0.65, 1.0),
	Color(0.75, 0.45, 1.0), Color(1.0, 0.65, 0.2)]


## Adds the tent and its chest to stations (once); the tent is the "clan_tent" station.
static func raise(stations: Node3D, clan: RefCounted) -> void:
	var tent: Node3D = stations.get_node_or_null("ClanTent")
	if not tent:
		tent = Station.instantiate()
		tent.name = "ClanTent"
		tent.station_id = "clan_tent"
		tent.model = TENT
		tent.solid = true
		tent.walk_in = true
		tent.position = SPOT
		tent.rotation.y = YAW
		stations.add_child(tent)
		for part: Array in [[CAULDRON, CAULDRON_AT, 0.55], [TOTEM, TOTEM_AT, 0.7]]:
			var decor: Node3D = part[0].instantiate()
			decor.position = part[1]
			decor.scale = Vector3.ONE * part[2]
			tent.add_child(decor)
			if part[0] == CAULDRON:
				HearthFire.light(decor, Vector3(0.0, 0.12, -0.28), 1.1, 0.55)
		var chest: Node3D = Station.instantiate()
		chest.name = "ClanChest"
		chest.station_id = "chest"
		chest.title = "Clan chest"
		chest.model = CHEST
		chest.solid = true
		chest.position = CHEST_SPOT
		chest.rotation.y = YAW
		chest.scale = Vector3.ONE * 0.6
		stations.add_child(chest)
	tent.scale = Vector3.ONE * (1.3 + 0.08 * clan.level())  # 30% bigger than first drawn (issue #23)
	tent.title = "%s\n%s tent" % [clan.name, clan.tier_name()]
	tent.get_node("Label").text = tent.title
	tent.get_node("Label").modulate = TIER_COLORS[clan.level()]
