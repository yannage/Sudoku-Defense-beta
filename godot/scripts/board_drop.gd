extends Control
var host
var pressed_at := Vector2.ZERO
var mouse_down := false
var mouse_moved := false
var mouse_device := 0
var touch_pressed_at := Vector2.ZERO
var active_touch := -1
var touch_moved := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func cancel_pointer() -> void:
	mouse_down = false
	active_touch = -1

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel_pointer()

func _screen_point(local_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_point

func _gui_input(event: InputEvent) -> void:
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
