class_name DefenseControllerInput
extends Node
## Native Godot joypad events: grid navigation plus a right-stick UI cursor.
## Consume controller events before Control's built-in ui_* handling so one
## physical press cannot activate a menu and plant a number underneath it.
signal action_pressed(action: String)
signal navigated(direction: Vector2i)
signal activity()
signal controller_lost()
signal pointer_activity()
signal pointer_axis_changed(axis: Vector2)
signal pointer_button_changed(source: String, pressed: bool)
signal pointer_precision_changed(pressed: bool)
signal pointer_reset()

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
const POINTER_DEADZONE := 0.20
const TRIGGER_PRESS := 0.55
const TRIGGER_RELEASE := 0.35
var active_device: int = -1
var _axis := Vector2.ZERO
var _pad := Vector2i.ZERO
var _direction := Vector2i.ZERO
var _repeat: float = 0.0
var _right_axis := Vector2.ZERO
var _pointer_buttons: Dictionary = {"stick":false,"trigger":false}
var _precision := false
var _window_focused := true

func _ready() -> void:
	Input.joy_connection_changed.connect(_connection_changed)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty(): active_device = devices[0]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_window_focused = false
		reset_navigation()
		reset_pointer()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true

func _connection_changed(device: int, connected: bool) -> void:
	if connected:
		if active_device < 0: active_device = device
	elif device == active_device:
		active_device = -1
		reset_navigation()
		reset_pointer()
		controller_lost.emit()

func reset_navigation() -> void:
	_axis = Vector2.ZERO
	_pad = Vector2i.ZERO
	_direction = Vector2i.ZERO
	_repeat = 0.0

func _claim(device: int) -> void:
	if active_device != device:
		reset_navigation()
		reset_pointer()
		active_device = device
	reset_pointer(false)
	activity.emit()

func reset_pointer(notify: bool = true) -> void:
	_right_axis = Vector2.ZERO
	_pointer_buttons = {"stick":false,"trigger":false}
	_precision = false
	if notify: pointer_reset.emit()

func _claim_pointer(device: int) -> void:
	if active_device != device:
		reset_pointer()
		active_device = device
	reset_navigation()
	pointer_activity.emit()

func _set_pointer_button(source: String, pressed: bool) -> void:
	if bool(_pointer_buttons[source]) == pressed: return
	_pointer_buttons[source] = pressed
	pointer_button_changed.emit(source,pressed)

func _input(event: InputEvent) -> void:
	if not _window_focused and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_RIGHT_STICK:
			get_viewport().set_input_as_handled()
			if event.pressed: _claim_pointer(event.device)
			elif active_device != event.device: return
			_set_pointer_button("stick",event.pressed)
			get_viewport().set_input_as_handled()
			return
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
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		get_viewport().set_input_as_handled()
		var axis: Vector2 = _right_axis if active_device == event.device or active_device < 0 else Vector2.ZERO
		if event.axis == JOY_AXIS_RIGHT_X: axis.x = event.axis_value
		else: axis.y = event.axis_value
		if axis.length() >= POINTER_DEADZONE: _claim_pointer(event.device)
		elif active_device >= 0 and active_device != event.device: return
		_right_axis = axis
		pointer_axis_changed.emit(_right_axis)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_RIGHT,JOY_AXIS_TRIGGER_LEFT]:
		get_viewport().set_input_as_handled()
		var old: bool = (bool(_pointer_buttons.trigger) if event.axis == JOY_AXIS_TRIGGER_RIGHT else _precision) if active_device == event.device else false
		var pressed: bool = event.axis_value >= (TRIGGER_RELEASE if old else TRIGGER_PRESS)
		if pressed and not old: _claim_pointer(event.device)
		elif active_device != event.device: return
		if event.axis == JOY_AXIS_TRIGGER_RIGHT: _set_pointer_button("trigger",pressed)
		elif _precision != pressed:
			_precision = pressed
			pointer_precision_changed.emit(pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		get_viewport().set_input_as_handled()
		if absf(event.axis_value) >= DEADZONE: _claim(event.device)
		elif active_device != event.device: return
		if event.axis == JOY_AXIS_LEFT_X: _axis.x = event.axis_value
		else: _axis.y = event.axis_value
		_update_direction()
		get_viewport().set_input_as_handled()

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
	if not _window_focused or _direction == Vector2i.ZERO: return
	_repeat -= delta
	if _repeat <= 0:
		_repeat = REPEAT_INTERVAL
		navigated.emit(_direction)
