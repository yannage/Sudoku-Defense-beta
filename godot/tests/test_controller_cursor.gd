extends SceneTree
## Standard-controller pointer regression through the actual main scene.
## Controller clicks and drags originate as joypad events. Production cursor
## movement owns native OS synchronization; physical pointer events below are
## used only to verify takeover, never to drive a controller interaction.
const DEVICE := 42
const Loot = preload("res://scripts/loot.gd")
var scene
var checks := 0
var failures := 0
var layout_name := "deck"

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(layout_name + ": " + message)

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func axis(index: int, value: float, device: int = DEVICE) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = index
	event.axis_value = value
	dispatch(event)

func button(index: int, down: bool, device: int = DEVICE) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = down
	dispatch(event)

func press(index: int) -> void:
	button(index,true)
	await frames(1)
	button(index,false)
	await frames(4)

func stick(vector: Vector2) -> void:
	axis(JOY_AXIS_RIGHT_X,vector.x)
	axis(JOY_AXIS_RIGHT_Y,vector.y)

func cursor():
	return scene.controller_cursor

func position_at(point: Vector2) -> void:
	# Public cursor positioning isolates click target geometry. Dedicated tests
	# below use the right stick for travel, precision, and complete held drags.
	cursor().move_to(point)
	await frames(3)

func steer_to(point: Vector2) -> void:
	for i in range(500):
		var offset: Vector2 = point - cursor().cursor_position
		if offset.length() < 5.0: break
		var amplitude: float = 0.37 if offset.length() < 20 else (0.52 if offset.length() < 55 else 0.95)
		stick(offset.normalized()*amplitude)
		await frames(1)
	stick(Vector2.ZERO)
	await frames(3)
	check(cursor().cursor_position.distance_to(point) < 8,"Right stick reaches the drag destination")

func click_at(point: Vector2) -> void:
	await position_at(point)
	await press(JOY_BUTTON_RIGHT_STICK)

func find_button(scope: Node, prefix: String) -> Button:
	for node in scope.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and str(node.text).begins_with(prefix): return node
	return null

func by_id(id: String) -> Button:
	for node in scene.dock.find_children("*","Button",true,false):
		if node.is_visible_in_tree() and str(node.get_meta("focus_id","")) == id: return node
	return null

func click_control(control: Control) -> void:
	check(is_instance_valid(control),"Cursor target exists")
	if is_instance_valid(control):
		await reveal_control(control)
		await click_at(control.get_global_rect().get_center())

