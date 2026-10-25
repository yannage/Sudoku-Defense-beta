extends Control
var host
var pressed_at := Vector2.ZERO
var mouse_down := false
var mouse_moved := false
var mouse_device := 0
var touch_pressed_at := Vector2.ZERO
var active_touch := -1
var touch_moved := false
var _camera_pointer_id := -2 # -1 mouse, >= 0 touch, -2 inactive
var _camera_button := MOUSE_BUTTON_NONE
var _camera_device := 0
var _camera_previous := Vector2.ZERO
const CAMERA_DRAG_TURN := TAU

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func cancel_pointer() -> void:
	if camera_pointer_active() and host != null: host._finish_pointer_activity.call_deferred()
	mouse_down = false
	active_touch = -1
	_camera_pointer_id = -2
	_camera_button = MOUSE_BUTTON_NONE

func camera_pointer_active() -> bool:
	return _camera_pointer_id != -2

func _begin_camera(point: Vector2, pointer_id: int, button: int = MOUSE_BUTTON_NONE, device: int = 0) -> void:
	cancel_pointer()
	_camera_pointer_id = pointer_id
	_camera_button = button
	_camera_device = device
	_camera_previous = point

func _drag_camera(point: Vector2) -> void:
	var delta: float = (point.x-_camera_previous.x)/maxf(240.0,host.board_rect.size.x)
	_camera_previous = point
	host._rotate_camera(delta*CAMERA_DRAG_TURN)

func _input(event: InputEvent) -> void:
	# Once the board owns a gesture, keep its release even outside the board.
	# Start in _gui_input so HUD clicks and seed/module drags retain priority.
	if not camera_pointer_active(): return
	if not host._camera_available():
		cancel_pointer()
		return
	if event is InputEventScreenTouch:
		if event.pressed and _camera_pointer_id == -1 and _camera_device == InputEvent.DEVICE_ID_EMULATION and _camera_previous.distance_to(event.position) < 12:
			_camera_pointer_id = event.index
			get_viewport().set_input_as_handled()
		elif event.index == _camera_pointer_id:
			if not event.pressed: cancel_pointer()
		# A second finger cannot steal the active camera gesture or plant.
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _camera_pointer_id: _drag_camera(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if _camera_pointer_id >= 0:
			# A raw finger owns this gesture; discard its synthetic mouse copy.
			if event.device == InputEvent.DEVICE_ID_EMULATION: get_viewport().set_input_as_handled()
		elif event.device == _camera_device:
			if event is InputEventMouseMotion:
				_drag_camera(event.position)
				get_viewport().set_input_as_handled()
			elif event.button_index == _camera_button:
				if not event.pressed: cancel_pointer()
				get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel_pointer()

func _screen_point(local_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_point

func _gui_input(event: InputEvent) -> void:
	if camera_pointer_active():
		accept_event()
		return
	if host._camera_available():
		if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_RIGHT or (host.camera_mode and event.button_index == MOUSE_BUTTON_LEFT)):
			var point: Vector2 = _screen_point(event.position)
			if host.board_rect.has_point(point):
				_begin_camera(point,-1,event.button_index,event.device)
				accept_event()
				return
		if host.camera_mode and event is InputEventScreenTouch and event.pressed:
			var point: Vector2 = _screen_point(event.position)
			if host.board_rect.has_point(point):
				_begin_camera(point,event.index)
				accept_event()
				return
	if host.camera_mode: return
	if host.menu_open or host.manual_pause or (host.seed_pointer != null and host.seed_pointer.is_active()):
		cancel_pointer()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Accept mouse-only touchscreen input. A paired raw finger takes
		# ownership below, so its synthetic mouse copy cannot select twice.
		if active_touch >= 0: return
		if event.pressed:
			if mouse_down: return
			pressed_at = event.position
			mouse_down = true
			mouse_moved = false
			mouse_device = event.device
		elif mouse_down and event.device == mouse_device:
			mouse_down = false
			if not event.canceled and not mouse_moved and pressed_at.distance_to(event.position)<12:
				var cell: int = host.world.cell_at_screen(_screen_point(event.position))
				host._tap_board(cell)
	if event is InputEventMouseMotion and mouse_down and event.device == mouse_device:
		mouse_moved = mouse_moved or pressed_at.distance_to(event.position) >= 12
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0:
			if mouse_down:
				if mouse_device != InputEvent.DEVICE_ID_EMULATION or pressed_at.distance_to(event.position) >= 12: return
				mouse_down = false
			active_touch = event.index
			touch_pressed_at = event.position
			touch_moved = false
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			if not event.canceled and not touch_moved and touch_pressed_at.distance_to(event.position) < 12:
				var cell: int = host.world.cell_at_screen(_screen_point(event.position))
				host._tap_board(cell)
	if event is InputEventScreenDrag and event.index == active_touch:
		touch_moved = touch_moved or touch_pressed_at.distance_to(event.position) >= 12

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if host.camera_mode: return false
	if not data is Dictionary or data.get("type","") != "attachment": return false
	var cell: int = host.world.cell_at_screen(_screen_point(at_position))
	return host._can_attach_module(cell,str(data.get("item_id", "")))

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position,data): return
	var cell: int = host.world.cell_at_screen(_screen_point(at_position))
	host.armed_item = ""
	host.dock.clear_armed()
	host._select(cell,false)
	host._action(host.run.equip_item(cell,str(data.item_id)))
