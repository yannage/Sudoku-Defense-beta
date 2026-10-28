extends SceneTree
## The controller's board -> number tray -> same board cell loop uses actual
## joypad dispatch. Fixtures set up game state; no placement callback is invoked.
const RUN_PATH := "user://sudoku-defense-run.json"
const DEVICE := 42
var scene
var checks := 0
var failures := 0
var layout_name := ""

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(layout_name+": "+message)

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

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
	await frames(3)

func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func click(point: Vector2, touch: bool = false) -> void:
	for down in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = down
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.position = point
			event.global_position = point
			event.pressed = down
			root.push_input(event,true)
		await frames(1)
	await frames(3)

func blank(except_cell: int = -1, except_number: int = -1) -> int:
	for cell in range(81):
		if cell != except_cell and scene.run.board[cell] == 0 and scene.run.solution[cell] != except_number: return cell
	return -1

func choose(number: int) -> void:
	for i in range(9):
		if scene.selected_number == number: break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_number == number,"Available number %d can be reached" % number)

func selected_tray_button() -> Button:
	if scene.selected_number < 1 or scene.selected_number > 9: return null
	return scene.number_buttons[scene.selected_number-1]

func check_open(cell: int, message: String) -> void:
	check(scene._controller_number_cell == cell and scene.selected_cell == cell,message+": original cell is retained")
	var focused: Control = root.gui_get_focus_owner()
	check(focused == selected_tray_button(),message+": visible number receives GUI focus")
	check(focused is Button and focused.focus_mode == Control.FOCUS_ALL and not focused.disabled,message+": focused number is usable")
	if is_instance_valid(focused):
		check(root.get_visible_rect().encloses(focused.get_global_rect()),message+": focused number fits in viewport")
	check(not scene._controller_pointer_active(),message+": discrete navigation does not activate the free mouse cursor")

func check_closed(cell: int, message: String) -> void:
	check(scene._controller_number_cell == -1 and scene.selected_cell == cell,message+": focus returns to the same board cell")
	check(not scene.number_buttons.has(root.gui_get_focus_owner()),message+": no stale tray GUI focus")
	for control: Button in scene.number_buttons:
		check(control.focus_mode == Control.FOCUS_NONE,message+": tray no longer intercepts navigation")

func reset_run() -> void:
	scene._close_controller_numbers()
	if scene.menu_open: scene._close_overlay()
	scene.dock.reset_for_run()
	scene._cancel_camera_controls()
	scene.controller.reset_navigation()
	scene.controller.reset_pointer()
	scene.run.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	scene.has_active_run = true
	scene.selected_cell = -1
	scene.selected_number = 0
	scene.armed_item = ""
	scene.manual_pause = false
	scene.last_phase = "solve"
	scene.world.setup(scene.run)
	scene._refresh()
	scene._layout_ui()
	await frames(5)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	scene.notice.hide()
	scene.notice_time = 0
	scene._update_context_visibility()
	await frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/controller-number-checks")
	var variant := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	root.get_texture().get_image().save_png("res://build/controller-number-checks/%s-%s-%s.png" % [variant,layout_name,name])

