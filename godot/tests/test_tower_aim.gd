extends SceneTree
## Native joypad events and real game scenes; never writes player saves.
const Aim = preload("res://scripts/tower_aim.gd")
const DEVICE := 63
var scene
var checks := 0
var failures: Array[String] = []
var serial := 0
var label := ""
var cells: Array[int] = []
var origin := -1

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(label + ": " + message)

func frames(count := 4) -> void:
	for index in range(count): await process_frame

func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func stick(value: Vector2) -> void:
	axis(JOY_AXIS_LEFT_X,value.x)
	axis(JOY_AXIS_LEFT_Y,value.y)

func button(index: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(index: int) -> void:
	button(index,true)
	await frames(1)
	button(index,false)
	await frames()

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(2,2)
	root.push_input(event,true)

func mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event,true)

func click(point: Vector2) -> void:
	mouse(point,true)
	await frames(1)
	mouse(point,false)
	await frames()

func fixture() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await frames()
	serial += 1
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = "user://tower-aim-%d-settings.json" % serial
	scene.run_save.file_path = "user://tower-aim-%d-run.json" % serial
	root.add_child(scene)
	await frames(6)
	scene.sound.set_muted(true)
	scene.set_process(false)
	scene.run.new_run(875,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	scene.has_active_run = true
	scene._close_overlay()
	scene.dock.reset_for_run()
	cells.clear()
	var blanks: Array[int] = []
	for cell in range(81):
		if scene.run.board[cell] == 0: blanks.append(cell)
	for index in range(0,blanks.size()-1,3):
		var cell := blanks[index]
		check(scene.run.place(cell,scene.run.solution[cell]).ok,"Fixture plants a legal tower")
		cells.append(cell)
	check(cells.size() >= 4,"Fixture has enough towers for directional navigation")
	check(scene.run.advance_phase().ok,"Fixture enters prepare phase")
	scene.last_phase = scene.run.phase
	scene.world.setup(scene.run)
	for index in range(120): scene.world.tick(1.0/60.0)
	origin = cells[0]
	var center: Vector2 = scene.board_rect.get_center()
	var nearest := INF
	for cell in cells:
		var distance: float = scene.world.cell_screen_position(cell).distance_to(center)
		if distance < nearest:
			nearest = distance
			origin = cell
	scene._select(origin,false,false)
	scene._refresh()
	scene.controller.active_device = DEVICE
	stick(Vector2.ZERO)
	await frames(8)
	check(scene._tower_aim_available(),"Tower aiming is available at 1280x800")

func diagonal() -> Vector2:
	var start: Vector2 = scene.world.cell_screen_position(scene.selected_cell)
	for cell in cells:
		var direction: Vector2 = (scene.world.cell_screen_position(cell)-start).normalized()
		if absf(direction.x) > 0.30 and absf(direction.y) > 0.30:
			return direction
	return Vector2(0.8,0.8).normalized()

func begin_aim(direction: Vector2) -> int:
	stick(direction)
	await frames()
	check(scene.tower_aim._stick_active,"Stick deflection begins an aim gesture")
	check(scene.tower_aim.target >= 0,"Aim produces a target")
	return int(scene.tower_aim.target)

func picker_contract() -> void:
	label = "screen-space picker"
	var positions := {0:Vector2.ZERO,1:Vector2(100,100),2:Vector2(140,0),3:Vector2(0,140),4:Vector2(-20,-20)}
	check(Aim.pick_target(Vector2.ZERO,Vector2(1,1),positions,0) == 1,"Diagonal aim selects diagonal tower instead of quantizing to an axis")
	check(Aim.pick_target(Vector2.ZERO,Vector2.RIGHT,positions,0) == 2,"Aligned tower beats a more lateral candidate")
	check(Aim.pick_target(Vector2.ZERO,Vector2.DOWN,positions,0) == 3,"Downward aiming uses screen coordinates")
	check(Aim.pick_target(Vector2.ZERO,Vector2.ZERO,positions,0) == 0,"Neutral has no target jump")
	check(Aim.pick_target(Vector2.ZERO,Vector2.LEFT,{0:Vector2.ZERO,1:Vector2(20,0)},0) == 0,"No forward tower leaves selection unchanged")
	check(Aim.pick_target(Vector2.ZERO,Vector2.RIGHT,{0:Vector2.ZERO,1:Vector2(1,100)},0) == 0,"A nearly perpendicular tower is outside the aim cone")
	check(Aim.pick_target(Vector2.ZERO,Vector2.RIGHT,{0:Vector2.ZERO,2:Vector2(80,0),1:Vector2(40,0)},0) == 1,"Nearest collinear tower wins independent of insertion order")
	var rotated := {}
	for cell: int in positions: rotated[cell] = positions[cell].rotated(PI/2.0)
	check(Aim.pick_target(Vector2.ZERO,Vector2(1,1).rotated(PI/2.0),rotated,0) == 1,"Picker is invariant under screen-space rotation")
	check(Aim.pick_target(Vector2.ZERO,Vector2.RIGHT,{},0) == 0,"Empty candidate layout is harmless")

func first_device_direction() -> void:
	label = "first device analog routing"
	await fixture()
	for direction: Vector2 in [Vector2(0.4,0.916),Vector2(0.5,0.5)]:
		scene.controller.reset_navigation()
		scene.controller.active_device = -1
		scene.controller._left_axes.clear()
		stick(Vector2.ZERO)
		await frames()
		stick(direction)
		await frames()
		check(scene.controller.active_device == DEVICE,"Radial deflection claims a previously unclaimed controller")
		check(scene.controller._axis.is_equal_approx(direction),"First diagonal preserves a subthreshold X component")
		check(scene.tower_aim._stick_active,"Radial diagonal starts tower aim even when individual axes are under the press threshold")
		stick(Vector2.ZERO)
		await frames()

func release_in_menu() -> void:
	label = "release while Gear owns input"
	await fixture()
	await begin_aim(diagonal())
	await press(JOY_BUTTON_X)
	check(scene.dock.is_open(),"Gear opens while aim is pending")
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == origin,"Releasing while Gear is open does not move the tower")
	await press(JOY_BUTTON_B)
	check(not scene.dock.is_open(),"Back returns from Gear")
	var expected := await begin_aim(diagonal())
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == expected,"Neutral observed in Gear rearms the next board gesture")

