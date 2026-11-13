class_name DefenseControllerInput
extends Node
## Native Godot joypad events: grid navigation plus a right-stick UI cursor.
## Consume controller events before Control's built-in ui_* handling so one
## physical press cannot activate a menu and plant a number underneath it.
signal action_pressed(action: String)
signal navigated(direction: Vector2i)
signal tower_aim_changed(axis: Vector2)
signal tower_aim_canceled()
signal left_axis_changed(axis: Vector2)
var tower_navigation_allowed: Callable
signal activity()
signal controller_lost()
signal pointer_activity()
signal pointer_axis_changed(axis: Vector2)
signal pointer_button_changed(source: String, pressed: bool)
signal pointer_precision_changed(pressed: bool)
signal pointer_reset()

const Bindings = preload("res://scripts/controller_bindings.gd")
signal binding_captured(token: String)
signal capture_canceled()
var bindings: Dictionary = Bindings.DEFAULTS.duplicate()
var settings_mode := false
var capturing := false
var _held: Dictionary = {}
var _blocked: Dictionary = {}
var _axes_held: Dictionary = {}
var _axes_blocked: Dictionary = {}
var _capture_device := -1

func set_bindings(value: Dictionary) -> void:
	bindings = Bindings.validate(value)
	reset_navigation()
	reset_pointer()
	_blocked = _held.duplicate()
	_axes_blocked = _axes_held.duplicate()

func set_settings_mode(enabled: bool) -> void:
	settings_mode = enabled
	cancel_capture()
	reset_navigation()
	reset_pointer()
	_blocked = _held.duplicate()
	_axes_blocked = _axes_held.duplicate()

func begin_capture() -> void:
	reset_navigation()
	reset_pointer()
	_blocked = _held.duplicate()
	_axes_blocked = _axes_held.duplicate()
	_capture_device = active_device
	capturing = true

func cancel_capture() -> void:
	var was_capturing := capturing
	capturing = false
	_blocked = _held.duplicate()
	_axes_blocked = _axes_held.duplicate()
	reset_navigation()
	reset_pointer()
	if was_capturing: capture_canceled.emit()

func _binding_action(token: String) -> String:
	for action: String in bindings:
		if bindings[action] == token: return action
	return ""

func _dispatch_binding(token: String, pressed: bool, device: int) -> void:
	var action := _binding_action(token)
	if action in ["click","drag","precision"]:
		if pressed: _claim_pointer(device)
		elif active_device != device: return
		if action == "precision":
			_precision = pressed
			pointer_precision_changed.emit(pressed)
		else: _set_pointer_button("stick" if action == "click" else "trigger",pressed)
	elif not action.is_empty():
		if pressed:
			_claim(device)
			action_pressed.emit(action)

const DPAD: Dictionary = {
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
	JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
}
const DEADZONE := 0.55
const RELEASE_ZONE := 0.30
const INITIAL_REPEAT := 0.30
const REPEAT_INTERVAL := 0.12
const STICK_INITIAL_REPEAT := 0.40
const STICK_REPEAT_INTERVAL := 0.18
const AXIS_HYSTERESIS := 0.18
const POINTER_DEADZONE := 0.20
const TRIGGER_PRESS := 0.55
const TRIGGER_RELEASE := 0.35
var active_device: int = -1
var _axis := Vector2.ZERO
var _left_axes: Dictionary = {}
var _tower_mode := false
var _navigation_wait_neutral := false
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
		cancel_capture()
		reset_navigation()
		reset_pointer()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_window_focused = true

