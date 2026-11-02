extends SceneTree

## Camp placement clearance: bushes, ferns, display traps and rim rocks must not stand inside a
## building's footprint (or a display trap inside a rock). Boxes are in the camp's XZ plane.

const CampScene = preload("res://game/presentation/camp/public/camp.tscn")
const Progress = preload("res://game/features/settlement/public/progress.gd")
const ShopDisplay = preload("res://game/presentation/camp/props/shop_display.gd")

var _camp: Node3D
var _frame := 0
var _failures := 0


func _initialize() -> void:
	_camp = CampScene.instantiate()
	_camp.progress = Progress.from_dict({})
	root.add_child(_camp)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	var boxes := {}
	for path in ["LargeTent", "AFrameTent", "RoundTent", "RoundTent2", "Stations/WeaponShop", "Stations/HuntingHut", "Stations/Tavern", "Stations/Well"]:
		boxes[path] = _footprint(_camp.get_node(path))
	var keys := boxes.keys()
	for a in keys.size():
		for b in range(a + 1, keys.size()):
			# The round tents' boxes are loose at the corners: compare their inner 60 %.
			if boxes[keys[a]].grow(-boxes[keys[a]].size.x * 0.2).intersects(boxes[keys[b]].grow(-boxes[keys[b]].size.x * 0.2)):
				_fail("buildings overlap: %s / %s" % [keys[a], keys[b]])
	for t: Array in ShopDisplay.TRAP_SPOTS:
		var trap := _trap_rect(t)
		for key in keys:
			if boxes[key].intersects(trap):
				_fail("trap %s inside %s" % [t[0], key])
		for rock: Rect2 in _camp.get_node("Scenery").rim_rocks:
			if rock.intersects(trap):
				_fail("trap %s inside a rim rock at %s" % [t[0], rock.get_center()])
	for plant: Rect2 in _camp.get_node("Dressing").plant_boxes:
		for key in keys:
			if boxes[key].intersects(plant):
				_fail("plant at %s inside %s" % [plant.get_center(), key])
		for rock: Rect2 in _camp.get_node("Scenery").rim_rocks:
			if rock.intersects(plant):
				_fail("plant at %s inside a rim rock" % plant.get_center())
	for rock: Rect2 in _camp.get_node("Scenery").rim_rocks:
		print("ROCK ", rock.position.x, " ", rock.position.y, " ", rock.size.x, " ", rock.size.y)
	print("camp clearance: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)
	return true


func _footprint(building: Node3D) -> Rect2:
	var box := Rect2()
	var first := true
	for mesh: MeshInstance3D in building.find_children("*", "MeshInstance3D", true, false):
		if ShopDisplay in _scripts(mesh):
			continue
		var world := mesh.global_transform * mesh.get_aabb()
		var rect := Rect2(world.position.x, world.position.z, world.size.x, world.size.z)
		box = rect if first else box.merge(rect)
		first = false
	return box


## The display trap's real ground footprint, from its meshes placed as shop_display.gd places them.
func _trap_rect(spot: Array) -> Rect2:
	var model: Node3D = load(ShopDisplay.TRAPS + spot[0] + ".tscn").instantiate()
	model.rotation.y = spot[3]
	model.scale = Vector3.ONE * float(spot[4])
	model.position = Vector3(spot[1], 0.0, spot[2])
	root.add_child(model)
	var box := Rect2()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var world := mesh.global_transform * mesh.get_aabb()
		var rect := Rect2(world.position.x, world.position.z, world.size.x, world.size.z)
		box = rect if first else box.merge(rect)
		first = false
	model.free()
	return box


## True when the mesh belongs to a shop display (its goods are not part of the building).
func _scripts(mesh: Node) -> Array:
	var found := []
	var node := mesh.get_parent()
	while node != null:
		found.append(node.get_script())
		node = node.get_parent()
	return found


func _fail(text: String) -> void:
	_failures += 1
	print("FAIL ", text)
