extends Control
## A single pointer owns a seed gesture. Raw touch and ordinary mouse input
## share the same path, including Steam Deck's mouse-emulated touchscreen.
const DRAG_DISTANCE := 12.0
var host
var number := 0
var pointer_id := -2 # -1 mouse, >=0 physical touch index, -2 inactive
var origin := Vector2.ZERO
var pointer_position := Vector2.ZERO
var dragging := false
var mouse_device := 0
var hover_cell := -1
var _source: Button
var _card: PanelContainer
var _digit: Label
var _hint: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 15
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(128,102)
	add_child(_card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation",1)
	_card.add_child(box)
	_digit = Label.new()
	_digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_digit.add_theme_font_size_override("font_size",43)
	_digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_digit)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size",11)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint)
	_card.hide()

func is_active() -> bool:
	return pointer_id != -2

func _number_at(point: Vector2) -> int:
	if host.dock.is_open() and host.dock._shell.get_global_rect().has_point(point): return 0
	for i in range(host.number_buttons.size()):
		var button: Button = host.number_buttons[i]
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point): return i+1
	return 0

func _input(event: InputEvent) -> void:
	if host == null: return
	if event is InputEventKey and event.pressed and is_active():
		cancel()
		# Escape cancels the dragged seed instead of also opening a menu.
		if event.keycode == KEY_ESCAPE: get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Only suppress a mouse copy while an actual finger owns this gesture.
		# Some desktop touch integrations provide mouse events alone; their
		# emulation device ID does not mean a raw touch event will follow.
		if pointer_id >= 0:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_active(): get_viewport().set_input_as_handled(); return
			var chosen: int = _number_at(event.position)
			if chosen > 0 and host._number_input_allowed():
				mouse_device = event.device
				_begin(chosen,event.position,-1)
				get_viewport().set_input_as_handled()
		elif pointer_id == -1 and event.device == mouse_device:
			_finish(event.position,event.canceled)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_id == -1 and event.device == mouse_device:
		_move(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			# Godot may dispatch the emulated mouse press before the raw touch.
			# Transfer that same press to the finger, rather than start it twice.
			if pointer_id == -1 and mouse_device == InputEvent.DEVICE_ID_EMULATION and origin.distance_to(event.position) < DRAG_DISTANCE:
				pointer_id = event.index
				get_viewport().set_input_as_handled()
				return
			if is_active(): get_viewport().set_input_as_handled(); return
			var chosen: int = _number_at(event.position)
			if chosen > 0 and host._number_input_allowed():
				_begin(chosen,event.position,event.index)
				get_viewport().set_input_as_handled()
		elif pointer_id == event.index:
			_finish(event.position,event.canceled)
			get_viewport().set_input_as_handled()
		elif is_active(): get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and is_active():
		if pointer_id == event.index: _move(event.position)
		get_viewport().set_input_as_handled()

func _begin(chosen: int, point: Vector2, id: int) -> void:
	host.board_input.cancel_pointer()
	number = chosen
	pointer_id = id
	origin = point
	pointer_position = point
	dragging = false
	hover_cell = -1
	_source = host.number_buttons[chosen-1]
	_source.self_modulate = Color(1.25,1.25,1.25,1)
	host._pointer_activity(id)

func _move(point: Vector2) -> void:
	pointer_position = point
	if not dragging and origin.distance_to(point) >= DRAG_DISTANCE:
		dragging = true
	if dragging: _preview()

func _target() -> int:
	if not host._number_placement_allowed(): return -1
	if host.run.phase == "solve" and host._number_complete(number): return -1
	return host.world.cell_at_screen(pointer_position)

func _target_hint(cell: int) -> String:
	if host.run.phase == "solve" and host._number_complete(number): return "ALL 9 COMPLETE"
	if cell < 0: return "DROP ON A SQUARE"
	if host.run.givens[cell]: return "FIXED CLUE"
	if host.run.towers.has(cell): return "TOWER ALREADY HERE"
	if host.run.phase == "battle" and host.run.inventory[number] <= 0: return "BUY A RESERVE FIRST"
	if host.run.phase == "solve" and not host.run.candidates(cell).has(number): return "NUMBER CONFLICT"
	return "RELEASE TO PLANT"

func _preview() -> void:
	hover_cell = _target()
	var hint: String = _target_hint(hover_cell)
	var allowed: bool = hint == "RELEASE TO PLANT"
	var tint: Color = Color("82939a") if hint == "ALL 9 COMPLETE" else Color("83e7c1") if allowed else Color("ff8b82") if hover_cell >= 0 else host.COLORS[number-1]
	if host.world.has_method("set_drop_preview"): host.world.set_drop_preview(hover_cell,number,allowed)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("132d3b")
	style.border_color = tint
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 3
	style.content_margin_bottom = 9
	style.shadow_color = Color(0,0,0,.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(4,5)
	_card.add_theme_stylebox_override("panel",style)
	_digit.text = str(number)
	_digit.add_theme_color_override("font_color",host.COLORS[number-1])
	_hint.text = hint
	_hint.add_theme_color_override("font_color",tint)
	_card.reset_size()
	var view: Vector2 = get_viewport_rect().size
	_card.position = Vector2(clampf(pointer_position.x-_card.size.x*.5,8,view.x-_card.size.x-8),clampf(pointer_position.y-_card.size.y-28,8,view.y-_card.size.y-8))
	_card.show()

func _finish(point: Vector2, canceled: bool) -> void:
	var chosen: int = number
	var was_dragging: bool = dragging or origin.distance_to(point) >= DRAG_DISTANCE
	pointer_position = point
	var target: int = _target()
	var same_button: bool = _number_at(point) == chosen
	var allowed: bool = host._number_input_allowed()
	cancel()
	if canceled or not allowed: return
	if was_dragging:
		if target >= 0: host._drop_number(target,chosen)
	elif same_button:
		host.sound.click()
		host._choose_number(chosen)

func cancel() -> void:
	if is_active() and host != null: host._finish_pointer_activity.call_deferred()
	if is_instance_valid(_source): _source.self_modulate = Color.WHITE
	_source = null
	pointer_id = -2
	number = 0
	dragging = false
	hover_cell = -1
	if is_instance_valid(_card): _card.hide()
	if host != null and is_instance_valid(host.world) and host.world.has_method("set_drop_preview"):
		host.world.set_drop_preview(-1,0,false)

func _process(_delta: float) -> void:
	if not is_active(): return
	if not host._number_input_allowed() or (dragging and not host._number_placement_allowed()): cancel()
	elif dragging: _preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: cancel()
