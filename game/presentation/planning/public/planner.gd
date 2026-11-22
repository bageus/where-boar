extends Node3D

## Planning mode (issue #29): a free camera over a level. Click an object to pick it, drag it over the ground,
## raise, turn, scale, copy or delete it with keys, add new ones from the palette, then save the layout:
## the level applies it whenever it is played. The level (injected) answers planning_targets(),
## planning_parent(), planning_centre(), planning_palette() and planning_removable(node).

const LevelLayout = preload("res://game/core/level_layout/public/level_layout.gd")

## Fact: the player saved; data is the layout to store.
signal saved(data: Dictionary)
## Fact: the player asked to throw the stored layout away.
signal reset_requested
signal closed

const SPEED := 15.0
const FAST := 5.0
const LOOK := 0.003
const STEP := 0.25
const TURN := PI / 12.0
const GROW := 1.1
## An object without a collision (fern, zone) is picked within this many metres of the clicked ground.
const PICK_REACH := 2.5
## Tall-grass and bush cover (terrain.gd COVER_LAYER) is not ground and holds nothing to pick.
const RAY_MASK := 0xFFFFFFFF & ~(1 << 4)
const HELP := "Fly: WASD, Q/E down/up, Shift faster, hold RMB to look.  LMB: pick and drag over the ground.\n" \
		+ "Up/Down: raise/lower.  Left/Right: turn (Shift: 90°).  +/-: size.  Ctrl+D: copy.  Del: delete.  Esc: drop.  Ctrl+S: save."

var level: Node3D

var _camera := Camera3D.new()
var _yaw := 0.0
var _pitch := -0.6
var _targets: Array[Node] = []
var _removed: Array = []
var _selected: Node3D
var _box := MeshInstance3D.new()
var _dragging := false
## The picked object's height over the ground under it, kept while dragging.
var _lift := 0.0
var _palette_entries: Array[Dictionary] = []
var _palette := ItemList.new()
var _status := Label.new()


func _ready() -> void:
	_targets = level.planning_targets()
	for node in _targets:
		if node is Node3D and not node.has_meta(LevelLayout.START_META):
			node.set_meta(LevelLayout.START_META, node.transform)
	_camera.far = 2000.0
	add_child(_camera)
	_camera.make_current()
	to_centre()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.85, 0.2, 0.25)
	material.no_depth_test = true
	_box.mesh = BoxMesh.new()
	_box.material_override = material
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box.top_level = true
	_box.visible = false
	add_child(_box)
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 8)
	ui.add_child(bar)
	for pair in [["Save", save], ["Export (copy JSON)", _export], ["Reset level", reset_requested.emit],
			["To centre", to_centre], ["Exit", closed.emit]]:
		var button := Button.new()
		button.text = pair[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(pair[1])
		bar.add_child(button)
	_status.position = Vector2(8, 48)
	ui.add_child(_status)
	_palette.position = Vector2(8, 80)
	_palette.size = Vector2(220, 520)
	_palette.focus_mode = Control.FOCUS_NONE
	_palette_entries = level.planning_palette()
	for entry in _palette_entries:
		_palette.add_item(entry["name"])
	ui.add_child(_palette)
	var help := Label.new()
	help.text = HELP
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 8.0
	help.offset_top = -56.0
	ui.add_child(help)
	_say("Pick an object, or choose one in the list and click the ground to add it.")


func _say(text: String) -> void:
	_status.text = text


func to_centre() -> void:
	var centre: Vector3 = level.planning_centre()
	_yaw = 0.0
	_pitch = -0.6
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)
	_camera.global_position = centre + _camera.global_basis.z * 30.0


func save() -> void:
	saved.emit(LevelLayout.capture(level, _targets, _removed))
	_say("Saved: the level now plays with this layout.")


func _export() -> void:
	DisplayServer.clipboard_set(JSON.stringify(LevelLayout.capture(level, _targets, _removed), "\t"))
	_say("Layout copied to the clipboard as JSON.")


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	for pair in [[KEY_W, Vector3.FORWARD], [KEY_S, Vector3.BACK], [KEY_A, Vector3.LEFT], [KEY_D, Vector3.RIGHT]]:
		if Input.is_physical_key_pressed(pair[0]):
			move += _camera.global_basis * pair[1]
	move.y += float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if not Input.is_key_pressed(KEY_CTRL) and move != Vector3.ZERO:
		_camera.global_position += move.normalized() * SPEED * (FAST if Input.is_key_pressed(KEY_SHIFT) else 1.0) * delta
	if is_instance_valid(_selected):
		var bounds := _bounds(_selected)
		_box.global_transform = Transform3D(Basis.from_scale(bounds.size), bounds.get_center())
	_box.visible = is_instance_valid(_selected)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if button.pressed else Input.MOUSE_MODE_VISIBLE
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false
			if button.pressed:
				_click(button.position)
	elif event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x * LOOK
			_pitch = clampf(_pitch - event.relative.y * LOOK, -1.5, 1.5)
			_camera.rotation = Vector3(_pitch, _yaw, 0.0)
		elif _dragging and is_instance_valid(_selected):
			var hit := _ray(event.position, _bodies(_selected))
			if hit:
				_selected.global_position = hit.position + Vector3.UP * _lift
	elif event is InputEventKey and event.pressed:
		_key(event as InputEventKey)


