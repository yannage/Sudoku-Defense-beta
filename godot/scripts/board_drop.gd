extends Control
var host
var pressed_at := Vector2.ZERO
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
func _gui_input(event: InputEvent) -> void:
	if host.menu_open: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pressed_at = event.position
		elif pressed_at.distance_to(event.position)<10:
			var cell: int = host.world.cell_at_screen(get_global_mouse_position())
			host._select(cell,true)
	if event is InputEventScreenTouch and not event.pressed:
		var cell: int = host.world.cell_at_screen(event.position)
		host._select(cell,true)
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
