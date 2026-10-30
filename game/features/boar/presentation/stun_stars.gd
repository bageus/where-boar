extends Node3D

## Cartoon stars circling over a stunned boar's head (owner, 2026-10-30).

const COUNT := 5
const RADIUS := 0.35
const TURNS_PER_SECOND := 0.8
const STAR_SIZE := 0.09


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.85, 0.1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var star := _star_mesh()
	star.surface_set_material(0, material)
	for i in COUNT:
		var mesh := MeshInstance3D.new()
		mesh.mesh = star
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.position = Vector3.RIGHT.rotated(Vector3.UP, TAU * i / COUNT) * RADIUS
		add_child(mesh)


func _process(delta: float) -> void:
	rotate_y(TAU * TURNS_PER_SECOND * delta)


## A flat five-pointed star facing +z.
static func _star_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		for corner: int in [i, i + 1]:
			var r := STAR_SIZE if corner % 2 == 0 else STAR_SIZE * 0.45
			var a := TAU * corner / 10.0
			tool.add_vertex(Vector3(sin(a) * r, cos(a) * r, 0.0))
		tool.add_vertex(Vector3.ZERO)
	return tool.commit()
