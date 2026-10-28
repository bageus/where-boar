extends RefCounted

## Pulsing outline on things the hunter can pick up (owner, 2026-10-28): an inverted-hull overlay
## on the item's meshes, switched on only for items near the hunter.

static var _material: ShaderMaterial


static func set_on(item: Node, on: bool) -> void:
	if _material == null:
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;
void vertex() { VERTEX += NORMAL * 0.05; }
void fragment() { ALBEDO = vec3(1.0, 0.85, 0.3); ALPHA = 0.55 + 0.35 * sin(TIME * 5.0); }"""
		_material = ShaderMaterial.new()
		_material.shader = shader
	for mesh: Node in item.find_children("*", "MeshInstance3D"):
		mesh.material_overlay = _material if on else null
