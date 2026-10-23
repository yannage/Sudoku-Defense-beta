extends SceneTree
var failures: int = 0
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("exercise")
func send_touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.pressed = pressed
	event.index = 0
	Input.parse_input_event(event)

func exercise() -> void:
	root.size = Vector2i(1280,800)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in range(3): await process_frame
	if "--canvas-graphics" in OS.get_cmdline_user_args():
		check(scene.world is Node2D,"Web profile uses an ordinary CanvasItem board")
		check(root.disable_3d,"Web profile disables the failing 3D pass entirely")
	check(scene.menu_open,"Menu should open at launch")
	scene._close_overlay()
	check(scene.menu_open and not scene.has_active_run,"Closing initial menu must not silently start placeholder run")
	var panels: Array = []
	for node in scene.overlay.get_children():
		if node is PanelContainer:
			check(node.get_rect().end.y <= 800,"Launch menu must fit 800px height: %s" % node.get_rect())
			check(node.get_rect().end.x <= 1280,"Launch menu must fit viewport")
	scene.seed_input.text = "12345"
	scene._start_run()
	check(not scene.menu_open,"Starting game closes menu")
	check(scene.run.seed_value==12345,"Typed seed is applied")
	var cells: Array[int] = []
	for cell in range(81):
		if scene.run.board[cell]==0 and cells.size()<8: cells.append(cell)
	for cell in cells:
		scene._select(cell,false)
		scene._choose_number(scene.run.solution[cell])
	check(scene.run.towers.size()==8,"Number bar flow plants 8 towers")
	scene._select(cells[0],true)
	check(scene.dock.is_open(),"Click tower opens workshop")
	check(scene.dock.current_panel=="tower","Selected tower panel")
	scene.dock.close_panel()
	scene._advance()
	check(scene.run.phase=="prep","Prepare advances phase")
	var first_item = scene.run.items[0]
	scene.armed_item = str(first_item.id)
	scene._select(cells[0],false)
	check(scene.run.towers[cells[0]].attachments.size()==1,"Arm then select equips")
	var second_item: Dictionary = scene.run.items[0]
	var third_item: Dictionary = scene.run.items[1]
	scene.armed_item = str(second_item.id)
	var drop = scene.ui.get_child(0)
	drop._drop_data(scene.world.cell_screen_position(cells[0]),{"type":"attachment","item_id":str(third_item.id)})
	check(scene.run.towers[cells[0]].attachments.size()==2,"A drag equips only its payload even with another armed item")
	for kind in ["bag","tower","loot","camp"]:
		scene.dock.open_panel(kind,cells[0])
		await process_frame
		check(scene.dock._shell.get_global_rect().end.y <= 800,"Dock fits screen")
	scene.dock.close_panel()
	scene._advance()
	check(scene.run.phase=="battle","Launch wave advances phase")
	scene._toggle_dock("bag")
	var previous: float = scene.run.battle_time
	scene._process(.1)
	check(scene.run.battle_time==previous,"Inventory tactical pause holds battle")
	scene.dock.close_panel()
	scene._process(.05)
	check(scene.run.battle_time>previous,"Close inventory resumes battle")
	scene._save()
	check(scene._load(),"UI can save and resume model")
	scene._help()
	for i in range(2): await process_frame
	for node in scene.overlay.get_children():
		if node is PanelContainer: check(node.get_rect().end.y <= 800,"Help fits 800px height: %s"%node.get_rect())
	scene._close_overlay()
	# A real touch also generates emulated mouse events. It must plant once,
	# then inspect only on a second distinct tap; a swipe must never plant.
	scene.run.phase = "solve"
	for i in range(30): scene.world.tick(.05)
	var touch_cell: int = -1
	var drag_cell: int = -1
	for cell in range(81):
		if scene.run.board[cell] == 0:
			if touch_cell < 0: touch_cell = cell
			elif drag_cell < 0: drag_cell = cell; break
	scene.selected_number = scene.run.solution[touch_cell]
	scene._select(touch_cell,false)
	var touch_point: Vector2 = scene.world.cell_screen_position(touch_cell)
	send_touch(touch_point,true)
	await process_frame
	send_touch(touch_point,false)
	for i in range(2): await process_frame
	check(scene.run.towers.has(touch_cell),"Physical tap plants the selected number")
	check(not scene.dock.is_open(),"Emulated mouse does not open workshop after the same tap")
	send_touch(touch_point,true)
	await process_frame
	send_touch(touch_point,false)
	for i in range(2): await process_frame
	check(scene.dock.is_open() and scene.dock.current_panel == "tower","Second distinct tap opens the planted tower")
	scene.dock.close_panel()
	scene.selected_number = scene.run.solution[drag_cell]
	scene._select(drag_cell,false)
	var drag_point: Vector2 = scene.world.cell_screen_position(drag_cell)
	send_touch(drag_point,true)
	await process_frame
	var swipe := InputEventScreenDrag.new()
	swipe.index = 0
	swipe.position = drag_point+Vector2(40,0)
	swipe.relative = Vector2(40,0)
	Input.parse_input_event(swipe)
	await process_frame
	send_touch(drag_point,false)
	for i in range(2): await process_frame
	check(not scene.run.towers.has(drag_cell),"A touch drag returning to its start must not plant")
	# Exercise the actual root canvas at phone and Deck aspect ratios. The camera
	# must agree with the HUD's board rectangle, including touch/drag picking.
	for window_size in [Vector2i(390,844),Vector2i(844,390),Vector2i(1280,800)]:
		root.size = window_size
		for i in range(5): await process_frame
		scene._layout_ui()
		scene.run.phase = "solve"
		for i in range(25): scene.world.tick(.05)
		var viewport_rect := root.get_visible_rect()
		var background: Control = scene.hud_nodes.bottom
		check(background.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Decorative footer must not intercept quick-tab clicks")
		for quick in [scene.bag_button,scene.loot_button,scene.hud_nodes.camp,scene.hud_nodes.tools]:
			check(background.get_index() < quick.get_index(),"Footer draws behind every quick tab")
		scene._toast("Plant 6-8 correct answers, then prepare your defense.")
		check(not scene.notice.get_global_rect().intersects(scene.board_rect),"Feedback never covers a Sudoku square")
		check(scene.portrait_layout == (window_size.y > window_size.x),"Responsive orientation matches window")
		for control in [scene.header,scene.resources,scene.phase_label,scene.next_button,scene.bag_button,scene.loot_button]:
			check(viewport_rect.encloses(control.get_global_rect()),"HUD stays inside %s: %s" % [window_size,control.get_global_rect()])
		for b in scene.number_buttons:
			check(viewport_rect.encloses(b.get_global_rect()),"Number bar fits %s" % window_size)
			check(not b.get_global_rect().intersects(scene.next_button.get_global_rect()),"Number bar does not overlap advance button")
		if scene.portrait_layout:
			check(root.content_scale_size.x == 600,"Phone uses readable portrait canvas")
			check(scene.next_button.size.y >= 72,"Phone primary action has generous touch target")
		for cell in [0,8,40,72,80]:
			var point: Vector2 = scene.world.cell_screen_position(cell)
			check(scene.board_rect.has_point(point),"Board corner %d visible inside HUD-free area at %s: %s" % [cell,window_size,point])
			check(scene.world.cell_at_screen(point)==cell,"Cell picking matches visible board at %s" % window_size)
		for kind in ["bag","tower","loot","camp"]:
			scene.dock.open_panel(kind,cells[0])
			for i in range(2): await process_frame
			check(viewport_rect.encloses(scene.dock._shell.get_global_rect()),"Responsive dock fits %s (%s): %s" % [window_size,kind,scene.dock._shell.get_global_rect()])
			if scene.portrait_layout:
				check(scene.dock._shell.position.y >= scene.board_rect.end.y,"Phone sheet leaves board visible")
				var scroll_rect: Rect2 = scene.dock._scroll.get_global_rect()
				for child in scene.dock._scroll.find_children("*","Control",true,false):
					if not child.is_visible_in_tree(): continue
					var child_rect: Rect2 = child.get_global_rect()
					check(child_rect.position.x >= scroll_rect.position.x-.1 and child_rect.end.x <= scroll_rect.end.x+.1,"Phone panel content fits horizontally, including ninth mini-grid column: %s" % child_rect)
		scene.dock.close_panel()
		# Exercise a pointer click through the actual GUI, not the callback alone.
		var gear_center: Vector2 = scene.bag_button.get_global_rect().get_center()
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = gear_center
		press.pressed = true
		root.push_input(press,true)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = gear_center
		release.pressed = false
		root.push_input(release,true)
		await process_frame
		check(scene.dock.is_open() and scene.dock.current_panel == "bag","Gear quick tab receives pointer clicks at %s" % window_size)
		scene.dock.close_panel()
		scene._show_menu(false)
		for i in range(3): await process_frame
		for node in scene.overlay.get_children():
			if node is PanelContainer: check(viewport_rect.encloses(node.get_global_rect()),"Responsive menu fits %s" % window_size)
		scene._help()
		for i in range(3): await process_frame
		for node in scene.overlay.get_children():
			if node is PanelContainer: check(viewport_rect.encloses(node.get_global_rect()),"Responsive help fits %s" % window_size)
		scene._close_overlay()
	scene.queue_free()
	await process_frame
	print("UI_FLOW_PASS" if failures==0 else "UI_FLOW_FAILURES: %d" % failures)
	quit(1 if failures>0 else 0)
