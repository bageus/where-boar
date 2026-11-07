extends Node3D

## A ring that spreads from the hunter to the shout's reach and fades (owner, 2026-10-27). It is drawn as an
## overlay on everything it passes, not only the ground: trees, stumps, rocks, logs, bushes; grass is left out
## (owner, 2026-11-07). Only meshes whose bounds reach the circle get the extra pass, and only for SECONDS.

const SECONDS := 0.6
const SHADER := preload("res://game/presentation/hunt_map/props/shout_wave.gdshader")
const WHEAT := preload("res://assets/nature/meshes/Wheat.res")

## Set by the map before the wave enters the tree: the shout's reach in metres.
var radius := 15.0
## Set by the map: the nodes whose meshes the wave runs over.
var surfaces: Array[Node] = []


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("centre", global_position)
	material.set_shader_parameter("radius", 0.0)  # tweens need the parameters set first
	material.set_shader_parameter("alpha", 0.6)
	var covered: Array[GeometryInstance3D] = []
	var reach := AABB(global_position - Vector3(radius, 1000.0, radius), Vector3(radius, 1000.0, radius) * 2.0)
	for root in surfaces:
		for node: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
			if node.material_overlay == null and not _grass(node) and reach.intersects(node.global_transform * node.get_aabb()):
				node.material_overlay = material
				covered.append(node)
	var spread := create_tween().set_parallel()
	spread.tween_property(material, "shader_parameter/radius", radius, SECONDS)
	spread.tween_property(material, "shader_parameter/alpha", 0.0, SECONDS).set_ease(Tween.EASE_IN)
	spread.chain().tween_callback(func() -> void:
		for node in covered:
			if is_instance_valid(node) and node.material_overlay == material:
				node.material_overlay = null
		queue_free())


func _grass(node: GeometryInstance3D) -> bool:
	var shader := (node.material_override as ShaderMaterial).shader if node.material_override is ShaderMaterial else null
	if shader and shader.resource_path.ends_with("grass.gdshader"):
		return true
	return node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh.mesh == WHEAT
