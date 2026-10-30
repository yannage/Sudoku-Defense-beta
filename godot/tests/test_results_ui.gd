extends SceneTree
## Run in an isolated OS user-data directory, as with the existing UI suites.
var scene
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("exercise")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func pad(button: int) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)
	await frames(3)

func exercise() -> void:
	# Backup/restore only this runner's storage; callers must isolate APPDATA/XDG.
	var path := "user://sudoku-defense-run.json"
	var had_save := FileAccess.file_exists(path)
	var previous := FileAccess.get_file_as_bytes(path) if had_save else PackedByteArray()
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await frames(5)
	scene.sound.set_muted(true)
	scene.set_process(false)
	for size: Vector2i in [Vector2i(1280,800),Vector2i(390,844)]:
		root.size = size
		for phase: String in ["lost","won"]:
			scene.run.new_run(9147,{"mode":"campaign","puzzle_difficulty":"medium","combat_difficulty":"hard"})
			var original_board: Array = scene.run.board.duplicate()
			scene.has_active_run = true
			scene.run.phase = phase
			scene.run.puzzle_difficulty = "easy"
			scene.run.combat_difficulty = "easy"
			scene.run.round_no = 12
			scene.run.combat_report.damage = 100
			scene.run.combat_report.leaks = {"runner":3}
			scene.run.combat_report.towers = {"1:0":{"round":1,"cell":0,"number":7,"damage":100.0,"kills":9}}
			scene.manual_pause = true
			scene.armed_item = "stale"
			scene.last_phase = phase
			scene.world.setup(scene.run)
			scene._layout_ui()
			scene._show_result()
			await frames(5)
			var before: Dictionary = scene.run.save_data()
			scene._show_result()
			await frames(5)
			check(scene.run.save_data() == before,"Repeated results never change progression or report")
			var retry: Button
			for control in scene.overlay.find_children("*","Button",true,false):
				if control.get_meta("focus_id","") == "result:retry": retry = control
			check(retry != null and retry.has_focus(),"Retry is initial controller focus")
			check(root.get_visible_rect().encloses(retry.get_global_rect()),"Retry remains visible on Deck and portrait")
			for step in range(3): await pad(JOY_BUTTON_DPAD_DOWN)
			var focused: Control = root.gui_get_focus_owner()
			check(focused != null and focused.get_meta("focus_id","") == "result:bottom","D-pad can reach the report bottom")
			var scroll: ScrollContainer = scene.overlay.find_children("*","ScrollContainer",true,false)[0]
			check(scroll.scroll_vertical > 0 or scroll.get_v_scroll_bar().max_value <= scroll.size.y,"Long reports scroll into view with controller")
			await pad(JOY_BUTTON_A)
			check(retry.has_focus(),"Bottom return action restores retry focus without restarting")
			scene._close_overlay()
			scene._advance()
			await frames(3)
			check(scene.menu_open and scene.next_button.text == "Run results","Inspect board retains a route back to results")
			await pad(JOY_BUTTON_A)
			check(scene.run.phase == "solve" and scene.run.round_no == 1 and scene.run.seed_value == 9147,"One A press retries finished run")
			check(scene.run.board == original_board and scene.run.puzzle_difficulty == "medium" and scene.run.combat_difficulty == "hard","Retry recreates original board and starting settings")
			check(not scene.menu_open and not scene.manual_pause and scene.armed_item.is_empty() and scene.selected_cell == -1,"Retry clears menu, pause and interaction state")
			check(scene.run.combat_report.damage == 0 and scene.run.combat_report.leaks.is_empty(),"Retry clears combat accounting")
			var first_empty := -1
			for cell in range(81):
				if int(scene.run.board[cell]) == 0:
					first_empty = cell
					break
			scene.selected_cell = first_empty
			scene.selected_number = 1
			scene._refresh()
			await frames(3)
			check(scene.candidate_label.tooltip_text.contains("does not confirm the answer"),"Placement preview does not claim correctness")
			check(scene.candidate_label.mouse_filter == Control.MOUSE_FILTER_PASS,"Strategy tooltip is reachable by pointer hover")
			check(scene.candidate_label.get_minimum_size().y <= scene.candidate_label.size.y+1,"Preview text fits allocated context height")
	scene.queue_free()
	await frames()
	if had_save:
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else: DirAccess.remove_absolute(path)
	print("%s: %d checks / %d failures" % ["RESULTS_UI_PASS" if failures == 0 else "RESULTS_UI_FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
