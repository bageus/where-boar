class_name Wind
extends RefCounted

## Wind in the woods: swaps the vertex-coloured material of the PEAK trees and bushes for foliage_sway.gdshader
## (the meshes are shared resources, so every MultiMesh and node using them sways). Idempotent.

const SHADER := preload("res://game/core/sun_fx/public/foliage_sway.gdshader")
const MESHES: Array[Mesh] = [
	preload("res://assets/nature/meshes/peak/PeakTree1.res"), preload("res://assets/nature/meshes/peak/PeakTree2.res"),
	preload("res://assets/nature/meshes/peak/PeakTree3.res"), preload("res://assets/nature/meshes/peak/PeakTree4.res"),
	preload("res://assets/nature/meshes/peak/PeakPine1.res"), preload("res://assets/nature/meshes/peak/PeakPine2.res"),
	preload("res://assets/nature/meshes/peak/PeakPine3.res"), preload("res://assets/nature/meshes/peak/PeakPalm1.res"),
	preload("res://assets/nature/meshes/peak/PeakPalm2.res"), preload("res://assets/nature/meshes/peak/PeakPalm3.res"),
	preload("res://assets/nature/meshes/peak/PeakBush1.res"), preload("res://assets/nature/meshes/peak/PeakBush2.res"),
	preload("res://assets/nature/meshes/peak/PeakBush3.res"), preload("res://assets/nature/meshes/peak/PeakShrub1.res"),
	preload("res://assets/nature/meshes/peak/PeakShrub2.res"), preload("res://assets/nature/meshes/peak/PeakShrub3.res"),
]

static var _materials: Array[ShaderMaterial] = []  # [back-face culled, two-sided]


static func apply(strength: float) -> void:
	if _materials.is_empty():
		var two_sided := Shader.new()
		two_sided.code = SHADER.code.replace("cull_back", "cull_disabled")
		for shader: Shader in [SHADER, two_sided]:
			var material := ShaderMaterial.new()
			material.shader = shader
			_materials.append(material)
		for mesh in MESHES:
			var old := mesh.surface_get_material(0) as BaseMaterial3D
			mesh.surface_set_material(0, _materials[1 if old and old.cull_mode == BaseMaterial3D.CULL_DISABLED else 0])
	for material in _materials:
		material.set_shader_parameter("strength", strength)
