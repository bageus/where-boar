extends MeshInstance3D

## A ring that spreads from the hunter to the shout's reach and fades (owner, 2026-10-27).

const SECONDS := 0.6

## Set by the map before the wave enters the tree: the shout's reach in metres.
var radius := 15.0


func _ready() -> void:
	scale = Vector3(0.1, 1.0, 0.1)
	var material: StandardMaterial3D = material_override
	var spread := create_tween().set_parallel()
	spread.tween_property(self, "scale", Vector3(radius, 1.0, radius), SECONDS)
	spread.tween_property(material, "albedo_color:a", 0.0, SECONDS).set_ease(Tween.EASE_IN)
	spread.chain().tween_callback(queue_free)
