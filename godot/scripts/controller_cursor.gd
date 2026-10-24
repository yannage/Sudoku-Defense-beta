class_name DefenseControllerCursor
extends Control
## One pointer, shared by R3 and RT. Native GUI drop testing reads the OS mouse
## position, while Web reads Input's mouse state; update both on desktop.
const DEVICE_ID := 99001
const DEADZONE := 0.20
const SPEED := 900.0
const SCROLL_DWELL := 0.45
const SCROLL_EDGE := 28.0
var host
var cursor_position := Vector2.ZERO
var button_down := false
var _active := false
var _initialized := false
var _axis := Vector2.ZERO
var _precision := false
var _sources: Dictionary = {}
var _dispatching := false
var _delivered_down := false
var _warp_echoes: Array[Dictionary] = []
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _scroll_control: ScrollContainer
var _scroll_direction := 0
var _scroll_time := 0.0
var _pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 50
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

func setup(game_host) -> void:
	host = game_host

func is_active() -> bool:
	return _active

func is_dispatching() -> bool:
	return _dispatching

func owns_event(event: InputEvent) -> bool:
	return event.device == DEVICE_ID or bool(event.get_meta("controller_cursor",false))

func activate() -> void:
	if _active: return
	_active = true
	if not _initialized:
		cursor_position = get_viewport_rect().size*0.5
		if host != null and int(host.selected_cell) >= 0 and not host.menu_open:
			cursor_position = host.world.cell_screen_position(int(host.selected_cell))
		_initialized = true
	cursor_position = _clamp_point(cursor_position)
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	show()
	_emit_motion(Vector2.ZERO)
	queue_redraw()

func set_axis(value: Vector2) -> void:
	_axis = value.limit_length(1.0)

func set_precision(value: bool) -> void:
	_precision = value
	queue_redraw()

func set_button(source: String, pressed: bool) -> void:
	if pressed:
		activate()
		_sources[source] = true
	else:
		_sources.erase(source)
	var next: bool = not _sources.is_empty()
	if next == button_down: return
	button_down = next
	_emit_button(next)
	_pulse = 1.0
	queue_redraw()

func move_to(point: Vector2) -> void:
	activate()
	var before: Vector2 = cursor_position
	cursor_position = _clamp_point(point)
	_emit_motion(cursor_position-before)
	queue_redraw()

func deactivate() -> bool:
	var was_active: bool = _active
	var canceled: bool = cancel()
	_active = false
	_axis = Vector2.ZERO
	_precision = false
	_scroll_control = null
	_scroll_time = 0.0
	_scroll_direction = 0
	hide()
	if was_active and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = _previous_mouse_mode
	return canceled

func cancel() -> bool:
	var was_down: bool = button_down or _delivered_down
	_sources.clear()
	if not _active and not was_down: return false
	if host != null:
		if host.seed_pointer != null and host.seed_pointer.mouse_device == DEVICE_ID: host.seed_pointer.cancel()
		if host.board_input != null and host.board_input.mouse_device == DEVICE_ID: host.board_input.cancel_pointer()
	if get_viewport().gui_is_dragging() and get_viewport().has_method("gui_cancel_drag"):
		get_viewport().call("gui_cancel_drag")
	button_down = false
	if _delivered_down:
		_emit_button(false,true)
	queue_redraw()
	return was_down

func _input(event: InputEvent) -> void:
	if not _active or _dispatching or owns_event(event): return
	var physical_input := false
	if event is InputEventScreenTouch: physical_input = event.pressed
	elif event is InputEventMouseButton: physical_input = event.pressed
	elif event is InputEventKey: physical_input = event.pressed
	if event is InputEventMouseMotion:
		# OS pointer warps emit an ordinary mouse-motion echo later. Ignore that
		# echo, but give an actual mouse immediate ownership when it moves away.
		var echo: bool = event.position.distance_to(cursor_position) <= 3.0
		var now: int = Time.get_ticks_msec()
		for warp in _warp_echoes:
			if now-int(warp.time) < 120 and event.position.distance_to(warp.point) <= 3.0: echo = true
		physical_input = not echo and event.relative.length_squared() > 0.0
	if physical_input:
		var canceled_hold: bool = deactivate()
		if host != null and host.controller != null: host.controller.reset_pointer()
		if canceled_hold and event is InputEventMouseButton:
			# Canceling the virtual mouse focus can mark the outer physical press
			# handled. Deliver that press once after cancellation; do not reparse
			# raw touch, which would synthesize a second mouse gesture.
			var press: InputEventMouseButton = event.duplicate()
			press.position = _physical(event.position)
			press.global_position = press.position
			Input.parse_input_event(press)
			Input.flush_buffered_events()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		deactivate()
		if host != null and host.controller != null: host.controller.reset_pointer()

