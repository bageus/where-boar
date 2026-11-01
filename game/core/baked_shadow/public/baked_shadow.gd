extends RefCounted

## Baked sun shadows (owner, 2026-11-01: the sun never moves, so static things need no live shadow).
## The static meshes under the given roots stop casting live shadows; one render of their silhouettes
## along the sun becomes a texture the ground shaders darken by (baked_shadow.gdshaderinc). Only moving
## things (the hunter, boars, thrown gear) keep live shadows.

const VertexGround = preload("res://game/core/baked_shadow/public/vertex_ground.gdshader")
const BakeSilhouette = preload("res://game/core/baked_shadow/public/bake_silhouette.gdshader")
const RESOLUTION := 2048
const STRENGTH := 0.45  # how much a baked shadow darkens the ground


## A ground material for vertex-coloured meshes that shows the baked shadows.
static func vertex_ground() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = VertexGround
	return material


## Bakes the shadows of the static meshes under roots onto the ground square of side size around centre,
## leaving out their parts below min_y. The render happens on the next frame, of copies in a world of their
## own; the texture lives as long as the returned viewport (a child of host).
static func bake(host: Node, sun: DirectionalLight3D, roots: Array[Node], centre: Vector3, size: float, min_y := -100000.0) -> SubViewport:
	var silhouette := ShaderMaterial.new()
	silhouette.shader = BakeSilhouette
	silhouette.set_shader_parameter("min_y", min_y)
	var copies: Array[GeometryInstance3D] = []
	for root in roots:
		for node: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
			if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or _receives(node):
				continue
			var copy: GeometryInstance3D
			if node is MeshInstance3D:
				copy = MeshInstance3D.new()
				copy.mesh = node.mesh
			elif node is MultiMeshInstance3D:
				copy = MultiMeshInstance3D.new()
				copy.multimesh = node.multimesh
			else:
				continue
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.transform = node.global_transform
			copy.material_override = silhouette
			copies.append(copy)
	var viewport := SubViewport.new()
	viewport.size = Vector2i.ONE * RESOLUTION
	viewport.own_world_3d = true
	viewport.transparent_bg = true  # alpha = something stands between the ground and the sun
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size * 1.42  # the square seen slanted along the sun still fits
	camera.far = 2000.0
	camera.environment = Environment.new()  # a clear background, so it stays transparent
	camera.transform = Transform3D(sun.global_basis.orthonormalized(), centre + sun.global_basis.z.normalized() * 800.0)
	viewport.add_child(camera)
	for copy in copies:
		viewport.add_child(copy)
	host.add_child(viewport)
	# World point -> texture uv: camera space scaled to 0..1, y down as in the image.
	var to_uv := Transform3D(Basis(Vector3(1.0 / camera.size, 0, 0), Vector3(0, -1.0 / camera.size, 0), Vector3(0, 0, 1)), Vector3(0.5, 0.5, 0.0))
	RenderingServer.global_shader_parameter_set("baked_shadow", viewport.get_texture())
	RenderingServer.global_shader_parameter_set("baked_shadow_view", Projection(to_uv * camera.transform.affine_inverse()))
	RenderingServer.global_shader_parameter_set("baked_shadow_strength", STRENGTH)
	viewport.tree_exiting.connect(func() -> void: RenderingServer.global_shader_parameter_set("baked_shadow_strength", 0.0))
	return viewport


## The ground itself: a mesh drawn with a shader that shows baked shadows would shade itself all over.
static func _receives(node: GeometryInstance3D) -> bool:
	var material := node.material_override
	if material == null and node is MeshInstance3D and node.mesh and node.mesh.get_surface_count() > 0:
		material = node.mesh.surface_get_material(0)
	return material is ShaderMaterial and material.shader and material.shader.code.contains("baked_shadow_at")
