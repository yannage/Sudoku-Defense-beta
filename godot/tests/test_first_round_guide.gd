extends SceneTree
var scene
var failures := 0
var checks := 0
const SAVE := "user://sudoku-defense-run.json"

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)

func frames(count := 3) -> void:
	for i in range(count): await process_frame

func press(key: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = key
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func exercise() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(6)
	scene.set_process(false)
	scene.run.new_run(91237,{"mode":"locked","puzzle_difficulty":"medium","combat_difficulty":"hard"})
	scene.has_active_run = true
	scene.manual_pause = true
	scene.game_speed = 4.0
	scene._save()
	var original: String = JSON.stringify(scene.run.save_data())
	var original_file: String = FileAccess.get_file_as_string(SAVE)
	for size in [Vector2i(1280,800),Vector2i(720,1280)]:
		root.size = size
		scene._layout_ui()
		scene.tutorial.start(scene)
		await frames(6)
		check(scene.tutorial.active and scene.tutorial.step == 0,"Fresh practice begins with first placement")
		check(scene.overlay.get_meta("first_round_guide",false),"Guide shows an actionable modal")
		var focused: Control = root.gui_get_focus_owner()
		check(focused is Button and root.get_visible_rect().encloses(focused.get_global_rect()),"Guide primary action fits viewport")
		await press(JOY_BUTTON_A)
		check(not scene.menu_open,"A closes instruction card without planting")
		var timer: float = scene.run.timer
		scene._process(0.04)
		check(scene.run.timer == timer,"Practice solve timer stays paused")
		var cell: int = scene.selected_cell
		await press(JOY_BUTTON_A)
		check(scene._controller_number_cell == cell,"Guide preserves Nick's square-to-tray flow")
		for i in range(9):
			if scene.selected_number == scene.run.solution[cell]: break
			await press(JOY_BUTTON_RIGHT_SHOULDER)
		await press(JOY_BUTTON_A)
		check(scene.run.towers.has(cell) and scene.selected_cell == cell,"Controller plants into original guided square")
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 1,"First tower advances to route lesson")
		scene.tutorial.event_seen({"type":"chest_open"})
		check(not scene.tutorial.reward_opened,"Opening an early chest cannot skip the post-wave reward lesson")
		scene.tutorial.continue_step()
		scene._advance()
		check(scene.run.phase == "solve","Guided route lesson cannot be accidentally skipped with Y")
		scene.tutorial.continue_step()
		for i in range(81):
			if scene.run.towers.size() >= 6: break
			if scene.run.board[i] == 0: scene._action(scene.run.place(i,scene.run.solution[i]))
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 2 and scene.run.board.has(0),"Six towers reach prepare with unfinished Sudoku")
		scene.tutorial.continue_step()
		scene._advance()
		scene.tutorial.observe()
		await frames()
		check(scene.run.phase == "prep" and scene.tutorial.step == 3,"Prepare introduces first gear")
		scene.tutorial.continue_step()
		check(scene.dock.is_open(),"Gear lesson opens real inventory")
		scene.dock.close_panel()
		scene._advance()
		check(scene.run.phase == "prep","Guide waits for a fitted module")
		scene.tutorial.continue_step()
		scene.dock._act("equip_item",[cell,scene.run.items[0].id])
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 4,"Actual equipment advances guide")
		scene.tutorial.continue_step()
		check(not scene.dock.is_open(),"Launch guidance closes Gear after socket or pointer equip")
		await press(JOY_BUTTON_Y)
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 5,"Wave launch teaches automatic defense")
		scene.tutorial.continue_step()
		var loops := 0
		while scene.run.phase == "battle" and loops < 10000:
			scene.run.update(0.05)
			loops += 1
		check(scene.run.phase == "loot","Six guided towers and starter module survive the practice wave")
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 6,"Actual wave completion introduces rewards")
		scene.tutorial.continue_step()
		check(scene.dock.is_open(),"Reward lesson opens real chest table")
		var cheapest: Dictionary = scene.run.chests[0]
		for chest: Dictionary in scene.run.chests:
			if int(chest.cost) < int(cheapest.cost): cheapest = chest
		var result: Dictionary = scene.run.open_chest(cheapest.id)
		check(result.ok and result.rewards.size() > 0,"Practice chest delivers actual gear")
		for event: Dictionary in scene.run.drain_events(): scene.tutorial.event_seen(event)
		scene.tutorial.observe()
		check(scene.tutorial.step == 7,"Only a collected reward completes guide")
		scene._save()
		check(FileAccess.get_file_as_string(SAVE) == original_file,"Practice never changes saved campaign")
		scene.tutorial.finish()
		await frames()
		check(JSON.parse_string(JSON.stringify(scene.run.save_data())) == JSON.parse_string(original),"Finishing restores exact active run including RNG")
		check(scene.manual_pause and scene.game_speed == 4.0,"Finishing restores pause and speed choices")
		scene.tutorial.start(scene)
		await frames()
		scene.tutorial.finish()
		await frames()
		check(not scene.tutorial.active and JSON.parse_string(JSON.stringify(scene.run.save_data())) == JSON.parse_string(original),"Replay can be skipped and restores previous run")
		scene.has_active_run = false
		scene.tutorial.start(scene)
		await frames()
		scene.tutorial.finish()
		await frames()
		check(scene.menu_open and not scene.has_active_run,"Skipping from initial menu returns to new-run setup")
		check(FileAccess.get_file_as_string(SAVE) == original_file,"Menu practice preserves existing disk save")
		scene.run.load_data(JSON.parse_string(original))
		scene.has_active_run = true
	print("FIRST_ROUND_GUIDE_PASS: %d checks" % checks if failures == 0 else "First round guide failures: %d" % failures)
	scene.queue_free()
	await frames()
	quit(1 if failures else 0)
