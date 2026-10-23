class_name DefenseControllerInput
extends Node
## Native Godot joypad events: standard gamepad layout, no mouse emulation.
## Consume controller events before Control's built-in ui_* handling so one
## physical press cannot activate a menu and plant a number underneath it.
signal action_pressed(action: String)
signal navigated(direction: Vector2i)
signal activity()
signal controller_lost()

const BUTTONS: Dictionary = {
	JOY_BUTTON_A: "confirm", JOY_BUTTON_B: "cancel",
	JOY_BUTTON_X: "gear", JOY_BUTTON_Y: "advance",
	JOY_BUTTON_LEFT_SHOULDER: "previous", JOY_BUTTON_RIGHT_SHOULDER: "next",
	JOY_BUTTON_START: "pause", JOY_BUTTON_BACK: "help",
}
const DPAD: Dictionary = {
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
	JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
}
const DEADZONE := 0.55
const RELEASE_ZONE := 0.30
const INITIAL_REPEAT := 0.30
const REPEAT_INTERVAL := 0.12
var active_device: int = -1
var _axis := Vector2.ZERO
var _pad := Vector2i.ZERO
var _direction := Vector2i.ZERO
var _repeat: float = 0.0

func _ready() -> void:
	Input.joy_connection_changed.connect(_connection_changed)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty(): active_device = devices[0]

func _connection_changed(device: int, connected: bool) -> void:
	if connected:
		if active_device < 0: active_device = device
	elif device == active_device:
		active_device = -1
		reset_navigation()
		controller_lost.emit()

func reset_navigation() -> void:
	_axis = Vector2.ZERO
	_pad = Vector2i.ZERO
	_direction = Vector2i.ZERO
	_repeat = 0.0

func _claim(device: int) -> void:
	if active_device != device:
		reset_navigation()
		active_device = device
	activity.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if not BUTTONS.has(event.button_index) and not DPAD.has(event.button_index): return
		get_viewport().set_input_as_handled()
		if event.pressed: _claim(event.device)
		elif active_device != event.device: return
		if DPAD.has(event.button_index):
			var step: Vector2i = DPAD[event.button_index]
			if event.pressed: _pad = step
			elif _pad == step: _pad = Vector2i.ZERO
			_update_direction()
		elif event.pressed:
			action_pressed.emit(str(BUTTONS[event.button_index]))
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		get_viewport().set_input_as_handled()
		if absf(event.axis_value) >= DEADZONE: _claim(event.device)
		elif active_device != event.device: return
		if event.axis == JOY_AXIS_LEFT_X: _axis.x = event.axis_value
		else: _axis.y = event.axis_value
		_update_direction()

func _update_direction() -> void:
	var next: Vector2i = _pad
	if next == Vector2i.ZERO:
		if maxf(absf(_axis.x),absf(_axis.y)) >= DEADZONE:
			next = Vector2i(signi(int(_axis.x*100)),0) if absf(_axis.x)>absf(_axis.y) else Vector2i(0,signi(int(_axis.y*100)))
		elif maxf(absf(_axis.x),absf(_axis.y)) > RELEASE_ZONE and _direction != Vector2i.ZERO:
			next = _direction
	if next != _direction:
		_direction = next
		_repeat = INITIAL_REPEAT
		if next != Vector2i.ZERO: navigated.emit(next)

func _process(delta: float) -> void:
	if _direction == Vector2i.ZERO: return
	_repeat -= delta
	if _repeat <= 0:
		_repeat = REPEAT_INTERVAL
		navigated.emit(_direction)
