extends CanvasLayer

## Pause menu (section 16): continue, settings (FOV, mouse sensitivity, camera motion), quit to the start screen.
## Runs while the tree is paused.

signal resumed
signal quit_requested
## Fact: the player changed a setting; settings is the whole dictionary.
signal settings_changed(settings: Dictionary)

var _settings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	%Continue.pressed.connect(resumed.emit)
	%Quit.pressed.connect(quit_requested.emit)
	%Fov.value_changed.connect(func(value: float) -> void: _change("fov", value))
	%Sensitivity.value_changed.connect(func(value: float) -> void: _change("mouse_sensitivity", value / 1000.0))
	%CameraMotion.toggled.connect(func(on: bool) -> void: _change("camera_motion", on))


func open(settings: Dictionary) -> void:
	_settings = settings.duplicate()
	%Fov.set_value_no_signal(settings["fov"])
	%Sensitivity.set_value_no_signal(settings["mouse_sensitivity"] * 1000.0)
	%CameraMotion.set_pressed_no_signal(settings["camera_motion"])
	show()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resumed.emit()


func _change(key: String, value: Variant) -> void:
	_settings[key] = value
	settings_changed.emit(_settings.duplicate())
