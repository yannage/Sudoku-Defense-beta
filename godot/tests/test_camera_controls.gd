extends SceneTree
## Real GUI/input dispatch validates orbit ownership alongside seed placement.
const DEVICE := 42
var scene
var checks := 0
var failures := 0
var layout_name := "Deck"

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(layout_name+": "+message)

func frames(count: int = 3) -> void:
	for i: int in range(count): await process_frame

func settle() -> void:
	for i: int in range(120): scene.world.tick(1.0/60.0)

func mouse(point: Vector2, pressed: bool, index: int = MOUSE_BUTTON_LEFT, device: int = 0) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.button_mask = (MOUSE_BUTTON_MASK_RIGHT if index == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT) if pressed else 0
	event.pressed = pressed
	event.device = device
	root.push_input(event,true)

func motion(from: Vector2, to: Vector2, mask: int = MOUSE_BUTTON_MASK_RIGHT, device: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to-from
	event.button_mask = mask
	event.device = device
	root.push_input(event,true)

func touch(point: Vector2, pressed: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event,true)

func drag_touch(from: Vector2, to: Vector2, index: int = 0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to-from
	root.push_input(event,true)

func click(point: Vector2) -> void:
	mouse(point,true)
	await frames(1)
	mouse(point,false)
	await frames()

func tap(point: Vector2) -> void:
	touch(point,true)
	await frames(1)
	touch(point,false)
	await frames()

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	root.push_input(event,true)

func pad(index: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press_pad(index: int) -> void:
	pad(index,true)
	await frames(1)
	pad(index,false)
	await frames()

func axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = JOY_AXIS_RIGHT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func blank_cell() -> int:
	for i: int in range(81):
		if int(scene.run.board[i]) == 0: return i
	return -1

func camera_button() -> Vector2:
	return scene.hud_nodes.camera.get_global_rect().get_center()

func capture(label: String) -> void:
	if "--capture-camera" not in OS.get_cmdline_user_args(): return
	check(DisplayServer.get_name() != "headless","Camera capture requires real graphics")
	if DisplayServer.get_name() == "headless": return
	scene.notice.hide()
	await frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(not image.is_empty(),"Camera screenshot contains pixels")
	var directory := "res://build/render-checks/camera"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var renderer := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	image.save_png("%s/%s-%s-%s.png" % [directory,renderer,layout_name,label])

func exercise() -> void:
	for size: Vector2i in [Vector2i(1280,800),Vector2i(600,1066),Vector2i(1200,600)]:
		layout_name = "deck" if size.x == 1280 else ("portrait" if size.x == 600 else "wide-phone")
		root.size = size
		root.position = Vector2i.ZERO
		scene = load("res://scenes/main.tscn").instantiate()
		root.add_child(scene)
		await frames(8)
		scene.muted = true
		scene.sound.set_muted(true)
		scene.seed_input.text = "12345"
		scene._start_run()
		scene.run.timer = 900.0
		await frames(5)
		await pointer_controls()
		await controller_controls()
		await navigation_and_capture()
		scene.queue_free()
		await frames(5)
	print("CAMERA_CONTROLS_%s: %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)

func pointer_controls() -> void:
	var viewport: Rect2 = root.get_visible_rect()
	check(scene.hud_nodes.camera.is_visible_in_tree() and viewport.encloses(scene.hud_nodes.camera.get_global_rect()),"Camera button is visible and on screen")
	var before: Array = scene.run.board.duplicate()
	var selected: int = scene.selected_cell
	var center: Vector2 = scene.board_rect.get_center()
	mouse(center,true,MOUSE_BUTTON_RIGHT)
	motion(center,center+Vector2(100,0))
	mouse(center+Vector2(100,0),false,MOUSE_BUTTON_RIGHT)
	settle()
	check(absf(scene.world.get_camera_yaw())>0.1,"Right drag rotates the board")
	check(scene.run.board == before and scene.selected_cell == selected,"Right drag neither selects nor plants")
	check(not scene.board_input.camera_pointer_active(),"Releasing right drag ends its gesture")
	key(KEY_HOME,true)
	key(KEY_HOME,false)
	settle()
	check(not scene.world.camera_is_rotated(),"Home restores the default view")
	key(KEY_E,true)
	scene._tick_camera_controls(0.20)
	key(KEY_E,false)
	settle()
	var yaw: float = scene.world.get_camera_yaw()
	check(yaw>0.1,"Holding E turns the camera")
	scene._tick_camera_controls(0.20)
	settle()
	check(absf(angle_difference(yaw,scene.world.get_camera_yaw()))<0.001,"Releasing the key stops rotation")
	key(KEY_Q,true)
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	scene._tick_camera_controls(0.20)
	settle()
	check(absf(angle_difference(yaw,scene.world.get_camera_yaw()))<0.001,"Focus loss cancels held camera keys")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	key(KEY_Q,false)
	# Rotation remains a board-only gesture even though its input layer spans the UI.
	var header: Vector2 = scene.header.get_global_rect().get_center()
	mouse(header,true,MOUSE_BUTTON_RIGHT)
	motion(header,header+Vector2(80,0))
	mouse(header+Vector2(80,0),false,MOUSE_BUTTON_RIGHT)
	settle()
	check(absf(angle_difference(yaw,scene.world.get_camera_yaw()))<0.001,"Right drag beginning over the HUD does not rotate")
	await tap(camera_button())
	check(scene.camera_mode,"Touch Camera button enables orbit mode")
	check(scene.hud_nodes.camera_reset.is_visible_in_tree() and viewport.encloses(scene.hud_nodes.camera_reset.get_global_rect()),"Reset view is accessible in camera mode")
	scene.world.reset_camera()
	settle()
	touch(center,true)
	drag_touch(center,center+Vector2(80,0))
	touch(center+Vector2(80,0),false)
	settle()
	var single_yaw: float = scene.world.get_camera_yaw()
	check(absf(single_yaw)>0.1,"Touch drag rotates in camera mode")
	scene.world.reset_camera()
	settle()
	# Raw touch can arrive alongside a synthetic mouse stream; it stays one turn.
	touch(center,true)
	mouse(center,true,MOUSE_BUTTON_LEFT,InputEvent.DEVICE_ID_EMULATION)
	drag_touch(center,center+Vector2(80,0))
	motion(center,center+Vector2(80,0),MOUSE_BUTTON_MASK_LEFT,InputEvent.DEVICE_ID_EMULATION)
	mouse(center+Vector2(80,0),false,MOUSE_BUTTON_LEFT,InputEvent.DEVICE_ID_EMULATION)
	touch(center+Vector2(80,0),false)
	settle()
	check(absf(angle_difference(single_yaw,scene.world.get_camera_yaw()))<0.001,"Paired touch/mouse rotates once")
	check(scene.run.board == before and scene.selected_cell == selected,"Touch orbit never plants or changes selection")
	var before_second_finger: float = scene.world.get_camera_yaw()
	touch(center,true)
	touch(center+Vector2(40,0),true,1)
	drag_touch(center+Vector2(40,0),center+Vector2(120,0),1)
	touch(center+Vector2(120,0),false,1)
	settle()
	check(absf(angle_difference(before_second_finger,scene.world.get_camera_yaw()))<0.001 and scene.board_input.camera_pointer_active(),"A second finger cannot rotate or steal the active camera gesture")
	touch(center,false)
	# Pointer ownership must end even when release is outside the original board.
	mouse(center,true)
	var outside := Vector2(5,5)
	motion(center,outside,MOUSE_BUTTON_MASK_LEFT)
	mouse(outside,false)
	check(not scene.board_input.camera_pointer_active(),"Camera drag released beyond the board is not left held")
	await tap(scene.hud_nodes.camera_reset.get_global_rect().get_center())
	settle()
	check(not scene.world.camera_is_rotated(),"Visible Reset view returns to default")
	await tap(camera_button())
	check(not scene.camera_mode,"Done exits touch camera mode")
	# The rotated picture and hit test must still agree for actual seed input.
	scene.world.rotate_camera(PI/2.0)
	settle()
	var cell: int = blank_cell()
	var answer: int = scene.run.solution[cell]
	await click(scene.world.cell_screen_position(cell))
	check(scene.selected_cell == cell,"A normal click selects the intended rotated square")
	await click(scene.number_buttons[answer-1].get_global_rect().get_center())
	check(int(scene.run.board[cell]) == answer,"Normal number placement works after rotating")
	await tap(camera_button())
	scene._toggle_dock("bag")
	await frames()
	check(scene.dock.is_open() and not scene.camera_mode,"Opening gear exits camera mode")
	var dock_yaw: float = scene.world.get_camera_yaw()
	key(KEY_E,true)
	scene._tick_camera_controls(0.20)
	key(KEY_E,false)
	settle()
	check(absf(angle_difference(dock_yaw,scene.world.get_camera_yaw()))<0.001,"Camera keys cannot move the board under a gear sheet")
	scene.dock.close_panel()
	await frames()

func controller_controls() -> void:
	scene.selected_number = 7
	var selected: int = scene.selected_cell
	var before: Array = scene.run.board.duplicate()
	await press_pad(JOY_BUTTON_LEFT_STICK)
	check(scene.camera_mode,"L3 enables controller camera mode")
	scene.world.reset_camera()
	settle()
	axis(0.85)
	scene._tick_camera_controls(0.25)
	axis(0.0)
	settle()
	check(absf(scene.world.get_camera_yaw())>0.1,"Right stick rotates in camera mode")
	check(not scene.controller_cursor.is_active(),"Camera stick movement does not move the UI pointer")
	await press_pad(JOY_BUTTON_RIGHT_STICK)
	settle()
	check(not scene.world.camera_is_rotated(),"R3 resets the camera instead of clicking a square")
	axis(0.85)
	scene._tick_camera_controls(0.15)
	await press_pad(JOY_BUTTON_B)
	check(not scene.camera_mode and scene.selected_number == 7,"B exits camera mode without clearing the selected number")
	check(not scene.controller_cursor.button_down,"Exiting with a held camera stick never creates a pointer press")
	axis(0.0)
	settle()
	var stopped_yaw: float = scene.world.get_camera_yaw()
	scene._tick_camera_controls(0.20)
	settle()
	check(absf(angle_difference(stopped_yaw,scene.world.get_camera_yaw()))<0.001,"Camera axis stops after leaving mode")
	check(scene.run.board == before and scene.selected_cell == selected,"Controller orbit and reset leave the board unchanged")
	axis(0.85)
	await create_timer(0.10).timeout
	axis(0.0)
	check(scene.controller_cursor.is_active(),"Right stick returns to the existing cursor outside camera mode")
	await press_pad(JOY_BUTTON_LEFT_STICK)
	check(scene.camera_mode,"L3 can enter camera mode from the active cursor")
	scene._show_menu(false)
	await frames()
	check(scene.menu_open and not scene.camera_mode,"Opening the menu cancels camera mode")
	scene._close_overlay()
	await frames()
	await press_pad(JOY_BUTTON_LEFT_STICK)
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not scene.camera_mode and not scene.board_input.camera_pointer_active(),"Focus loss cancels camera mode and gestures")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)

func navigation_and_capture() -> void:
	# Include spatial content in the rendered review, and pick its visible heads
	# after orbiting rather than relying solely on an empty-board round trip.
	var remaining := 8
	for cell: int in range(81):
		if int(scene.run.board[cell]) == 0 and cell % 3 == 0 and remaining > 0:
			scene.run.place(cell,int(scene.run.solution[cell]))
			remaining -= 1
	scene.run.drain_events()
	for phase: String in ["solve","prep"]:
		scene.run.phase = phase
		for degrees: int in [45,90,135,180,225,270,315]:
			scene.world.reset_camera()
			settle()
			scene.world.rotate_camera(deg_to_rad(degrees))
			settle()
			var reached: Dictionary = {}
			for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
				scene.selected_cell = 40
				var origin: Vector2 = scene.world.cell_screen_position(40)
				scene._move_selection(direction)
				var moved: Vector2 = scene.world.cell_screen_position(scene.selected_cell)-origin
				check(moved.dot(Vector2(direction))>1.0,"Grid navigation follows screen direction at %d degrees in %s" % [degrees,phase])
				reached[scene.selected_cell] = true
			check(reached.size()==4,"The four directions reach all four neighbors at %d degrees in %s" % [degrees,phase])
			if phase == "prep":
				var picked := true
				for cell: Variant in scene.run.towers:
					var head: Vector2
					if scene.world is Node2D: head = scene.world.tower_screen_position(int(cell))
					else:
						var entry: Dictionary = scene.world._tower_nodes[cell]
						head = scene.world.camera.unproject_position(entry.node.position+Vector3(0,entry.head.position.y,0))
					picked = picked and scene.world.cell_at_screen(head) == int(cell)
				check(picked,"Visible tower heads remain selectable at %d degrees" % degrees)
			if phase == "prep" and layout_name != "wide-phone" and degrees in [90,180,270]:
				if not scene.camera_mode: scene._toggle_camera_mode()
				await capture("orbit-%d" % degrees)
				scene._toggle_camera_mode()
	# A fresh run must not inherit an old camera mode or turn.
	scene._toggle_camera_mode()
	scene._start_run()
	await frames()
	check(not scene.camera_mode and not scene.world.camera_is_rotated(),"New run restores the default camera and placement controls")