func exercise_layout(window_size: Vector2i) -> void:
	root.size = window_size
	layout_name = "%dx%d" % [window_size.x,window_size.y]
	await reset_run()
	var cell: int = blank()
	var answer: int = scene.run.solution[cell]
	scene._select(cell,false,false)
	# An old selected number must not accidentally fill the newly selected cell.
	scene.selected_number = answer
	var before_credits: int = scene.run.credits
	var before_towers: int = scene.run.towers.size()
	button(JOY_BUTTON_A,true)
	await frames(12)
	check_open(cell,"Held first A opens tray")
	check(scene.run.board[cell] == 0 and scene.run.credits == before_credits,"Opening/holding the tray never plants or earns credits")
	button(JOY_BUTTON_A,false)
	await frames(4)
	check(scene.run.board[cell] == 0,"First A release cannot confirm the new tray")
	await capture("choose-number")
	var choices: Array[int] = scene._controller_number_choices()
	var previous: int = scene.selected_number
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(scene.selected_number == choices[posmod(choices.find(previous)+1,choices.size())],"D-pad right advances one tray number")
	check(scene.selected_cell == cell,"Tray navigation never moves the board target")
	await press(JOY_BUTTON_DPAD_LEFT)
	check(scene.selected_number == previous,"D-pad left reverses the tray step")
	await press(JOY_BUTTON_DPAD_DOWN)
	check(scene.selected_number == choices[posmod(choices.find(previous)+1,choices.size())],"D-pad down cycles forward in the single-row tray")
	await press(JOY_BUTTON_DPAD_UP)
	check(scene.selected_number == previous,"D-pad up cycles backward in the tray")
	axis(JOY_AXIS_LEFT_X,0.9)
	await frames(2)
	axis(JOY_AXIS_LEFT_X,0.0)
	await frames(3)
	check(scene.selected_number == choices[posmod(choices.find(previous)+1,choices.size())] and scene.selected_cell == cell,"Left stick chooses a tray number instead of a board cell")
	await choose(answer)
	button(JOY_BUTTON_A,true)
	await frames(12)
	check(scene.run.board[cell] == answer and scene.run.towers.size() == before_towers+1,"Second held A plants exactly one number")
	var planted_credits: int = scene.run.credits
	button(JOY_BUTTON_A,false)
	await frames(4)
	check(scene.run.credits == planted_credits and not scene.dock.is_open(),"Commit release cannot duplicate rewards or open the new tower")
	check_closed(cell,"Successful placement")
	await capture("returned-to-cell")
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(scene.selected_cell != cell,"Next D-pad press navigates the board after placement")
	# Cancel restores the same cell and cannot plant even with a valid number.
	cell = blank()
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	await choose(int(scene.run.solution[cell]))
	await press(JOY_BUTTON_B)
	check_closed(cell,"B cancels number selection")
	check(scene.run.board[cell] == 0,"B never places the pending number")
	# Incorrect solve answers retain tray focus for another attempt.
	await press(JOY_BUTTON_A)
	var wrong: int = 1 if scene.run.solution[cell] != 1 else 2
	await choose(wrong)
	before_credits = scene.run.credits
	before_towers = scene.run.towers.size()
	await press(JOY_BUTTON_A)
	check_open(cell,"Rejected answer")
	check(scene.run.board[cell] == 0 and scene.run.towers.size() == before_towers and scene.run.credits == before_credits,"Rejected answer changes neither board nor rewards")
	await choose(int(scene.run.solution[cell]))
	await press(JOY_BUTTON_A)
	check_closed(cell,"Retry succeeds")
	check(scene.run.board[cell] == scene.run.solution[cell],"Retry fills the originally selected cell")
	# A fixed clue and a planted tower keep their previous inspection behavior.
	var fixed := -1
	for i in range(81):
		if scene.run.givens[i]: fixed = i; break
	scene._select(fixed,false,false)
	await press(JOY_BUTTON_A)
	check(scene._controller_number_cell == -1 and scene.run.board[fixed] == scene.run.solution[fixed],"A on a fixed clue never opens a placement tray")
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	check(scene.dock.is_open() and scene._controller_number_cell == -1,"A on a tower still opens its workshop")
	await press(JOY_BUTTON_B)
	# Modal/UI commands cancel an active tray and cannot submit its number.
	cell = blank()
	for command in [JOY_BUTTON_START,JOY_BUTTON_BACK,JOY_BUTTON_X,JOY_BUTTON_LEFT_STICK]:
		scene._select(cell,false,false)
		await press(JOY_BUTTON_A)
		await press(command)
		check(scene._controller_number_cell == -1 and scene.run.board[cell] == 0,"Menu/gear/camera command cancels pending placement")
		check(not scene.number_buttons.has(root.gui_get_focus_owner()),"Overlay commands release covered tray focus")
		await press(JOY_BUTTON_B)
		check(scene.run.board[cell] == 0,"Closing the overlay does not submit its old pending number")
	# A in an actual pause menu belongs exclusively to Resume.
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_START)
	await press(JOY_BUTTON_A)
	check(not scene.menu_open and scene._controller_number_cell == -1 and scene.run.board[cell] == 0,"A resumes the pause menu without placing behind it")
	await press(JOY_BUTTON_A)
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await frames(2)
	check_closed(cell,"Window focus loss")
	check(scene.run.board[cell] == 0,"Losing window focus never confirms a pending number")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await press(JOY_BUTTON_A)
	scene.controller._connection_changed(DEVICE,false)
	await frames(3)
	check(scene.menu_open and scene._controller_number_cell == -1 and scene.run.board[cell] == 0,"Controller loss pauses and discards pending number selection")
	scene.controller._connection_changed(DEVICE,true)
	await press(JOY_BUTTON_START)
	check(not scene.menu_open,"Reconnected controller resumes without restoring a stale tray")
	# Right-stick takeover switches back to the existing free-pointer system.
	await press(JOY_BUTTON_A)
	axis(JOY_AXIS_RIGHT_X,0.6)
	await frames(2)
	axis(JOY_AXIS_RIGHT_X,0.0)
	await frames(2)
	check(scene._controller_number_cell == -1 and scene._controller_pointer_active() and scene.run.board[cell] == 0,"Right stick cancels tray mode without a phantom click")
	# Real pointer takeover selects a different board cell, not the saved tray cell.
	var other: int = blank(cell)
	for use_touch in [false,true]:
		scene._select(cell,false,false)
		await press(JOY_BUTTON_A)
		await click(scene.world.cell_screen_position(other),use_touch)
		check(scene._controller_number_cell == -1 and scene.selected_cell == other,"Mouse/touch takeover discards the old placement target")
		check(scene.run.board[cell] == 0 and scene.run.board[other] == 0,"Pointer selection still waits for a separate number choice")
	# Rotation changes screen coordinates, never the cell stored by tray mode.
	scene.world.rotate_camera(1.1)
	for i in range(20): scene.world.tick(0.05)
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	await choose(int(scene.run.solution[cell]))
	await press(JOY_BUTTON_A)
	check_closed(cell,"Rotated board placement")
	check(scene.run.board[cell] == scene.run.solution[cell] and scene.run.board[other] == 0,"Rotated placement uses original cell identity")
	# Completed Solve families are skipped, but no candidate/solution filtering occurs.
	await reset_run()
	for i in range(81):
		if scene.run.solution[i] == 4: scene.run.board[i] = 4
	cell = blank(-1,4)
	scene._select(cell,false,false)
	scene.selected_number = 4
	scene._refresh()
	await press(JOY_BUTTON_A)
	choices = scene._controller_number_choices()
	check(choices.size() == 8 and not choices.has(4),"Completed family is the only omitted Solve number")
	check(scene.selected_number != 4,"Opening skips a previously selected completed family")
	for i in range(choices.size()):
		await press(JOY_BUTTON_RIGHT_SHOULDER)
		check(scene.selected_number != 4 and scene.selected_cell == cell,"Shoulder navigation skips completed families without moving target")
	await choose(3)
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(scene.selected_number == 5,"D-pad navigation skips the completed family")
	await choose(9)
	await press(JOY_BUTTON_DPAD_RIGHT)
	check(scene.selected_number == 1,"Tray selection wraps from last to first available number")
	await press(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.selected_number == 9,"Left shoulder wraps backward through available numbers")
	# Expiry and explicit phase advancement must discard pending Solve selection.
	scene.run.timer = 0.001
	scene._process(0.05)
	await frames(4)
	check(scene.run.phase == "prep" and scene._controller_number_cell == -1,"Solve timer expiry cancels the pending number tray")
	await press(JOY_BUTTON_A)
	check(scene.run.board[cell] == 0 and scene._controller_number_cell == -1,"A after expiry cannot place into preparation")
	await reset_run()
	cell = blank()
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_Y)
	check(scene.run.phase == "prep" and scene._controller_number_cell == -1 and scene.run.board[cell] == 0,"Y closes the tray and advances without placing")
	# Battle trays offer reserves only, including intentionally wrong towers.
	await reset_run()
	cell = blank()
	scene.run.advance_phase()
	scene.run.advance_phase()
	scene.last_phase = "battle"
	for i in range(1,10): scene.run.inventory[i] = 0
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	check(scene._controller_number_cell == -1 and scene.run.board[cell] == 0,"No-reserve battle cannot open an empty tray or place for free")
	wrong = 1 if scene.run.solution[cell] != 1 else 2
	scene.run.inventory[wrong] = 1
	scene._refresh()
	await press(JOY_BUTTON_A)
	check_open(cell,"Battle reserve selection")
	check(scene._controller_number_choices() == [wrong] and scene.selected_number == wrong,"Battle offers exactly the available reserve")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_number == wrong,"A one-item reserve tray cycles safely")
	var corruption_before: int = scene.run.corruption
	await press(JOY_BUTTON_A)
	check_closed(cell,"Battle reserve placement")
	check(scene.run.board[cell] == wrong and scene.run.inventory[wrong] == 0 and scene.run.corruption == corruption_before+1,"Emergency wrong-number placement preserves reserve consumption and corruption")

func exercise() -> void:
	var had_save := FileAccess.file_exists(RUN_PATH)
	var prior_save: PackedByteArray = FileAccess.get_file_as_bytes(RUN_PATH) if had_save else PackedByteArray()
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(5)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "784217"
	scene._start_run()
	for size: Vector2i in [Vector2i(1280,800),Vector2i(390,844)]:
		await exercise_layout(size)
	scene.queue_free()
	await frames()
	if had_save:
		var file := FileAccess.open(RUN_PATH,FileAccess.WRITE)
		file.store_buffer(prior_save)
		file.close()
	else: DirAccess.remove_absolute(RUN_PATH)
	print("%s %d checks / %d failures" % ["CONTROLLER_NUMBER_PICKER_PASS" if failures == 0 else "CONTROLLER_NUMBER_PICKER_FAIL",checks,failures])
	quit(1 if failures else 0)