func held_stick_into_pause_menu() -> void:
	label = "held stick through Start"
	await fixture()
	await begin_aim(Vector2.DOWN)
	await press(JOY_BUTTON_START)
	check(scene.menu_open,"Start opens the pause menu during a tower aim")
	var focused: Control = root.gui_get_focus_owner()
	check(is_instance_valid(focused),"Pause menu has a focused control")
	for index in range(8):
		stick(Vector2(0.0,0.90 if index%2 == 0 else 0.96))
		scene.controller._process(0.5)
		await frames(1)
	check(root.gui_get_focus_owner() == focused,"Held stick chatter cannot move pause-menu focus before neutral")
	check(scene.selected_cell == origin,"Start and held input do not commit the canceled tower aim")
	stick(Vector2.ZERO)
	await frames()
	stick(Vector2.DOWN)
	await frames(1)
	check(root.gui_get_focus_owner() != focused,"After neutral, a fresh stick gesture moves pause-menu focus")
	check(scene.menu_open and scene.selected_cell == origin,"Fresh menu navigation remains scoped to the pause menu")
	stick(Vector2.ZERO)
	await frames()

func analog_gesture() -> void:
	label = "analog gesture"
	await fixture()
	var direction := diagonal()
	var state_before: String = JSON.stringify(scene.run.save_data(),"",true,true)
	stick(Vector2(0.15,0.15))
	await frames()
	check(scene.selected_cell == origin and not scene.tower_aim._stick_active,"Drift does not start or commit an aim")
	stick(Vector2.ZERO)
	var expected := await begin_aim(direction)
	check(expected != origin,"Fixture direction offers another tower")
	check(scene.controller._axis.is_equal_approx(direction),"Native routing retains both analog components")
	check(scene.selected_cell == origin,"Aiming previews without moving current tower")
	for index in range(40):
		# Simulate far more time than the old 0.12-second repeat interval.
		scene.controller._process(0.12)
		stick(direction*(0.94 if index%2 == 0 else 1.0))
		scene.tower_aim._process(0.12)
	check(scene.selected_cell == origin,"Held stick and noisy axis events never race through towers")
	check(scene.controller._direction == Vector2i.ZERO,"Tower stick aiming does not feed cardinal repeat")
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == expected,"Returning to neutral commits exactly the previewed tower")
	var selected: int = scene.selected_cell
	for index in range(20):
		scene.controller._process(0.5)
		scene.tower_aim._process(0.5)
	check(scene.selected_cell == selected,"Neutral after release cannot chain another selection")
	check(JSON.stringify(scene.run.save_data(),"",true,true) == state_before,"Aiming and selecting never spends, equips, or changes gameplay")
	var second := await begin_aim(-direction)
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == second,"A fresh gesture selects again")