func _clamp_point(point: Vector2) -> Vector2:
	var bounds: Vector2 = get_viewport_rect().size
	return Vector2(clampf(point.x,2,maxf(2,bounds.x-3)),clampf(point.y,2,maxf(2,bounds.y-3)))

func _physical(point: Vector2) -> Vector2:
	return get_viewport().get_final_transform()*point

func _sync_native_pointer(point: Vector2) -> void:
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		_warp_echoes.append({"point":point,"time":Time.get_ticks_msec()})
		if _warp_echoes.size() > 16: _warp_echoes.pop_front()
		get_viewport().warp_mouse(point)

func _dispatch(event: InputEvent) -> void:
	event.device = DEVICE_ID
	event.set_meta("controller_cursor",true)
	if event is InputEventMouse and not (event is InputEventMouseButton and event.canceled):
		_sync_native_pointer(get_viewport().get_final_transform().affine_inverse()*event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_delivered_down = event.pressed
	# Viewport.push_input resets handling per event. Synchronous cancellation
	# clears the old GUI press before a physical touch/mouse press can replace it.
	# ControllerInput reasserts handling for the original joypad event afterwards.
	var previous_dispatching: bool = _dispatching
	_dispatching = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	_dispatching = previous_dispatching

func _emit_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _physical(cursor_position)
	event.global_position = event.position
	event.relative = get_viewport().get_final_transform().basis_xform(relative)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if button_down else 0
	_dispatch(event)

func _emit_button(pressed: bool, canceled: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = _physical(cursor_position)
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.canceled = canceled
	_dispatch(event)

func _process(delta: float) -> void:
	if not _active: return
	var before: Vector2 = cursor_position
	var strength: float = _axis.length()
	if strength > DEADZONE:
		var speed: float = SPEED*clampf(get_viewport_rect().size.x/1280.0,0.5,2.0)
		var amount: float = pow((strength-DEADZONE)/(1.0-DEADZONE),1.6)
		cursor_position += _axis.normalized()*speed*amount*(0.30 if _precision else 1.0)*minf(delta,0.05)
	cursor_position = _clamp_point(cursor_position)
	if cursor_position != before: _emit_motion(cursor_position-before)
	_auto_scroll(minf(delta,0.05))
	_pulse = maxf(0.0,_pulse-delta*5.0)
	queue_redraw()

func _auto_scroll(delta: float) -> void:
	var target: ScrollContainer
	var direction := 0
	if not button_down and host != null:
		var scope: Control = host._controller_scope()
		if is_instance_valid(scope):
			for node in scope.find_children("*","ScrollContainer",true,false):
				if not node.is_visible_in_tree(): continue
				var rect: Rect2 = node.get_global_rect()
				if not rect.has_point(cursor_position): continue
				var bar: VScrollBar = node.get_v_scroll_bar()
				if bar.max_value <= bar.page: continue
				var edge: float = minf(SCROLL_EDGE,rect.size.y*0.20)
				if cursor_position.y < rect.position.y+edge and bar.value > bar.min_value:
					target = node; direction = -1
				elif cursor_position.y > rect.end.y-edge and bar.value < bar.max_value-bar.page:
					target = node; direction = 1
	if target != _scroll_control or direction != _scroll_direction:
		_scroll_control = target
		_scroll_direction = direction
		_scroll_time = 0.0
	if not is_instance_valid(target) or direction == 0: return
	_scroll_time += delta
	if _scroll_time >= SCROLL_DWELL:
		var bar: VScrollBar = target.get_v_scroll_bar()
		bar.value += float(direction)*280.0*delta

func _draw() -> void:
	if not _active: return
	var p: Vector2 = cursor_position
	var color := Color("ffc184") if button_down else Color("83e7c1")
	var outline := Color("07131c")
	var points := PackedVector2Array([p,p+Vector2(0,23),p+Vector2(6,17),p+Vector2(11,28),p+Vector2(16,25),p+Vector2(10,15),p+Vector2(19,15)])
	draw_colored_polygon(points,color)
	var border := points.duplicate()
	border.append(points[0])
	draw_polyline(border,outline,2.0,true)
	if _precision: draw_arc(p,10,0,TAU,24,Color(color,0.65),1.0,true)
	if _pulse > 0: draw_arc(p,13+(1-_pulse)*10,0,TAU,24,Color(color,_pulse*0.7),2.0,true)
	if _scroll_direction != 0:
		var center: Vector2 = p+Vector2(29,10)
		var sign_y: float = float(_scroll_direction)
		draw_polyline(PackedVector2Array([center+Vector2(-5,-sign_y*3),center+Vector2(0,sign_y*3),center+Vector2(5,-sign_y*3)]),color,2.0,true)
