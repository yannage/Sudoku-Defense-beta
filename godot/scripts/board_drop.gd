extends Control
var host
var pressed_at := Vector2.ZERO
var touch_pressed_at := Vector2.ZERO
var active_touch := -1
var touch_moved := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
func _gui_input(event: InputEvent) -> void:
	if host.menu_open: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Godot also emits a mouse release for a physical touch. Handle the
		# original touch once so planting does not immediately open its workshop.
		if event.device == InputEvent.DEVICE_ID_EMULATION: return
		if event.pressed: pressed_at = event.position
		elif pressed_at.distance_to(event.position)<10:
			var cell: int = host.world.cell_at_screen(get_global_mouse_position())
			host._select(cell,true)
	if event is InputEventScreenTouch:
		if event.pressed and (active_touch < 0 or event.index == active_touch):
			active_touch = event.index
			touch_pressed_at = event.position
			touch_moved = false
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			if not touch_moved and touch_pressed_at.distance_to(event.position) < 12:
				var cell: int = host.world.cell_at_screen(event.position)
				host._select(cell,true)
	if event is InputEventScreenDrag and event.index == active_touch:
		touch_moved = touch_moved or touch_pressed_at.distance_to(event.position) >= 12
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or data.get("type","") != "attachment": return false
	var cell: int = host.world.cell_at_screen(at_position)
	return host.run.towers.has(cell) and not host.menu_open
func _drop_data(at_position: Vector2, data: Variant) -> void:
	var cell: int = host.world.cell_at_screen(at_position)
	host.armed_item = ""
	host.dock.clear_armed()
	host._select(cell,false)
	host._action(host.run.equip_item(cell,str(data.item_id)))
