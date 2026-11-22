extends Node3D

## Planning mode (issue #29): a free camera over a level. Click an object to pick it, drag it over the ground,
## raise, turn, scale, copy or delete it with keys, add new ones from the palette, then save the layout:
## the level applies it whenever it is played. The level (injected) answers planning_targets(),
## planning_parent(), planning_centre(), planning_palette() and planning_removable(node); a level with
## planning_terrain() also gets the ground brush (raise, lower, flatten), its heights saved with the layout.

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
## Ground brush: metres a second at the centre, share a second for flatten, radius range and redraw period.
const SCULPT_RATE := 2.0
const FLATTEN_RATE := 3.0
const RADIUS_RANGE := Vector2(2.0, 30.0)
const REDRAW_SECONDS := 0.15
const HELP := "Fly: WASD, Q/E down/up, Shift faster, hold RMB to look.  LMB: pick and drag over the ground.\n" \
		+ "Up/Down: raise/lower.  Left/Right: turn (Shift: 90°).  +/-: size.  Ctrl+D: copy.  Del: delete.  Esc: drop.  Ctrl+S: save.\n" \
		+ "Ground brush: hold LMB to shape, [ / ] brush size; objects under it ride along."

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
var _terrain: Node3D
## "" picks objects; else "raise", "lower" or "flatten".
var _brush := ""
var _radius := 6.0
var _ring := MeshInstance3D.new()
var _sculpting := false
## Flatten pulls the ground to the height first clicked.
var _flat_y := 0.0
var _redraw_left := 0.0
## Colliders the brush looks through, gathered when a brush is chosen.
var _see_through: Array[RID] = []


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
	_terrain = level.planning_terrain() if level.has_method("planning_terrain") else null
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.2
	_ring.mesh = disc
	_ring.material_override = material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var bar := HBoxContainer.new()
	bar.position = Vector2(8, 8)
	ui.add_child(bar)
	for pair in [["Save", save], ["Export (copy JSON)", _export], ["Reset level", reset_requested.emit],
			["To centre", to_centre], ["Exit", closed.emit]] + ([["Objects", _use_brush.bind("")], ["Raise", _use_brush.bind("raise")],
			["Lower", _use_brush.bind("lower")], ["Flatten", _use_brush.bind("flatten")]] if _terrain else []):
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
	help.offset_top = -80.0
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


func _use_brush(brush: String) -> void:
	_brush = brush
	_see_through = _target_bodies() if brush != "" else []
	_pick(null)
	_palette.deselect_all()
	_say("Ground brush: %s. Hold LMB on the ground." % brush if brush != "" else "Pick an object.")


func _layout() -> Dictionary:
	var data := LevelLayout.capture(level, _targets, _removed)
	if _terrain:
		data["heights"] = _terrain.height_edits.duplicate()
	return data


func save() -> void:
	saved.emit(_layout())
	_say("Saved: the level now plays with this layout.")


func _export() -> void:
	DisplayServer.clipboard_set(JSON.stringify(_layout(), "\t"))
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
	_brush_tick(delta)


## Moves the brush disc to the ground under the mouse and shapes the ground while LMB is held.
func _brush_tick(delta: float) -> void:
	var hit := _ray(get_viewport().get_mouse_position(), _see_through) if _brush != "" else {}
	_ring.visible = not hit.is_empty()
	if hit.is_empty():
		return
	_ring.global_transform = Transform3D(Basis.from_scale(Vector3(_radius, 1.0, _radius)), hit.position)
	_redraw_left -= delta
	if not _sculpting:
		return
	sculpt(hit.position, delta)
	if _redraw_left <= 0.0:
		_redraw_left = REDRAW_SECONDS
		_terrain.rebuild()


## One brush step at a ground point; objects under the brush keep their height over the ground.
func sculpt(at: Vector3, delta: float) -> void:
	var riders := {}
	for target in _targets:
		if is_instance_valid(target) and target is Node3D \
				and Vector2(target.global_position.x - at.x, target.global_position.z - at.z).length() < _radius + 1.0:
			riders[target] = _terrain.height_at(target.global_position.x, target.global_position.z)
	match _brush:
		"raise": _terrain.sculpt(at, _radius, SCULPT_RATE * delta)
		"lower": _terrain.sculpt(at, _radius, -SCULPT_RATE * delta)
		"flatten": _terrain.sculpt(Vector3(at.x, _flat_y, at.z), _radius, FLATTEN_RATE * delta, true)
	for target: Node3D in riders:
		target.global_position.y += _terrain.height_at(target.global_position.x, target.global_position.z) - riders[target]


## Colliders of the level's objects: the brush looks through them to the ground.
func _target_bodies() -> Array[RID]:
	var rids: Array[RID] = []
	for target in _targets:
		if is_instance_valid(target):
			rids.append_array(_bodies(target))
	return rids


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if button.pressed else Input.MOUSE_MODE_VISIBLE
		elif button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = false
			if _brush != "":
				_sculpting = button.pressed
				var hit := _ray(button.position, _see_through) if button.pressed else {}
				_flat_y = hit.position.y if hit else _flat_y
				if not button.pressed:
					_terrain.rebuild()
			elif button.pressed:
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
	elif key.keycode in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		_radius = clampf(_radius * (0.8 if key.keycode == KEY_BRACKETLEFT else 1.25), RADIUS_RANGE.x, RADIUS_RANGE.y)
		_say("Brush size %.0f m" % _radius)
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
