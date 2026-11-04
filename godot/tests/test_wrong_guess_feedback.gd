extends SceneTree
## Wrong-answer feedback through real mouse, touch, and joypad dispatch.
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

func pad(index: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)
	await frames(3)

func blank() -> int:
	for cell in [40,39,41,31,49]+range(81):
		if scene.run.board[cell] == 0: return cell
	return -1

func wrong_number(cell: int) -> int:
	for number in range(1,10):
		if scene.run.solution[cell] != number and not scene._number_complete(number): return number
	return -1

func reset_run() -> void:
	scene.set_process(true)
	scene._close_controller_numbers()
	if scene.menu_open: scene._close_overlay()
	scene.dock.reset_for_run()
	scene._cancel_camera_controls()
	scene.controller.reset_navigation()
	scene.controller.reset_pointer()
	scene.run.new_run(784217,{"puzzle_difficulty":"easy"})
	scene.run.timer = 100.0
	scene.has_active_run = true
	scene.selected_cell = -1
	scene.selected_number = 0
	scene.armed_item = ""
	scene.manual_pause = false
	scene.last_phase = "solve"
	scene.world.setup(scene.run)
	scene.wrong_guess_feedback.clear_feedback()
	scene._refresh()
	scene._layout_ui()
	await frames(5)

func latest() -> Dictionary:
	return scene.wrong_guess_feedback._entries.back() if not scene.wrong_guess_feedback._entries.is_empty() else {}

func check_feedback(cell: int, seconds: float, attempts: int = 1) -> void:
	var entry := latest()
	check(not entry.is_empty(),"Rejected input produces map feedback")
	if entry.is_empty(): return
	check(int(entry.cell) == cell,"Feedback stays on the rejected square")
	check(is_equal_approx(float(entry.time_penalty),seconds),"Feedback shows actual deducted seconds")
	check(int(entry.attempts) == attempts,"Repeated guesses have an explicit count")
	var rect: Rect2 = scene.wrong_guess_feedback._popup_rect(entry)
	check(scene.board_rect.encloses(rect),"Loss receipt fits inside board region")
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 23 if scene.portrait_layout else 17
	var width: float = font.get_string_size(scene.wrong_guess_feedback._receipt(entry),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	check(width <= rect.size.x-28.0+0.1,"Loss receipt is not clipped")
	var shape: PackedVector2Array = scene.wrong_guess_feedback._cell_shape(cell)
	var center: Vector2 = (shape[0]+shape[1]+shape[2]+shape[3])*0.25
	check(center.distance_to(scene.world.cell_screen_position(cell)) < 0.01,"Map marker stays centered on renderer projection")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(),"Real framebuffer is available")
	if image == null or image.is_empty() or latest().is_empty(): return
	var scale: Vector2 = Vector2(image.get_size())/root.get_visible_rect().size
	var center: Vector2 = scene.world.cell_screen_position(int(latest().cell))
	var region := Rect2(center-Vector2(6,6),Vector2(12,12))
	check(red_pixels(image,region,scale) > 5,"Rendered rejected square has a visible red X")
	var panel: Rect2 = scene.wrong_guess_feedback._popup_rect(latest())
	check(red_pixels(image,panel,scale) > 30,"Rendered time-loss receipt has visible error ink")
	DirAccess.make_dir_recursive_absolute("res://build/wrong-guess-checks")
	var variant := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	check(image.save_png("res://build/wrong-guess-checks/%s-%s-%s.png" % [variant,layout_name,name]) == OK,"Feedback capture is saved")

func red_pixels(image: Image, area: Rect2, scale: Vector2) -> int:
	var count := 0
	for y in range(maxi(0,int(area.position.y*scale.y)),mini(image.get_height(),ceili(area.end.y*scale.y))):
		for x in range(maxi(0,int(area.position.x*scale.x)),mini(image.get_width(),ceili(area.end.x*scale.x))):
			var pixel := image.get_pixel(x,y)
			if pixel.r > 0.7 and pixel.r > pixel.g*1.25 and pixel.b > 0.2: count += 1
	return count

