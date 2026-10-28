extends Node3D

## Low-poly boar from assets/models/boar.glb (tools/build_models.py); the "hide" surface takes a boar type's colour.


func paint(color: Color) -> void:
	var hide := StandardMaterial3D.new()
	hide.albedo_color = color
	hide.roughness = 0.9
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_material(i).resource_name == "hide":
				mesh.set_surface_override_material(i, hide)
