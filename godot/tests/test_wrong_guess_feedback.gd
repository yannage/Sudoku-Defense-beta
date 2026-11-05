extends SceneTree
## Wrong-answer feedback through real mouse, touch, and joypad dispatch.
const DEVICE := 42
var scene
var checks := 0
var failures := 0
var layout_name := ""
var profile_root := ""

class FailingSave:
	extends "res://scripts/run_save.gd"
	var fail_writes := false
	func write_run(data: Dictionary) -> bool:
		if fail_writes: return false
		return super.write_run(data)

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
	scene.run.new_run(784217,{"puzzle_difficulty":"easy","achievement_run_id":"wrong-feedback-%s" % Time.get_ticks_usec()})
	scene.run.timer = 100.0
	scene.has_active_run = true
	scene.selected_cell = -1
	scene.selected_number = 0
	scene.armed_item = ""
	scene.manual_pause = false
	scene.last_phase = "solve"
	scene.world.setup(scene.run)
	scene.wrong_guess_feedback.clear_feedback()
	scene.penalty_notice_remaining = 0.0
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
	var saved: Dictionary = scene.run_save.read_run()
	check(not saved.is_empty() and float(saved.get("data",{}).get("state",{}).get("timer",999.0)) <= before-5.0,"Rejected input immediately persists the reduced timer through the journal")
	var restored = load("res://scripts/run.gd").new()
	check(restored.load_data(saved.get("data",{})) and restored.timer <= before-5.0,"Loading the saved wrong guess cannot restore the deducted time")
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
	var expired: Dictionary = scene.run_save.read_run()
	check(not expired.is_empty() and expired.data.state.phase == "prep" and float(expired.data.state.timer) == 0.0,"Penalty expiry persists Prepare with an exact zero timer")
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

func profile_bytes() -> Dictionary:
	var result := {}
	for path: String in [scene.run_save.file_path,scene.run_save.file_path+".pending",scene.run_save.file_path+".bak",scene.achievements.store.file_path,scene.achievements.store.file_path+".pending",scene.achievements.store.file_path+".bak"]:
		result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return result