func _connection_changed(device: int, connected: bool) -> void:
	if not connected:
		_left_axes.erase(device)
		for states: Dictionary in [_held,_blocked]:
			for key: String in states.keys():
				if key.begins_with(str(device)+"b") or key.begins_with(str(device)+"t"): states.erase(key)
		for states: Dictionary in [_axes_held,_axes_blocked]:
			for key: String in states.keys():
				if key.begins_with(str(device)+":"): states.erase(key)
	if capturing: cancel_capture()
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
	# Cancel a pending gesture; a reset must never commit an aim.
	if tower_navigation_allowed.is_valid(): tower_aim_canceled.emit()

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
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var left: Vector2 = _left_axes.get(event.device,Vector2.ZERO)
		if event.axis == JOY_AXIS_LEFT_X: left.x = event.axis_value
		else: left.y = event.axis_value
		_left_axes[event.device] = left
		# Neutral must be observed even while a menu, capture, or focus block owns input.
		if event.device == active_device or active_device < 0: left_axis_changed.emit(left)
	if capturing and (event is InputEventJoypadButton or event is InputEventJoypadMotion) and _capture_device >= 0 and event.device != _capture_device:
		get_viewport().set_input_as_handled()
		cancel_capture()
		return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y,JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:
		var axis_key := str(event.device)+":"+str(event.axis)
		if absf(event.axis_value) > POINTER_DEADZONE: _axes_held[axis_key] = true
		else: _axes_held.erase(axis_key)
		if _axes_blocked.has(axis_key):
			if absf(event.axis_value) <= POINTER_DEADZONE: _axes_blocked.erase(axis_key)
			get_viewport().set_input_as_handled()
			return
	if capturing and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_LEFT:
		get_viewport().set_input_as_handled()
		cancel_capture()
		return
	if capturing and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel_capture()
		return
	var token := ""
	var pressed := false
	if event is InputEventJoypadButton:
		token = "b%d" % event.button_index
		pressed = event.pressed
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		token = "t%d" % event.axis
		pressed = event.axis_value >= (TRIGGER_RELEASE if _held.has(str(event.device)+token) else TRIGGER_PRESS)
	if not token.is_empty():
		var key := str(event.device)+token
		var was_pressed: bool = _held.has(key)
		if pressed: _held[key] = true
		else: _held.erase(key)
		if not _window_focused:
			if not pressed: _blocked.erase(key)
			else: _blocked[key] = true
			get_viewport().set_input_as_handled()
			return
		if _blocked.has(key):
			if not pressed: _blocked.erase(key)
			get_viewport().set_input_as_handled()
			return
		if capturing:
			get_viewport().set_input_as_handled()
			if pressed and not was_pressed and Bindings.INPUTS.has(token):
				capturing = false
				_blocked = _held.duplicate()
				_axes_blocked = _axes_held.duplicate()
				binding_captured.emit(token)
			return
		if settings_mode and Bindings.INPUTS.has(token):
			get_viewport().set_input_as_handled()
			if pressed and not was_pressed:
				_claim(event.device)
				if token == "b0": action_pressed.emit("confirm")
				elif token in ["b1","b6"]: action_pressed.emit("cancel")
			return
		if Bindings.INPUTS.has(token):
			get_viewport().set_input_as_handled()
			if pressed != was_pressed: _dispatch_binding(token,pressed,event.device)
			return
	if (capturing or not _window_focused) and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()
		return
	if settings_mode and event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		if not DPAD.has(event.button_index): return
		if event.pressed: _claim(event.device)
		elif active_device != event.device: return
		var step: Vector2i = DPAD[event.button_index]
		if event.pressed: _pad = step
		elif _pad == step: _pad = Vector2i.ZERO
		_update_direction()
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
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		get_viewport().set_input_as_handled()
		_sync_navigation_mode()
		var axis: Vector2 = _left_axes.get(event.device,Vector2.ZERO)
		if axis.length() >= DEADZONE: _claim(event.device)
		elif active_device != event.device: return
		_axis = axis
		_update_direction()
		get_viewport().set_input_as_handled()

func _sync_navigation_mode() -> void:
	var enabled: bool = tower_navigation_allowed.is_valid() and tower_navigation_allowed.call()
	if enabled != _tower_mode:
		_tower_mode = enabled
		_navigation_wait_neutral = _navigation_wait_neutral or _axis.length() > RELEASE_ZONE
		_direction = Vector2i.ZERO
		_repeat = 0.0
		tower_aim_canceled.emit()
	if _axis.length() <= RELEASE_ZONE: _navigation_wait_neutral = false

func _update_direction() -> void:
	_sync_navigation_mode()
	if _pad == Vector2i.ZERO and _navigation_wait_neutral: return
	if _pad == Vector2i.ZERO and _tower_mode:
		_direction = Vector2i.ZERO
		_repeat = 0.0
		tower_aim_changed.emit(_axis)
		return
	tower_aim_canceled.emit()
	var next: Vector2i = _pad
	if next == Vector2i.ZERO:
		if maxf(absf(_axis.x),absf(_axis.y)) >= DEADZONE:
			next = Vector2i(signi(int(_axis.x*100)),0) if absf(_axis.x)>absf(_axis.y) else Vector2i(0,signi(int(_axis.y*100)))
			# Keep a cardinal axis through diagonal noise; intentional turns still work.
			if _direction.x != 0 and signf(_axis.x) == float(_direction.x) and absf(_axis.x) >= DEADZONE and absf(_axis.y) < absf(_axis.x)+AXIS_HYSTERESIS:
				next = _direction
			elif _direction.y != 0 and signf(_axis.y) == float(_direction.y) and absf(_axis.y) >= DEADZONE and absf(_axis.x) < absf(_axis.y)+AXIS_HYSTERESIS:
				next = _direction
		elif maxf(absf(_axis.x),absf(_axis.y)) > RELEASE_ZONE and _direction != Vector2i.ZERO:
			next = _direction
	if next != _direction:
		_direction = next
		_repeat = INITIAL_REPEAT if _pad != Vector2i.ZERO else STICK_INITIAL_REPEAT
		if next != Vector2i.ZERO: navigated.emit(next)

func _process(delta: float) -> void:
	_sync_navigation_mode()
	if capturing or not _window_focused or _direction == Vector2i.ZERO: return
	if _pad == Vector2i.ZERO and tower_navigation_allowed.is_valid() and tower_navigation_allowed.call():
		_update_direction()
		return
	_repeat -= delta
	if _repeat <= 0:
		_repeat = REPEAT_INTERVAL if _pad != Vector2i.ZERO else STICK_REPEAT_INTERVAL
		navigated.emit(_direction)
