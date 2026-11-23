extends RefCounted

## A procedural cord (bowstring, slingshot band): a thin cylinder stretched between two points.


static func make(parent: Node3D, radius: float, colour: Color) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 1.0
	cylinder.radial_segments = 6
	cylinder.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	cylinder.material = material
	var strand := MeshInstance3D.new()
	strand.mesh = cylinder
	parent.add_child(strand)
	return strand


## from and to in the parent's space; to should lie roughly above from (the arc from +Y is undefined downwards).
static func stretch(strand: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var basis := Basis(Quaternion(Vector3.UP, along.normalized()))
	basis.y *= along.length()
	strand.transform = Transform3D(basis, (from + to) / 2.0)