func cancel_context(kind: String) -> void:
	label = "cancel " + kind
	await fixture()
	await begin_aim(diagonal())
	match kind:
		"dock": scene.dock.open_panel("bag",scene.selected_cell)
		"camera": scene._set_camera_mode(true)
		"solve": scene.run.phase = "solve"
		"reserve": scene.reserve_mode = true
		"pause": scene.manual_pause = true
		"focus": scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
		"reset": scene.controller.reset_navigation()
	await frames()
	check(scene.tower_aim.target == -1 and not scene.tower_aim._stick_active,"Interrupted context clears the preview")
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == origin,"Late stick release cannot select through another context")
	if kind == "focus": scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)

func cancel_button() -> void:
	label = "cancel button"
	await fixture()
	await begin_aim(diagonal())
	await press(JOY_BUTTON_B)
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == origin,"B cancels the aim so release does not move afterwards")
	check(scene.tower_aim.target == -1,"B clears the highlighted target")
	var second := await begin_aim(diagonal())
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == second,"After B and neutral, a fresh gesture works")

func confirm_preview() -> void:
	label = "confirm preview"
	await fixture()
	var direction := diagonal()
	var expected := await begin_aim(direction)
	await press(JOY_BUTTON_A)
	check(scene.selected_cell == expected,"A commits the highlighted tower")
	check(not scene.dock.is_open(),"Confirming a preview only selects; it does not open the wrong workshop")
	for index in range(6):
		stick(direction)
		await frames(1)
	check(scene.selected_cell == expected,"Holding after A cannot create another target hop")
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == expected,"Release after A cannot commit a second selection")

func partial_release() -> void:
	label = "partial diagonal release"
	await fixture()
	var direction := Vector2(1,1).normalized()
	var expected := await begin_aim(direction)
	# First lower both axes enough to mark release, then let them return separately.
	stick(direction*0.7)
	await frames()
	axis(JOY_AXIS_LEFT_X,0.0)
	await frames()
	check(scene.tower_aim.target == expected,"Asymmetric diagonal release keeps the deliberate preview")
	axis(JOY_AXIS_LEFT_Y,0.0)
	await frames()
	check(scene.selected_cell == expected,"Asymmetric release selects the intended tower")

