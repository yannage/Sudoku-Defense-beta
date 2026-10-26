extends SceneTree
## Exercise real input dispatch, readable layouts, and exact forecast presentation.
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

func find_button(scope: Node, id: String) -> Button:
	for control in scope.find_children("*","Button",true,false):
		if str(control.get_meta("focus_id","")) == id: return control
	return null

func click(point: Vector2, touch: bool = false) -> void:
	for pressed in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = point
			event.index = 0
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
		await frames(1)
	await frames(4)

func pad(button: int) -> void:
	for pressed in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)
	await frames(3)

func fit_text(button: Button) -> bool:
	var skin: StyleBox = button.get_theme_stylebox("normal")
	var available: float = button.size.x-skin.get_content_margin(SIDE_LEFT)-skin.get_content_margin(SIDE_RIGHT)
	for line: String in button.text.split("\n"):
		if button.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x > available+0.1: return false
	return true

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture-tactics" not in OS.get_cmdline_user_args(): return
	scene.notice.hide()
	scene.notice_time = 0
	scene._update_context_visibility()
	await frames(3)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/tactics-checks")
	var variant := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	root.get_texture().get_image().save_png("res://build/tactics-checks/%s-%s-%s.png" % [variant,layout_name,name])

func exercise_layout(window_size: Vector2i) -> void:
	layout_name = "%dx%d" % [window_size.x,window_size.y]
	root.size = window_size
	scene.run.new_run(784217,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	scene.run.round_no = 5
	scene.run.corruption = 3
	scene.run.credits = 500
	scene.selected_cell = -1
	scene.selected_number = 0
	scene.manual_pause = false
	scene.dock.reset_for_run()
	scene.world.setup(scene.run)
	scene.last_phase = "solve"
	scene._layout_ui()
	await frames(6)
	var cell := -1
	for i in range(81):
		if int(scene.run.board[i]) == 0:
			cell = i
			break
	scene.run.place(cell,int(scene.run.solution[cell]))
	scene._advance()
	scene.run.update(1.0) # Finish tower growth before checking inspection purity.
	await frames(5)
	var board_before: Array = scene.run.board.duplicate()
	var state_before: Dictionary = scene.run.save_data()
	var forecast: Dictionary = scene.run.wave_forecast()
	var viewport: Rect2 = root.get_visible_rect()
	var intel: Button = scene.hud_nodes.intel
	check(intel.is_visible_in_tree() and viewport.encloses(intel.get_global_rect()),"Prep exposes Wave intel within viewport")
	check(fit_text(intel),"Prep intel label fits including the boss warning")
	check(not intel.get_global_rect().intersects(scene.board_rect),"Intel preserves the board's interactive area")
	check(not intel.get_global_rect().intersects(scene.next_button.get_global_rect()),"Intel does not overlap the primary launch action")
	if not scene.portrait_layout:
		check(not intel.get_global_rect().intersects(scene.phase_detail.get_global_rect()),"Prep forecast and its action have separate bounds")
		check(scene.phase_detail.text.contains(str(forecast.count)) and scene.phase_detail.text.contains("BOSS"),"Desktop prep shows exact enemy count and boss warning")
	else:
		check(intel.text.contains(str(forecast.count)) and intel.text.contains("BOSS"),"Portrait prep shows exact enemy count and boss warning")
	check(scene.next_button.text == "Launch wave" and not scene.next_button.disabled,"Launch remains available from the existing primary action")
	await click(intel.get_global_rect().get_center(),scene.portrait_layout)
	check(scene.menu_open and is_instance_valid(scene.overlay) and bool(scene.overlay.get_meta("wave_intel",false)),"Mouse/touch opens Wave intel")
	if not scene.menu_open: return
	var scroll: ScrollContainer = scene.overlay.find_children("*","ScrollContainer",true,false)[0]
	var boss_card: Control
	var group_count := 0
	var visible_text: Array[String] = []
	for text_label in scene.overlay.find_children("*","Label",true,false): visible_text.append(text_label.text)
	check("WAVE INTEL  /  ROUND %02d" % scene.run.round_no in visible_text,"Intel names the current round")
	check("Current corruption: %d  ·  Enemy health ×%.2f\nOne enemy arrives every %.2f seconds." % [int(scene.run.corruption),float(forecast.corruption_multiplier),float(forecast.spawn_interval)] in visible_text,"Visible corruption multiplier and spawn interval match the model")
	for control in scene.overlay.find_children("*","Control",true,false):
		if control.has_meta("forecast_total"):
			check(control.text == "%d enemies incoming" % int(forecast.count),"Visible total exactly matches the current wave")
		if control.has_meta("forecast_group"):
			var group: Dictionary = control.get_meta("forecast_group")
			check(group == forecast.groups[group_count],"Each displayed group uses exact count and combat stats")
			var labels: Array[Node] = control.find_children("*","Label",true,false)
			check(labels[0].text.begins_with("%d ×" % int(group.count)) and labels[1].text == "%.1f HP  ·  %.2f speed  ·  %d core damage" % [float(group.health),float(group.speed),int(group.core_damage)],"Visible count, health, speed, and core damage match the forecast")
			group_count += 1
			if str(group.kind) == "boss": boss_card = control
	check(group_count == forecast.groups.size() and is_instance_valid(boss_card),"All groups including the boss are presented")
	check(viewport.encloses(scroll.get_global_rect()),"Intel scroll area fits the viewport")
	var close: Button = find_button(scene.overlay,"wave:close")
	check(root.gui_get_focus_owner() == close,"Intel gives controller focus to a safe close action")
	await capture("intel")
	var reached_boss := false
	for i in range(20):
		await pad(JOY_BUTTON_DPAD_DOWN)
		if not reached_boss and scroll.get_global_rect().encloses(boss_card.get_global_rect()):
			reached_boss = true
			await capture("intel-boss")
	check(scroll.scroll_vertical > 0 and reached_boss,"Real D-pad navigation scrolls all the way to the boss profile")
	check(root.gui_get_focus_owner() == find_button(scene.overlay,"wave:close_bottom"),"At the bottom, a visible Back action receives focus")
	await pad(JOY_BUTTON_B)
	check(not scene.menu_open and not scene.manual_pause,"B closes intel and resumes the prior unpaused state")
	check(scene.run.board == board_before and scene.run.phase == "prep","Closing intel does not plant a number or launch the wave")
	check(scene.run.save_data() == state_before,"Opening, scrolling, and closing intel preserves the full run including resources, items, IDs, and RNG")
	# Start → Wave intel gives controller access without a free cursor.
	await pad(JOY_BUTTON_START)
	var pause_intel: Button = find_button(scene.overlay,"wave:intel")
	check(is_instance_valid(pause_intel),"Pause menu exposes Wave intel to controllers")
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner() == pause_intel,"D-pad reaches intel from the pause menu's Resume action")
	await pad(JOY_BUTTON_A)
	check(bool(scene.overlay.get_meta("wave_intel",false)),"A opens intel from the pause menu exactly once")
	await pad(JOY_BUTTON_A)
	check(not scene.menu_open and scene.run.board == board_before and scene.run.phase == "prep","A on Back closes without board or phase input leakage")
	# The workshop must retain focus and scroll position when target changes.
	scene._select(cell,true)
	await frames(6)
	var strongest: Button = find_button(scene.dock._shell,"target:strongest")
	check(is_instance_valid(strongest),"Tower workshop offers explicit target choices")
	if not is_instance_valid(strongest): return
	strongest.grab_focus()
	scene.dock._scroll.ensure_control_visible(strongest)
	await frames(3)
	var previous: Rect2
	for mode: String in ["first","strongest","nearest"]:
		var option := find_button(scene.dock._shell,"target:"+mode)
		check(fit_text(option),"Target label fits: "+mode)
		check(scene.dock._scroll.get_global_rect().encloses(option.get_global_rect()),"Target choice is fully visible after controller focus: "+mode)
		check(previous.size == Vector2.ZERO or not previous.intersects(option.get_global_rect()),"Target buttons do not overlap: "+mode)
		previous = option.get_global_rect()
	await capture("targets")
	await pad(JOY_BUTTON_A)
	check(scene.run.towers[cell].target_priority == "strongest","A changes only this tower's priority to Strongest")
	var saved_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	var restored = preload("res://scripts/run.gd").new()
	var loaded: bool = saved_data is Dictionary and restored.load_data(saved_data)
	check(loaded and restored.towers.has(cell) and str(restored.towers[cell].target_priority) == "strongest","UI target selection is saved and survives loading a fresh run model")
	check(str(root.gui_get_focus_owner().get_meta("focus_id","")) == "target:strongest","Target refresh preserves controller focus")
	var nearest: Button = find_button(scene.dock._shell,"target:nearest")
	scene.dock._scroll.ensure_control_visible(nearest)
	await frames(3)
	await click(nearest.get_global_rect().get_center())
	check(scene.run.towers[cell].target_priority == "nearest","First mouse click after controller use selects Nearest")
	strongest = find_button(scene.dock._shell,"target:strongest")
	strongest.grab_focus()
	scene.dock._scroll.ensure_control_visible(strongest)
	await frames(3)
	await pad(JOY_BUTTON_A)
	var first: Button = find_button(scene.dock._shell,"target:first")
	scene.dock._scroll.ensure_control_visible(first)
	await frames(3)
	await click(first.get_global_rect().get_center(),true)
	check(scene.run.towers[cell].target_priority == "first","First touch after controller use selects First")
	check(scene.run.board == board_before,"Priority selection never plants or removes Sudoku numbers")
	await pad(JOY_BUTTON_B)
	check(not scene.dock.is_open() and scene.run.board == board_before,"B closes the workshop without input leakage")
	# Intel also pauses the ticking solve clock and preserves a manual pause.
	scene.run.phase = "solve"
	scene.last_phase = "solve"
	scene.manual_pause = false
	scene._show_wave_intel()
	var timer_before: float = scene.run.timer
	scene._process(0.05)
	check(scene.run.timer == timer_before,"Forecast inspection freezes the solve clock")
	await pad(JOY_BUTTON_B)
	check(not scene.manual_pause,"Closing solve intel resumes an originally running clock")
	scene.manual_pause = true
	scene._show_wave_intel()
	await pad(JOY_BUTTON_B)
	check(scene.manual_pause,"Closing intel preserves an existing manual pause")
	scene.manual_pause = false
	scene.run.phase = "prep"
	scene.last_phase = "prep"
	scene.run.round_no = 4
	scene._show_wave_intel()
	var warnings := 0
	for control in scene.overlay.find_children("*","Control",true,false):
		if control.has_meta("forecast_boss"): warnings += 1
	check(warnings == 0,"Ordinary waves do not display a stale boss warning")
	scene._close_overlay()
	scene._advance()
	await frames(2)
	check(scene.run.phase == "battle" and not scene.hud_nodes.intel.visible,"Existing Launch wave starts combat and hides the prebattle forecast")
	scene._show_wave_intel()
	check(not scene.menu_open,"Live combat cannot show a misleading prebattle forecast")

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
	for size: Vector2i in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(390,844),Vector2i(844,390)]:
		await exercise_layout(size)
	scene.queue_free()
	await frames()
	if had_save:
		var file := FileAccess.open(RUN_PATH,FileAccess.WRITE)
		file.store_buffer(prior_save)
		file.close()
	else: DirAccess.remove_absolute(RUN_PATH)
	print("%s %d checks / %d failures" % ["TACTICS_UI_PASS" if failures == 0 else "TACTICS_UI_FAIL",checks,failures])
	quit(1 if failures else 0)