func _click(at: Vector2) -> void:
	var hit := _ray(at)
	var chosen := _palette.get_selected_items()
	if not chosen.is_empty():
		_palette.deselect_all()
		if hit:
			_add(_palette_entries[chosen[0]], hit.position)
		return
	_pick(_find(hit))
	if _selected:
		_dragging = true
		var below := _ray_down(_selected)
		_lift = _selected.global_position.y - below.position.y if below else 0.0


func _key(key: InputEventKey) -> void:
	var shift := key.shift_pressed
	if key.ctrl_pressed and key.keycode == KEY_S:
		save()
	elif key.keycode == KEY_ESCAPE:
		_pick(null)
		_palette.deselect_all()
	elif not is_instance_valid(_selected):
		return
	elif key.ctrl_pressed and key.keycode == KEY_D:
		_copy()
	elif key.keycode in [KEY_UP, KEY_PAGEUP]:
		_selected.global_position.y += STEP * (4.0 if shift else 1.0)
	elif key.keycode in [KEY_DOWN, KEY_PAGEDOWN]:
		_selected.global_position.y -= STEP * (4.0 if shift else 1.0)
	elif key.keycode in [KEY_LEFT, KEY_RIGHT]:
		_selected.global_rotate(Vector3.UP, (PI / 2.0 if shift else TURN) * (1.0 if key.keycode == KEY_LEFT else -1.0))
	elif key.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
		_selected.scale *= GROW
	elif key.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
		_selected.scale /= GROW
	elif key.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_delete()


func _pick(node: Node3D) -> void:
	_selected = node
	_say("Picked %s" % node.name if node else "")


## The object a ray hit belongs to, else the nearest object to the hit point (things with no collision).
func _find(hit: Dictionary) -> Node3D:
	if hit.is_empty():
		return null
	var node: Node = hit.collider
	while node and node != level:
		if node in _targets:
			return node
		node = node.get_parent()
	var best: Node3D = null
	var best_d := PICK_REACH
	for target in _targets:
		if is_instance_valid(target) and target is Node3D:
			var d := Vector2(target.global_position.x - hit.position.x, target.global_position.z - hit.position.z).length()
			if d < best_d:
				best_d = d
				best = target
	return best


func _add(entry: Dictionary, at: Vector3) -> void:
	var node := LevelLayout.make(entry["res"], entry["solid"])
	if node == null:
		_say("Cannot load %s" % entry["res"])
		return
	node.name = "Planned%d" % (Time.get_ticks_usec() % 100000000)  # unique; a map tree picks its model by name
	level.planning_parent().add_child(node)
	node.global_position = at
	_targets.append(node)
	_pick(node)


func _copy() -> void:
	var res: String = _selected.get_meta(LevelLayout.ADDED_META)["res"] if _selected.has_meta(LevelLayout.ADDED_META) \
			else _selected.scene_file_path
	var solid: String = _selected.get_meta(LevelLayout.ADDED_META, {}).get("solid", "")
	var node := LevelLayout.make(res, solid) if res != "" else null
	if node == null:
		_say("%s cannot be copied" % _selected.name)
		return
	node.name = "Planned%d" % (Time.get_ticks_usec() % 100000000)
	_selected.get_parent().add_child(node)
	node.global_transform = _selected.global_transform.translated(_camera.global_basis.x * 2.0)
	_targets.append(node)
	_pick(node)


func _delete() -> void:
	if not level.planning_removable(_selected):
		_say("%s is part of the level: move it instead" % _selected.name)
		return
	if not _selected.has_meta(LevelLayout.ADDED_META):
		_removed.append(String(level.get_path_to(_selected)))
	_targets.erase(_selected)
	_selected.queue_free()
	_pick(null)


func _ray(at: Vector2, exclude: Array[RID] = []) -> Dictionary:
	var from := _camera.project_ray_origin(at)
	var query := PhysicsRayQueryParameters3D.create(from, from + _camera.project_ray_normal(at) * 2000.0, RAY_MASK, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _ray_down(node: Node3D) -> Dictionary:
	var top := node.global_position + Vector3.UP * 200.0
	var query := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 400.0, RAY_MASK, _bodies(node))
	return get_world_3d().direct_space_state.intersect_ray(query)


## Collision bodies of node and its children, so a ray from the camera finds the ground behind it.
func _bodies(node: Node) -> Array[RID]:
	var rids: Array[RID] = []
	for body in [node] + node.find_children("*", "CollisionObject3D", true, false):
		if body is CollisionObject3D:
			rids.append((body as CollisionObject3D).get_rid())
	return rids


func _bounds(node: Node3D) -> AABB:
	var box := AABB(node.global_position, Vector3.ZERO)
	for visual in [node] + node.find_children("*", "VisualInstance3D", true, false):
		if visual is VisualInstance3D:
			box = box.merge(visual.global_transform * (visual as VisualInstance3D).get_aabb())
	return box.grow(0.1)
