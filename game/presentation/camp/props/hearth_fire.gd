extends RefCounted

## Shader flame over a disc of glowing coals (assets/fire), put into a hearth, furnace or oven of any model.

const FLAME = preload("res://assets/fire/flame.tscn")
const EMBERS = preload("res://assets/fire/embers.tres")


## Lights a fire at pos (parent's units); size scales both flame and coals. Returns the fire node.
static func light(parent: Node3D, pos: Vector3, size: float, coal_radius := 0.5) -> Node3D:
	var fire := Node3D.new()
	fire.name = "HearthFire"
	fire.position = pos
	fire.scale = Vector3.ONE * size
	var coals := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = coal_radius
	disc.bottom_radius = coal_radius
	disc.height = 0.05
	disc.material = EMBERS
	coals.mesh = disc
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire.add_child(coals)
	var flame: Node3D = FLAME.instantiate()
	flame.position.y = 0.02
	fire.add_child(flame)
	parent.add_child(fire)
	return fire