func exercise_profile_boundaries() -> void:
	root.size = Vector2i(1280,800)
	layout_name = "profile-boundaries"
	await reset_run()
	scene.set_process(false)
	var feedback = scene.wrong_guess_feedback
	var cell := blank()
	var wrong := wrong_number(cell)
	scene.run.timer = 17.375
	scene._select(cell,false,false)
	scene._choose_number(wrong)
	scene._process(0.0)
	check(scene.run.timer == 12.375,"Precise wrong-guess timer is retained by the active scene")
	check_feedback(cell,5.0)
	check(scene._load(),"Actual Main load accepts the reduced-time journal")
	check(scene.run.timer == 12.375 and scene.run.phase == "solve","Actual Main resume does not restore deducted time")
	check(feedback._entries.is_empty() and scene.penalty_notice_remaining == 0.0,"Loading clears stale map markers and timer tint")
	scene.world.setup(scene.run)
	scene._refresh()
	var original: String = JSON.stringify(scene.run.save_data(),"",true,true)
	var bytes_before := profile_bytes()
	# Practice uses the same placement rule but never writes its cost or facts
	# into the ordinary run/achievement journal, including when skipped early.
	scene.tutorial.start(scene)
	await frames()
	check(feedback._entries.is_empty(),"Starting practice has no previous-run error marker")
	scene.tutorial.continue_step()
	cell = scene.tutorial.target_cell
	wrong = wrong_number(cell)
	scene._select(cell,false,false)
	var practice_before: float = scene.run.timer
	scene._choose_number(wrong)
	scene._process(0.0)
	check(scene.run.timer == practice_before-5.0,"Wrong practice guess exercises the ordinary model penalty")
	check_feedback(cell,5.0)
	check(profile_bytes() == bytes_before,"Practice penalty leaves all normal save and achievement journal bytes unchanged")
	scene.tutorial.finish()
	check(not scene.tutorial.active and JSON.stringify(scene.run.save_data(),"",true,true) == original,"Skipping practice restores the complete normal run and reduced timer")
	check(feedback._entries.is_empty() and scene.penalty_notice_remaining == 0.0,"Leaving practice cannot paint its wrong-answer feedback onto the restored board")
	check(profile_bytes() == bytes_before,"Leaving practice preserves the normal journals")
	# Repeated genuine wrong answers can expire an empty practice board. The
	# guide must still offer a way into Battle instead of requiring an impossible
	# module fit when no tower exists. Every guess uses the ordinary input action.
	scene.tutorial.start(scene)
	await frames()
	scene.tutorial.continue_step()
	cell = scene.tutorial.target_cell
	wrong = wrong_number(cell)
	scene._select(cell,false,false)
	var practice_guesses := 0
	for attempt in range(200):
		if scene.run.phase != "solve": break
		scene._choose_number(wrong)
		scene._process(0.0)
		practice_guesses += 1
	await frames()
	check(practice_guesses > 1 and scene.run.phase == "prep" and scene.run.timer == 0.0,"Repeated practice mistakes exhaust Solve and enter Prepare")
	check(scene.run.towers.is_empty() and scene.tutorial.step == 3,"Expired practice reaches the guide's empty-tower preparation case")
	check(scene.tutorial.can_advance(),"Empty practice preparation has an escape path without an impossible equip action")
	check(profile_bytes() == bytes_before,"Repeated practice penalties never write normal run or achievement journals")
	scene.tutorial.continue_step()
	scene._process(0.0)
	await frames()
	check(scene.tutorial.active and scene.run.phase == "battle" and scene.run.towers.is_empty(),"Guide continuation launches the actual empty-board Battle")
	check(profile_bytes() == bytes_before,"Launching the empty practice wave preserves normal journal bytes")
	scene.tutorial.finish()
	check(not scene.tutorial.active and JSON.stringify(scene.run.save_data(),"",true,true) == original,"Leaving expired practice restores the exact prior run and timer")
	check(feedback._entries.is_empty() and scene.penalty_notice_remaining == 0.0,"Leaving expired practice clears its map feedback")
	check(profile_bytes() == bytes_before,"Expired practice exit preserves normal run and achievement journals")
	# A rejected answer is still a save attempt; failed storage must report it
	# and retain the in-memory deduction without overwriting the previous save.
	cell = blank()
	wrong = wrong_number(cell)
	scene._select(cell,false,false)
	var before: float = scene.run.timer
	scene.run_save.fail_writes = true
	scene._choose_number(wrong)
	scene._process(0.0)
	check(scene.run.timer == maxf(0.0,before-5.0),"A failed save does not refund the penalty in memory")
	check(scene.save_failed and scene.hud_nodes.menu.text == "Save!","Rejected-action save failure keeps the existing visible recovery warning")
	check(FileAccess.get_file_as_bytes(scene.run_save.file_path) == bytes_before[scene.run_save.file_path],"Failed write preserves the previous normal save")
	scene.run_save.fail_writes = false
	check(scene._save() and not scene.save_failed,"Existing retry-save path commits the pending reduced timer")
	var persisted: Dictionary = scene.run_save.read_run()
	check(float(persisted.data.state.timer) == scene.run.timer,"Retry saves the reduced timer, not the pre-penalty snapshot")
	# Backups retain the already-deducted timer and actual Main recovery resets
	# temporary feedback. Only this synthetic profile is fault-injected.
	check(scene._save(),"Create a last-good backup with the reduced timer")
	var reduced: float = scene.run.timer
	var broken := FileAccess.open(scene.run_save.file_path,FileAccess.WRITE)
	check(broken != null,"Open disposable primary for corrupt-save recovery fixture")
	if broken != null:
		broken.store_string("{broken synthetic save")
		broken.close()
		check(scene._load() and scene.save_recovered,"Actual Main load recovers the last-good reduced-time backup")
		check(scene.run.timer == reduced,"Backup recovery does not undo the penalty")
		check(feedback._entries.is_empty() and scene.penalty_notice_remaining == 0.0,"Backup recovery clears the old board's feedback")
		check(FileAccess.get_file_as_string(scene.run_save.file_path) == "{broken synthetic save","Read-only recovery leaves corrupt evidence intact")
	# Retry is a result-only action. It must leave an active Solve run alone;
	# use an explicit terminal-state UI fixture, as in test_results_ui.gd, to
	# exercise the actual retry reset rather than bypassing that safety guard.
	feedback.play_event({"type":"invalid","reason":"wrong_answer","cell":cell,"time_penalty":5.0})
	scene.penalty_notice_remaining = 2.0
	scene._retry_same_seed()
	check(scene.run.phase == "solve" and scene.run.timer == reduced and not feedback._entries.is_empty(),"Retry remains unavailable during active Solve without clearing its feedback")
	scene.run.phase = "lost"
	scene.run.health = 0.0
	scene._retry_same_seed()
	check(scene.run.phase == "solve" and scene.run.round_no == 1,"Finished-run retry starts a fresh first round")
	check(feedback._entries.is_empty() and scene.penalty_notice_remaining == 0.0,"Retry seed clears prior-board feedback")
	scene.set_process(true)

func exercise() -> void:
	profile_root = "user://wrong-guess-feedback-%s" % Time.get_ticks_usec()
	check(DirAccess.make_dir_recursive_absolute(profile_root) == OK,"Create disposable feedback profile")
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = profile_root.path_join("settings.json")
	scene.run_save = FailingSave.new()
	scene.run_save.file_path = profile_root.path_join("run.json")
	root.add_child(scene)
	await frames(5)
	check(not scene.steam_platform.get_status().available,"Feedback regression never connects to real Steam")
	check(str(scene.achievements.store.file_path).begins_with(profile_root),"Achievement evidence stays inside the disposable feedback profile")
	scene.muted = true
	scene.sound.set_muted(true)
	scene.seed_input.text = "784217"
	scene._start_run()
	check(scene.has_active_run and not scene.save_failed,"Ordinary run starts in the isolated journal profile")
	for window_size: Vector2i in [Vector2i(1280,800),Vector2i(390,844)]: await exercise_layout(window_size)
	await exercise_profile_boundaries()
	scene.queue_free()
	await frames()
	# Retain this synthetic profile as test evidence; no real save is restored
	# or deleted by this suite. The runner supplies an isolated user:// root.
	print("%s %d checks / %d failures" % ["WRONG_GUESS_FEEDBACK_PASS" if failures == 0 else "WRONG_GUESS_FEEDBACK_FAIL",checks,failures])
	quit(1 if failures else 0)

