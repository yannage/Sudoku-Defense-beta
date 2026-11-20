extends SceneTree
var scene
var failures := 0
var checks := 0
var save_path := ""

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
	save_path = "user://guide-test-%d.json" % Time.get_ticks_usec()
	scene.run_save.file_path = save_path
	scene.achievements.configure(save_path + ".achievements", "", "")
	scene.run.new_run(91237,{"mode":"locked","puzzle_difficulty":"medium","combat_difficulty":"hard","achievement_run_id":"guide-owner-run"})
	var initial_cell: int = scene.run.board.find(0)
	scene.run.place(initial_cell,scene.run.solution[initial_cell])
	scene.has_active_run = true
	scene.manual_pause = true
	scene.game_speed = 4.0
	scene._save()
	var original: String = JSON.stringify(scene.run.save_data())
	var original_file: String = FileAccess.get_file_as_string(save_path)
	var original_achievements: String = FileAccess.get_file_as_string(save_path + ".achievements")
	check(scene.achievements.pending_keys() == ["SD_FIRST_PLANT"],"Real run starts with one durable offline unlock before practice")
	for size in [Vector2i(1280,800),Vector2i(720,1280)]:
		root.size = size
		scene._layout_ui()
		scene.tutorial.start(scene)
		await frames(6)
		check(scene.tutorial.active and scene.tutorial.step == 0,"Fresh practice begins with first placement")
		check(not scene.menu_open and scene.overlay == null,"Practice starts directly on the board")
		check(not scene.hud_nodes.camp.visible and not scene.loot_button.visible and not scene.next_button.visible,"First seed keeps unrelated controls off the board")
		check(scene.tutorial.marker.visible and scene.tutorial.target_cell == scene.selected_cell,"Board outline points to the real first square")
		check(scene.phase_detail.visible and root.get_visible_rect().encloses(scene.phase_detail.get_global_rect()),"Guide instruction fits viewport")
		scene._help()
		await frames()
		check(scene.overlay.get_meta("first_round_guide",false),"Help and skip remain available on demand")
		await press(JOY_BUTTON_A)
		check(not scene.menu_open and scene.run.towers.is_empty(),"Return from Help restores the board without auto-planting")
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
		check(not scene.menu_open and scene.selected_number == 0,"First placement leaves the board visible without a stale seed brush")
		scene._advance()
		check(scene.run.phase == "solve" and not scene.menu_open,"Early advance keeps the board and target visible")
		var second: int = scene.tutorial.target_cell
		check(cell / 27 != second / 27,"Second suggestion lets the player steer another three-row band")
		var first_route: Array = scene.run.route.duplicate()
		scene._select(second)
		scene.number_buttons[scene.run.solution[second]-1].pressed.emit()
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 2 and scene.run.towers.size() == 2 and scene.run.route != first_route,"Two real answers change the route and unlock preparation")
		scene._advance()
		scene.tutorial.observe()
		await frames()
		check(scene.run.phase == "prep" and scene.tutorial.step == 3 and not scene.menu_open,"Prepare introduces gear on the real board")
		scene._advance()
		check(scene.run.phase == "prep","Guide waits for a fitted module")
		await press(JOY_BUTTON_A)
		check(scene.dock.is_open() and scene.dock.current_panel == "tower","Activating the tower opens its real sockets")
		await press(JOY_BUTTON_A)
		check(scene.dock.controller_picker_slot >= 0,"Choosing a socket opens its module picker")
		await press(JOY_BUTTON_A)
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 4 and scene.run.towers[second].attachments.size() == 1,"Fitting a module on the highlighted tower advances the guide")
		await press(JOY_BUTTON_B)
		check(not scene.dock.is_open(),"Closing the workshop exposes the route")
		await press(JOY_BUTTON_Y)
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 5 and not scene.menu_open,"Wave launch leaves automatic defense visible")
		var loops := 0
		while scene.run.phase == "battle" and loops < 10000:
			scene.run.update(0.05)
			loops += 1
		check(scene.run.phase == "loot","Two guided towers and starter module survive the practice wave")
		scene.tutorial.observe()
		await frames()
		check(scene.tutorial.step == 6 and scene.loot_button.visible,"Actual wave completion reveals Chests")
		scene.loot_button.pressed.emit()
		check(scene.dock.is_open(),"Reward lesson opens real chest table")
		var cheapest: Dictionary = scene.run.chests[0]
		for chest: Dictionary in scene.run.chests:
			if int(chest.cost) < int(cheapest.cost): cheapest = chest
		var result: Dictionary = scene.run.open_chest(cheapest.id)
		check(result.ok and result.rewards.size() > 0,"Practice chest delivers actual gear")
		for event: Dictionary in scene.run.drain_events(): scene.tutorial.event_seen(event)
		scene.tutorial.observe()
		check(scene.tutorial.step == 7,"Only a collected reward completes guide")
		check(scene.run.achievement_stats.counters.manual_placements == 2 and scene.run.achievement_stats.counters.module_equips > 0 and scene.run.achievement_stats.counters.waves_cleared == 1 and scene.run.achievement_stats.counters.chests_opened == 1,"Completed practice exercised real placement, gear, wave and chest counters")
		check(scene.run.achievement_stats.run_id.is_empty() and preload("res://scripts/achievement_rules.gd").evaluate(scene.run).is_empty(),"Complete practice has no eligible achievement evidence")
		scene._observe_achievements()
		scene._save()
		check(FileAccess.get_file_as_string(save_path) == original_file,"Practice never changes saved campaign")
		check(FileAccess.get_file_as_string(save_path + ".achievements") == original_achievements,"Full practice preserves the original offline achievement journal byte-for-byte")
		var restarted_profile = preload("res://scripts/achievement_profile.gd").new()
		restarted_profile.configure(save_path + ".achievements", "", "")
		check(restarted_profile.pending_keys() == ["SD_FIRST_PLANT"],"Restart after practice retains only the real run's queued unlock")
		scene.dock.close_panel()
		scene._advance()
		await frames()
		check(JSON.parse_string(JSON.stringify(scene.run.save_data())) == JSON.parse_string(original),"Finishing restores exact active run including RNG")
		check(scene.manual_pause and scene.game_speed == 4.0,"Finishing restores pause and speed choices")
		check(scene.hud_nodes.camp.visible and scene.loot_button.visible and scene.next_button.visible,"Normal campaign controls return when practice ends")
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
		check(FileAccess.get_file_as_string(save_path) == original_file,"Menu practice preserves existing disk save")
		check(FileAccess.get_file_as_string(save_path + ".achievements") == original_achievements,"Replay and menu practice preserve the achievement journal")
		scene.run.load_data(JSON.parse_string(original))
		scene.has_active_run = true
	print("FIRST_ROUND_GUIDE_PASS: %d checks" % checks if failures == 0 else "First round guide failures: %d" % failures)
	scene.queue_free()
	await frames()
	for suffix in ["", ".bak", ".pending", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(save_path+suffix): DirAccess.remove_absolute(save_path+suffix)
		if FileAccess.file_exists(save_path+".achievements"+suffix): DirAccess.remove_absolute(save_path+".achievements"+suffix)
	quit(1 if failures else 0)