func dpad_and_grid() -> void:
	label = "D-pad and solve grid"
	await fixture()
	var before: int = scene.selected_cell
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(scene.run.towers.has(scene.selected_cell),"D-pad stays on planted towers")
	check(not scene.tower_aim._stick_active,"D-pad is independent of stick gestures")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.run.towers.has(scene.selected_cell),"RB still cycles towers")
	scene.run.phase = "solve"
	scene.last_phase = "solve"
	scene._select(40,false,false)
	scene.controller.reset_navigation()
	var step: Vector2i = scene._screen_grid_direction(Vector2i.RIGHT)
	var expected := posmod(4+step.y,9)*9+posmod(4+step.x,9)
	stick(Vector2.RIGHT)
	await frames(1)
	check(scene.selected_cell == expected,"Solving still moves immediately from the left stick")
	check(not scene.tower_aim._stick_active,"Solve navigation does not start tower aim")
	stick(Vector2.ZERO)
	await frames()
	scene._show_menu(false)
	await frames()
	var focused: Control = root.gui_get_focus_owner()
	await press(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() != focused,"Menu D-pad still moves focus")
	check(scene.menu_open,"Menu navigation cannot fall through to board")
	check(scene.selected_cell == expected,"Menu navigation leaves board selection unchanged")
	if before < 0: check(false,"Fixture has an initial selection")

func pointer_navigation() -> void:
	label = "mouse and trackpad"
	await fixture()
	var origin_point: Vector2 = scene.world.cell_screen_position(origin)
	var point := Vector2.ZERO
	var expected := -1
	# Find a real board gap that aims at a different planted tower.
	for row in range(1,19):
		for col in range(1,27):
			var candidate: Vector2 = scene.board_rect.position + scene.board_rect.size*Vector2(float(col)/28.0,float(row)/20.0)
			var hit: int = scene.world.cell_at_screen(candidate)
			var target: int = scene.tower_aim.target_at(candidate)
			if not scene.run.towers.has(hit) and target >= 0 and target != origin and candidate.distance_to(origin_point) > 24.0:
				point = candidate
				expected = target
				break
		if expected >= 0: break
	check(expected >= 0,"Fixture contains an aimable gap between towers")
	if expected < 0: return
	var state_before: String = JSON.stringify(scene.run.save_data(),"",true,true)
	motion(point)
	await frames()
	check(scene.tower_aim.target == expected,"Mouse motion previews its directional target")
	check(scene.selected_cell == origin,"Hover alone never selects a tower")
	await click(point)
	check(scene.selected_cell == expected,"Click toward a tower selects the previewed target")
	check(not scene.dock.is_open(),"Directional gap click does not unexpectedly open a workshop")
	check(JSON.stringify(scene.run.save_data(),"",true,true) == state_before,"Pointer aiming cannot buy or equip anything")
	var selected: int = scene.selected_cell
	await frames(10)
	check(scene.selected_cell == selected,"Stationary pointer never chains tower selections")
	var direct: Vector2 = scene.world.cell_screen_position(selected)
	await click(direct)
	check(scene.dock.is_open() and scene.dock.current_panel == "tower","Direct tower click retains workshop access")

func rotated_scene() -> void:
	label = "rotated camera"
	await fixture()
	scene.world.rotate_camera(PI/2.0)
	for index in range(120): scene.world.tick(1.0/60.0)
	var direction := diagonal()
	var expected := await begin_aim(direction)
	check(expected != origin,"Rotated scene has a target in the aimed screen direction")
	if expected != origin:
		var delta: Vector2 = scene.world.cell_screen_position(expected)-scene.world.cell_screen_position(origin)
		check(delta.normalized().dot(direction) >= 0.5,"Preview remains in the aimed cone after camera rotation")
	stick(Vector2.ZERO)
	await frames()
	check(scene.selected_cell == expected,"Rotated view release selects the displayed target")

func exercise() -> void:
	picker_contract()
	await first_device_direction()
	await analog_gesture()
	for kind in ["dock","camera","solve","reserve","pause","focus","reset"]: await cancel_context(kind)
	await cancel_button()
	await release_in_menu()
	await held_stick_into_pause_menu()
	await confirm_preview()
	await partial_release()
	await dpad_and_grid()
	await pointer_navigation()
	await rotated_scene()
	if is_instance_valid(scene): scene.queue_free()
	await frames()
	for failure in failures: push_error(failure)
	print("TOWER_AIM_%s %d checks / %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