func reveal_control(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			var scroll: ScrollContainer = ancestor
			var scroll_rect: Rect2 = scroll.get_global_rect()
			# Move the target beyond the edge-scroll band before aiming at it.
			# Otherwise it keeps travelling under a stationary pointer on slower
			# rendered frames while the press is being prepared.
			var rect: Rect2 = scroll_rect.grow(-minf(38,scroll_rect.size.y*0.25))
			for i in range(600):
				var point: Vector2 = control.get_global_rect().get_center()
				if rect.has_point(point): break
				var edge_y: float = scroll_rect.position.y+7 if point.y < rect.position.y else scroll_rect.end.y-7
				if i == 0: await position_at(Vector2(scroll_rect.get_center().x,edge_y))
				await frames(1)
			check(rect.has_point(control.get_global_rect().get_center()),"Cursor edge scroll reveals its clipped target")
		ancestor = ancestor.get_parent()

func capture(label: String) -> void:
	if "--capture-controller-cursor" not in OS.get_cmdline_user_args(): return
	check(DisplayServer.get_name() != "headless","Cursor capture uses a real renderer")
	if DisplayServer.get_name() == "headless": return
	scene.notice.hide()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(not image.is_empty(),"Rendered cursor screenshot exists")
	var directory := "res://build/controller-cursor-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var renderer := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	image.save_png("%s/%s-%s-%s.png" % [directory,renderer,layout_name,label])

func exercise() -> void:
	for window_size in [Vector2i(1280,800),Vector2i(1920,1080)]:
		layout_name = "deck" if window_size.x == 1280 else "docked"
		root.size = window_size
		# Native cursor warping respects the actual desktop bounds. Keep the
		# resized docked window fully inside the test display.
		root.position = Vector2i.ZERO
		scene = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		await frames(8)
		scene.muted = true
		scene.sound.set_muted(true)
		check(scene.controller_cursor != null,"Main scene installs the standard-controller cursor")
		# The platform input driver enforces this setting. Directly parsed test
		# events intentionally bypass it, so do not pretend to test OS focus here.
		check(bool(ProjectSettings.get_setting("input_devices/joypads/ignore_joypad_on_unfocused_application",false)),"Platform joypad input is ignored while the game is unfocused")
		await movement_and_menu()
		if scene.has_active_run and not scene.menu_open:
			await board_and_seed()
			if not scene.run.towers.is_empty():
				await gear_and_loot()
				await ownership_and_cancel()
		scene.queue_free()
		await frames(6)
	print("CONTROLLER_CURSOR_CHECKS: %d assertions, %d failures" % [checks,failures])
	print("CONTROLLER_CURSOR_PASS" if failures == 0 else "CONTROLLER_CURSOR_FAIL")
	quit(1 if failures else 0)

func movement_and_menu() -> void:
	var selected: int = scene.selected_cell
	var origin: Vector2 = cursor().cursor_position
	stick(Vector2(0.11,0.08))
	await create_timer(0.12).timeout
	check(not cursor().is_active() and cursor().cursor_position == origin,"Stick drift neither displays nor moves the pointer")
	origin = root.get_visible_rect().size*0.5
	stick(Vector2(0.85,0.0))
	await create_timer(0.14).timeout
	stick(Vector2.ZERO)
	await frames(2)
	check(cursor().is_active() and scene.controller_used,"Right stick activates cursor while retaining controller prompts")
	check(cursor().cursor_position.x > origin.x+12,"Right stick moves the pointer across the screen")
	check(scene.selected_cell == selected,"Pointer travel never navigates the underlying grid")
	await position_at(root.get_visible_rect().size*0.5)
	var start: Vector2 = cursor().cursor_position
	stick(Vector2(0.70,0.0))
	await create_timer(0.12).timeout
	stick(Vector2.ZERO)
	var normal_distance: float = cursor().cursor_position.distance_to(start)
	await position_at(start)
	axis(JOY_AXIS_TRIGGER_LEFT,1.0)
	stick(Vector2(0.70,0.0))
	await create_timer(0.12).timeout
	stick(Vector2.ZERO)
	axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	var precise_distance: float = cursor().cursor_position.distance_to(start)
	check(precise_distance > 0 and precise_distance < normal_distance*0.6,"Left trigger supplies slower fine positioning")
	var start_button: Button = find_button(scene.overlay,"Start run")
	await click_control(start_button)
	check(scene.has_active_run and not scene.menu_open,"R3 launches a run through the actual menu button")
	if not scene.has_active_run:
		print("CURSOR_CLICK_DIAGNOSTIC point=",cursor().cursor_position," mouse=",root.get_mouse_position()," active=",cursor().is_active()," button=",start_button.get_global_rect()," hovered=",root.gui_get_hovered_control())
		await capture("menu-failure")
	check(scene.controller_used,"Synthetic pointer click does not switch the UI to touch/mouse mode")
	await frames(5)

func empty_cells(count: int) -> Array[int]:
	var result: Array[int] = []
	for cell in range(81):
		if scene.run.board[cell] == 0 and result.size() < count: result.append(cell)
	return result

func board_and_seed() -> void:
	var cells := empty_cells(3)
	check(cells.size() == 3,"Sudoku fixture offers three empty cells")
	if cells.size() < 3: return
	var first: int = cells[0]
	await click_at(scene.world.cell_screen_position(first))
	check(scene.selected_cell == first and scene.run.board[first] == 0,"R3 selects an empty grid square without planting")
	var value: int = scene.run.solution[first]
	await click_control(scene.number_buttons[value-1])
	check(scene.run.board[first] == value and scene.run.towers.has(first),"R3 on the number bar plants the selected correct answer")
	var count: int = scene.run.towers.size()
	var credits: int = scene.run.credits
	await press(JOY_BUTTON_RIGHT_STICK)
	check(scene.run.towers.size() == count and scene.run.credits == credits,"Repeated number click cannot grant a second tower or solve reward")
	var target: int = cells[1]
	value = scene.run.solution[target]
	await position_at(scene.number_buttons[value-1].get_global_rect().get_center())
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await frames(2)
	check(cursor().button_down and scene.seed_pointer.is_active(),"Right trigger holds a seed using the production pointer gesture")
	await steer_to(scene.world.cell_screen_position(target))
	check(scene.run.board[target] == 0,"Held seed remains a preview until trigger release")
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await frames(5)
	check(scene.run.board[target] == value and scene.run.towers.size() == count+1,"Trigger release plants exactly one dragged seed")
	check(not cursor().button_down and not scene.seed_pointer.is_active(),"Seed drop releases both cursor and seed gesture ownership")
	# A canceled held seed must never plant on the current board target.
	var canceled: int = cells[2]
	value = scene.run.solution[canceled]
	await position_at(scene.number_buttons[value-1].get_global_rect().get_center())
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await frames(2)
	await steer_to(scene.world.cell_screen_position(canceled))
	await press(JOY_BUTTON_B)
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await frames(3)
	check(scene.run.board[canceled] == 0 and not scene.seed_pointer.is_active(),"B cancels a dragged seed without committing it on release")
	await click_control(scene.next_button)
	check(scene.run.phase == "prep","Cursor reaches the phase button outside the grid")
	await create_timer(0.65).timeout

func gear_and_loot() -> void:
	var target: int = int(scene.run.towers.keys()[0])
	scene.run.items.clear()
	for kind in Loot.ATTACHMENTS:
		scene.run.items.append(Loot.make_item(scene.run.rng,"rare",2,scene.run._id(),kind))
	scene.run.fragments = 100
	var chest: Dictionary = scene.run._add_chest("rare")
	scene._refresh()
	await click_control(scene.bag_button)
	check(scene.dock.is_open() and scene.dock.current_panel == "bag","Cursor opens Gear directly from its quick button")
	if not scene.dock.is_open() or scene.dock.current_panel != "bag": return
	await frames(20)
	var item: Dictionary = {}
	var card: Button
	for candidate in scene.dock._shell.find_children("*","Button",true,false):
		if str(candidate.get_meta("focus_id","")).begins_with("item:"):
			card = candidate
			item = card.item
			break
	check(is_instance_valid(card),"Visual module tile is available for controller dragging")
	if is_instance_valid(card):
		var inventory: int = scene.run.items.size()
		await reveal_control(card)
		await position_at(card.get_global_rect().get_center())
		axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
		await frames(2)
		await steer_to(scene.world.cell_screen_position(target))
		check(root.gui_is_dragging(),"Right-stick travel while holding RT starts a real GUI module drag")
		check(scene.run.items.size() == inventory,"Dragging gear does not remove it before release")
		await capture("module-drag")
		axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
		await frames(6)
		check(scene.run.items.size() == inventory-1 and scene.run.towers[target].attachments.size() == 1,"RT release attaches exactly one module to the hovered tower")
		check(str(scene.run.towers[target].attachments[0].id) == str(item.id),"Dragged module identity is preserved")
		check(not root.gui_is_dragging() and not cursor().button_down,"Module drop releases native GUI drag ownership")
	# Hovering at the inventory's edge scrolls the real scroller; the stick is
	# still a pointer and shoulder buttons remain available for normal tabs.
	var scroll: ScrollContainer = scene.dock._scroll
	var rect: Rect2 = scroll.get_global_rect()
	await position_at(Vector2(rect.get_center().x,rect.end.y-7))
	var before_scroll: int = scroll.scroll_vertical
	await create_timer(0.85).timeout
	check(scroll.scroll_vertical > before_scroll,"Pointer edge dwell scrolls a long module inventory")
	await press(JOY_BUTTON_B)
	await click_control(scene.loot_button)
	check(scene.dock.is_open() and scene.dock.current_panel == "loot","Cursor reaches Chests without a grid navigation shortcut")
	await frames(10)
	var chest_button: Button = by_id("chest:"+str(chest.id))
	var fragments: int = scene.run.fragments
	var items: int = scene.run.items.size()
	await click_control(chest_button)
	await press(JOY_BUTTON_RIGHT_STICK)
	check(scene.run.fragments == fragments-int(chest.cost) and scene.run.items.size() == items+2,"R3 opens a chest and repeated input cannot charge or grant twice")
	await create_timer(0.85).timeout
	check(scene.dock._loot_table._reward_cards.size() == 2,"The controller-opened chest presents every earned item")
	await click_control(by_id("loot:continue"))
	await press(JOY_BUTTON_B)
	check(not scene.dock.is_open(),"B returns from loot management to the board")

func ownership_and_cancel() -> void:
	# Cancellation between press and release must never activate covered UI,
	# including same-frame handoffs with no intervening rendered frame.
	await position_at(scene.bag_button.get_global_rect().get_center())
	button(JOY_BUTTON_RIGHT_STICK,true)
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	button(JOY_BUTTON_RIGHT_STICK,false)
	await frames(5)
	check(not scene.dock.is_open() and not cursor().button_down,"Same-frame focus loss cancels a cursor press before release")
	await unfocused_input_is_ignored()
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await position_at(scene.bag_button.get_global_rect().get_center())
	button(JOY_BUTTON_RIGHT_STICK,true)
	button(JOY_BUTTON_B,true)
	button(JOY_BUTTON_B,false)
	button(JOY_BUTTON_RIGHT_STICK,false)
	await frames(5)
	check(not scene.dock.is_open() and not scene.menu_open and not cursor().button_down,"Same-frame B cancels a held click without activating Gear or opening another menu")
	# R3 and RT own a shared mouse hold; releasing only one must not click.
	await position_at(scene.bag_button.get_global_rect().get_center())
	button(JOY_BUTTON_RIGHT_STICK,true)
	await frames(2)
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await frames(2)
	button(JOY_BUTTON_RIGHT_STICK,false)
	await frames(2)
	check(cursor().button_down and not scene.dock.is_open(),"Releasing R3 keeps the mouse held while RT still owns it")
	await press(JOY_BUTTON_B)
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await frames(3)
	check(not cursor().button_down and not scene.dock.is_open(),"Cancel releases all aggregated cursor holds without a click")
	# Changing controllers while a click is held cancels the old gesture.
	await position_at(scene.bag_button.get_global_rect().get_center())
	button(JOY_BUTTON_RIGHT_STICK,true)
	await frames(2)
	axis(JOY_AXIS_RIGHT_X,0.75,43)
	await frames(2)
	axis(JOY_AXIS_RIGHT_X,0.0,43)
	button(JOY_BUTTON_RIGHT_STICK,false,DEVICE)
	await frames(3)
	check(scene.controller.active_device == 43 and not cursor().button_down and not scene.dock.is_open(),"A second controller takes over without committing the first controller's held click")
	axis(JOY_AXIS_RIGHT_X,0.7,DEVICE)
	await frames(2)
	axis(JOY_AXIS_RIGHT_X,0.0,DEVICE)
	# A pointer gesture must be canceled, not committed, on lost focus/device.
	await position_at(scene.bag_button.get_global_rect().get_center())
	button(JOY_BUTTON_RIGHT_STICK,true)
	await frames(2)
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await frames(3)
	button(JOY_BUTTON_RIGHT_STICK,false)
	await frames(3)
	check(not cursor().is_active() and not cursor().button_down and not scene.dock.is_open(),"Focus loss releases and hides a held cursor without activating Gear")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await position_at(scene.bag_button.get_global_rect().get_center())
	button(JOY_BUTTON_RIGHT_STICK,true)
	await frames(2)
	Input.joy_connection_changed.emit(DEVICE,false)
	await frames(4)
	button(JOY_BUTTON_RIGHT_STICK,false)
	await frames(3)
	check(not cursor().button_down and scene.menu_open and not scene.dock.is_open(),"Controller disconnect cancels the held click and pauses safely")
	Input.joy_connection_changed.emit(DEVICE,true)
	await press(JOY_BUTTON_B)
	check(not scene.menu_open,"Reconnected controller can leave the pause menu")
	await focus_resets_navigation()
	var selected: int = scene.selected_cell
	if selected < 0: scene._select(40,false,false); selected = 40
	await position_at(scene.bag_button.get_global_rect().get_center())
	await press(JOY_BUTTON_DPAD_DOWN)
	check(not cursor().is_active() and scene.selected_cell == mini(selected+9,72+selected%9),"D-pad resumes discrete grid navigation without moving the mouse target")
	var stopped: int = scene.selected_cell
	stick(Vector2(-0.75,0.0))
	await create_timer(0.12).timeout
	stick(Vector2.ZERO)
	await create_timer(0.35).timeout
	check(cursor().is_active() and scene.selected_cell == stopped,"Returning to the pointer stops all latent grid repeats")
	var point: Vector2 = scene.loot_button.get_global_rect().get_center()
	var physical_clicks := [0]
	scene.loot_button.pressed.connect(func(): physical_clicks[0] += 1)
	await position_at(scene.bag_button.get_global_rect().get_center())
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	await frames(2)
	for down in [true,false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = root.get_final_transform()*point
		touch.pressed = down
		dispatch(touch)
		await frames(2)
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await frames(4)
	check(not cursor().is_active() and not scene.controller_used,"A physical-touch event cleanly takes ownership from the virtual pointer")
	check(not cursor().button_down,"Input handoff leaves no held synthetic mouse button")
	check(scene.dock.is_open() and scene.dock.current_panel == "loot" and physical_clicks[0] == 1,"The first physical touch during a virtual RT hold activates the Chests GUI button exactly once")
	if scene.dock.is_open(): await press(JOY_BUTTON_B)
	# Desktop mouse and mouse-only touch emulation must also take over on the
	# very first press. No preceding motion is injected: that would cancel RT
	# before the press and conceal the nested-release ownership regression.
	for mouse_device in [0,InputEvent.DEVICE_ID_EMULATION]:
		var source := "Physical mouse" if mouse_device == 0 else "Mouse-only touch emulation"
		physical_clicks[0] = 0
		await position_at(scene.bag_button.get_global_rect().get_center())
		axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
		await frames(2)
		for down in [true,false]:
			var mouse := InputEventMouseButton.new()
			mouse.device = mouse_device
			mouse.position = root.get_final_transform()*point
			mouse.global_position = mouse.position
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			mouse.pressed = down
			dispatch(mouse)
			await frames(2)
		axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
		await frames(4)
		check(not cursor().is_active() and not scene.controller_used and not cursor().button_down,source+" takes ownership and leaves no held virtual button")
		check(scene.dock.is_open() and scene.dock.current_panel == "loot" and physical_clicks[0] == 1,source+" first click during RT hold opens Chests exactly once")
		if scene.dock.is_open(): await press(JOY_BUTTON_B)
	await position_at(root.get_visible_rect().size+Vector2(100,100))
	check(root.get_visible_rect().grow(1).has_point(cursor().cursor_position),"Cursor is constrained to the current viewport after docking/resize")
	await capture("pointer")

func unfocused_input_is_ignored() -> void:
	# Input.parse_input_event bypasses the platform driver setting, so this
	# exercises the application's own focus guard, including new held input.
	var position_before: Vector2 = cursor().cursor_position
	var selected_before: int = scene.selected_cell
	axis(JOY_AXIS_RIGHT_X,0.9)
	button(JOY_BUTTON_RIGHT_STICK,true)
	axis(JOY_AXIS_TRIGGER_RIGHT,1.0)
	axis(JOY_AXIS_LEFT_Y,0.9)
	button(JOY_BUTTON_DPAD_DOWN,true)
	await create_timer(0.35).timeout
	check(not cursor().is_active() and not cursor().button_down and cursor().cursor_position == position_before,"Fresh right-stick, R3, and trigger input cannot reactivate the unfocused pointer")
	check(scene.selected_cell == selected_before and not scene.dock.is_open(),"Fresh left-stick and D-pad input cannot navigate or activate unfocused UI")
	axis(JOY_AXIS_RIGHT_X,0.0)
	button(JOY_BUTTON_RIGHT_STICK,false)
	axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	axis(JOY_AXIS_LEFT_Y,0.0)
	button(JOY_BUTTON_DPAD_DOWN,false)

func focus_resets_navigation() -> void:
	# Losing focus may prevent the corresponding stick/D-pad release from
	# arriving. Cached repeat must stop without relying on that missing event.
	scene._select(40,false,false)
	axis(JOY_AXIS_LEFT_Y,0.9)
	await frames(2)
	var stopped: int = scene.selected_cell
	check(stopped == 49,"Left-stick fixture starts real grid navigation before focus loss")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await create_timer(0.50).timeout
	check(scene.selected_cell == stopped and not cursor().is_active(),"Focus loss stops a held left stick without needing its release")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	axis(JOY_AXIS_LEFT_Y,0.0)
	button(JOY_BUTTON_DPAD_LEFT,true)
	await frames(2)
	stopped = scene.selected_cell
	check(stopped == 48,"Fresh D-pad input resumes after focus returns")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await create_timer(0.50).timeout
	check(scene.selected_cell == stopped,"Focus loss also clears held D-pad repeat")
	button(JOY_BUTTON_DPAD_LEFT,false)
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