func exercise_layout(window_size: Vector2i) -> void:
	root.size = window_size
	layout_name = "%dx%d" % [window_size.x,window_size.y]
	await reset_run()
	var feedback = scene.wrong_guess_feedback
	check(feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE and feedback.focus_mode == Control.FOCUS_NONE,"Feedback never intercepts input or focus")
	# The ordinary board -> number button path must carry the penalty and cue.
	var cell := blank()
	var wrong := wrong_number(cell)
	await click(scene.world.cell_screen_position(cell),scene.portrait_layout)
	check(scene.selected_cell == cell,"Pointer selects the intended square")
	var before: float = scene.run.timer
	await click(scene.number_buttons[wrong-1].get_global_rect().get_center(),scene.portrait_layout)
	check(scene.run.timer <= before-5.0 and scene.run.timer >= before-6.0,"Mouse/touch wrong guess deducts five seconds once")
	check(scene.run.board[cell] == 0,"Wrong input does not create a tower")
	check_feedback(cell,5.0)
	check(scene.penalty_notice_remaining > 0.0,"Timer reacts to the lost time")
	await capture("wrong-answer")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	check(saved is Dictionary and float(saved.get("state",{}).get("timer",999.0)) <= before-5.0,"Rejected input immediately persists the reduced timer")
	var restored = load("res://scripts/run.gd").new()
	check(restored.load_data(saved) and restored.timer <= before-5.0,"Loading the saved wrong guess cannot restore the deducted time")
	# A correct retry can still click through the on-map visual and earn a tower.
	await click(scene.number_buttons[int(scene.run.solution[cell])-1].get_global_rect().get_center(),scene.portrait_layout)
	check(scene.run.board[cell] == scene.run.solution[cell],"Correct retry remains available while feedback is visible")
	check(feedback._entries.is_empty(),"Correct retry removes the error marker from the new tower")
	# Multiple model events can arrive before the next rendered frame.
	feedback.play_event({"type":"invalid","reason":"wrong_answer","cell":cell,"time_penalty":5.0})
	feedback.play_event({"type":"plant","cell":cell})
	check(feedback._entries.is_empty(),"Queued wrong-then-correct events cannot leave a stale error over the tower")
	# Real controller input retains the tray for wrong guesses and exits at zero.
	await reset_run()
	cell = blank()
	wrong = wrong_number(cell)
	scene._select(cell,false,false)
	scene.selected_number = wrong
	await pad(JOY_BUTTON_A)
	check(scene._controller_number_cell == cell,"Controller A opens the tray without guessing")
	before = scene.run.timer
	await pad(JOY_BUTTON_A)
	check(scene.run.timer <= before-5.0 and scene.run.timer >= before-6.0,"Controller guess receives the same penalty")
	check(scene._controller_number_cell == cell and root.gui_get_focus_owner() == scene.number_buttons[wrong-1],"Wrong controller answer keeps focused number ready to retry")
	check_feedback(cell,5.0)
	await pad(JOY_BUTTON_A)
	check_feedback(cell,10.0,2)
	check(feedback._entries.size() == 1,"Rapid same-cell guesses have one readable receipt")
	# Freeze clock ticks only for exact fractional deduction evidence. Input still
	# travels through the real controller; zero-delta processing drains events.
	scene.set_process(false)
	feedback.clear_feedback()
	scene.run.timer = 2.375
	await pad(JOY_BUTTON_A)
	scene._process(0.0)
	check(scene.run.phase == "prep" and scene.run.timer == 0.0,"Penalty clamps at zero and enters preparation immediately")
	check(scene._controller_number_cell == -1 and not scene.number_buttons.has(root.gui_get_focus_owner()),"Penalty timeout closes the controller tray")
	check_feedback(cell,2.375)
	check(feedback._receipt(latest()).begins_with("−2.38s"),"Fractional final loss is presented accurately")
	for i in range(12): scene.world.tick(1.0/60.0)
	check_feedback(cell,2.375)
	await capture("timeout-transition")
	await pad(JOY_BUTTON_A)
	scene._process(0.0)
	check(scene.run.phase == "prep" and scene.run.timer == 0.0 and scene.run.board[cell] == 0,"Further A cannot place or skip preparation after timeout")
	scene.set_process(true)
	# All edge cells and a rotated board keep the receipt on-screen. These are
	# visual fixtures; they do not inject extra guesses into the game model.
	await reset_run()
	scene.reduced_motion = true
	scene.world.set_reduced_motion(true)
	scene.world.rotate_camera(0.55)
	scene.world.tick(0.02)
	for edge in [0,8,72,80]:
		feedback.clear_feedback()
		feedback.play_event({"type":"invalid","reason":"wrong_answer","cell":edge,"time_penalty":5.0})
		check_feedback(edge,5.0)
	await capture("reduced-motion-edge")
	feedback._process(3.0)
	check(feedback._entries.is_empty(),"Feedback expires without leaving map marks")
	feedback.play_event({"type":"invalid","cell":0,"text":"Printed clues stay fixed."})
	check(feedback._entries.is_empty(),"Non-guess failures do not claim a time penalty")
	for edge in range(8): feedback.play_event({"type":"invalid","reason":"wrong_answer","cell":edge,"time_penalty":5.0})
	check(feedback._entries.size() == 6,"Rapid changes across cells keep a bounded number of map marks")
	feedback.clear_feedback()
	check(feedback._entries.is_empty(),"Run reset clears all prior feedback")
	# Pauses, menus, and camera mode cannot submit hidden guesses.
	await reset_run()
	cell = blank()
	wrong = wrong_number(cell)
	scene._select(cell,false,false)
	scene.manual_pause = true
	before = scene.run.timer
	await click(scene.number_buttons[wrong-1].get_global_rect().get_center(),scene.portrait_layout)
	check(scene.run.timer == before and feedback._entries.is_empty(),"Paused number input cannot charge a penalty")
	scene.manual_pause = false
	scene._set_camera_mode(true)
	before = scene.run.timer
	await click(scene.number_buttons[wrong-1].get_global_rect().get_center(),scene.portrait_layout)
	check(scene.run.timer >= before-1.0 and feedback._entries.is_empty(),"Camera interaction cannot submit a wrong guess")
	scene._set_camera_mode(false)
	scene._show_menu(false)
	before = scene.run.timer
	scene._choose_number(wrong)
	await frames(3)
	check(scene.run.timer == before and feedback._entries.is_empty(),"Covered board input cannot charge a penalty")
	scene._close_overlay()
	scene.reduced_motion = false
	scene.world.set_reduced_motion(false)

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
	for window_size: Vector2i in [Vector2i(1280,800),Vector2i(390,844)]: await exercise_layout(window_size)
	scene.queue_free()
	await frames()
	if had_save:
		var file := FileAccess.open(RUN_PATH,FileAccess.WRITE)
		file.store_buffer(prior_save)
		file.close()
	else: DirAccess.remove_absolute(RUN_PATH)
	print("%s %d checks / %d failures" % ["WRONG_GUESS_FEEDBACK_PASS" if failures == 0 else "WRONG_GUESS_FEEDBACK_FAIL",checks,failures])
	quit(1 if failures else 0)
