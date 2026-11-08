extends SceneTree
## Native joypad dispatch through the management and reserve-planting loop.
## Run normally and with --canvas-graphics; rendering is not required.
const DEVICE := 42
const RUN_PATH := "user://karen-controller-run.json"
var checks := 0
var failures := 0
var scene

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or "--capture-karen" not in OS.get_cmdline_user_args(): return
	scene._layout_ui()
	scene._refresh()
	scene.notice_time = 0
	scene.notice.hide()
	scene._update_context_visibility()
	await frames(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/karen-checks")
	var variant := "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	check(root.get_texture().get_image().save_png("res://build/karen-checks/main-%s-%s.png" % [variant, name]) == OK, "Capture main " + name)

func pad(index: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)
	await frames(3)

func by_id(scope: Node, id: String) -> Button:
	for candidate in scope.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and str(candidate.get_meta("focus_id", "")) == id: return candidate
	return null

func focus_id() -> String:
	var focused: Control = root.gui_get_focus_owner()
	return str(focused.get_meta("focus_id", "")) if is_instance_valid(focused) else ""

func activate_id(scope: Node, id: String) -> void:
	var target := by_id(scope, id)
	check(is_instance_valid(target) and not target.disabled, "Controller action is enabled: " + id)
	if not is_instance_valid(target) or target.disabled: return
	target.grab_focus()
	await frames()
	await pad(JOY_BUTTON_A)

func activate_menu(prefix: String) -> void:
	var found := false
	for i in range(30):
		var focused: Control = root.gui_get_focus_owner()
		if focused is Button and str(focused.text).begins_with(prefix):
			found = true
			break
		await pad(JOY_BUTTON_DPAD_DOWN)
	check(found, "D-pad reaches pause action: " + prefix)
	if found: await pad(JOY_BUTTON_A)

func phase(value: String) -> void:
	scene.run.phase = value
	scene.last_phase = value
	scene.run.drain_events()
	scene.reserve_mode = false
	scene._refresh()
	for i in range(24): scene.world.tick(0.05)

func assert_tower_navigation(cells: Array[int], label: String) -> void:
	var leftmost: int = cells[0]
	for cell in cells:
		if scene.world.cell_screen_position(cell).x < scene.world.cell_screen_position(leftmost).x: leftmost = cell
	scene._select(leftmost, false, false)
	await pad(JOY_BUTTON_DPAD_RIGHT)
	check(scene.selected_cell != leftmost and cells.has(scene.selected_cell), label + " right skips intervening empty and printed cells")
	for button in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT]:
		await pad(button)
		check(cells.has(scene.selected_cell), label + " D-pad remains anchored to a planted tower")
	scene._select(cells[0], false, false)
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_cell == cells[1], label + " RB selects the next tower")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.selected_cell == cells[0], label + " LB returns to the previous tower")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.selected_cell == cells[-1], label + " LB wraps to the last tower")

func exercise() -> void:
	var had_save := FileAccess.file_exists(RUN_PATH)
	var previous_save := FileAccess.get_file_as_bytes(RUN_PATH) if had_save else PackedByteArray()
	root.size = Vector2i(1280, 800)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.run_save.file_path = RUN_PATH # Explicit fixture survives account-profile routing.
	root.add_child(scene)
	await frames(6)
	scene.muted = true
	scene.sound.set_muted(true)
	scene.auto_open_chests = false
	scene.seed_input.text = "784217"
	scene._start_run()
	# Freeze the clock while leaving ControllerInput and real GUI input active.
	scene.set_process(false)
	await frames()
	scene.selected_number = 1
	scene._refresh()
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_number == 2 and scene.run.phase == "solve", "Solve RB still cycles numbers")
	await pad(JOY_BUTTON_LEFT_SHOULDER)
	check(scene.selected_number == 1, "Solve LB still cycles numbers backwards")
	var cells: Array[int] = []
	for start in [0, 27, 54]:
		for cell in range(start, start+27):
			if scene.run.board[cell] == 0:
				check(bool(scene.run.place(cell, scene.run.solution[cell]).ok), "Fixture plants a separate tower")
				cells.append(cell)
				break
	check(cells.size() == 3, "Fixture has three towers separated by non-tower squares")
	scene.run.advance_phase()
	scene.run.update(0.8) # Finish cosmetic growth before the clock is held for input checks.
	phase("prep")
	await assert_tower_navigation(cells, "Prepare")
	var puzzle_before: Array = scene.run.board.duplicate()
	for entry in [["Manage gear", "bag"], ["Chests / Open all", "loot"], ["Camp / Salvage slots", "camp"]]:
		await pad(JOY_BUTTON_START)
		check(scene.menu_open, "Start opens the management menu")
		if entry[1] == "bag": await capture("start-menu")
		await activate_menu(entry[0])
		check(not scene.menu_open and scene.dock.is_open() and scene.dock.current_panel == entry[1], "A opens " + entry[1] + " without using a cursor")
		if entry[1] == "camp":
			await pad(JOY_BUTTON_START)
			await activate_menu("Camp / Salvage slots")
			check(not scene.menu_open and scene.dock.is_open() and scene.dock.current_panel == "camp", "Start from Camp then choosing Camp keeps the requested panel open")
		await pad(JOY_BUTTON_B)
		check(not scene.dock.is_open(), "B returns to the board from " + entry[1])
	check(scene.run.board == puzzle_before and scene.run.phase == "prep", "Management navigation neither plants nor advances the phase")
	# Batch selection remains in Gear, and Y installs only the selected copies.
	scene._select(cells[0], false, false)
	await pad(JOY_BUTTON_X)
	var modules: Array[String] = []
	for item in scene.run.items:
		if item.type == "attachment" and modules.size() < 2: modules.append(str(item.id))
	var before_items: int = scene.run.items.size()
	for id in modules: await activate_id(scene.dock, "item:" + id)
	check(scene.dock.is_open() and scene.dock.current_panel == "bag" and scene.dock.has_selected_modules(), "A selects several modules without leaving Gear")
	await pad(JOY_BUTTON_Y)
	check(scene.run.towers[cells[0]].attachments.size() == 2 and scene.run.items.size() == before_items-2, "Y installs the two selected modules exactly once")
	check(scene.selected_cell == cells[0] and scene.dock.selected_cell == cells[0] and scene.dock.is_open(), "Batch install stays on the same tower")
	check(scene.run.phase == "prep" and not scene.dock.has_selected_modules(), "Y consumes the selection without launching the wave")
	await pad(JOY_BUTTON_Y)
	check(scene.run.towers[cells[0]].attachments.size() == 2 and scene.run.phase == "prep", "Repeated Y cannot duplicate the batch or launch through an open panel")
	await pad(JOY_BUTTON_B)
	# With no tower selected, selecting a module retains the existing target flow.
	var blank := -1
	for cell in range(81):
		if scene.run.board[cell] == 0:
			blank = cell
			break
	scene._select(blank, false, false)
	await pad(JOY_BUTTON_X)
	var single := ""
	for item in scene.run.items:
		if item.type == "attachment":
			single = str(item.id)
			break
	await activate_id(scene.dock, "item:" + single)
	check(scene.armed_item == single and not scene.dock.is_open(), "Single module selection enters tower targeting")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	var target: int = scene.selected_cell
	var occupied: int = scene.run.towers[target].attachments.size() if scene.run.towers.has(target) else -1
	check(cells.has(target), "Armed targeting chooses a tower instead of an empty cell")
	await pad(JOY_BUTTON_A)
	check(scene.run.towers[target].attachments.size() == occupied+1 and scene.selected_cell == target, "A installs the single module and keeps its tower selected")
	check(scene.dock.is_open() and scene.dock.current_panel == "tower" and focus_id() == "slot:" + str(occupied+1), "Single install returns focus to the same tower's next empty socket")
	await pad(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_cell != target and scene.dock.current_panel == "tower", "RB explicitly changes towers while the workshop stays open")
	await pad(JOY_BUTTON_B)
	scene.run.advance_phase()
	phase("battle")
	await assert_tower_navigation(cells, "Battle")
	check(scene.number_buttons.all(func(b): return not b.is_visible_in_tree()), "Battle hides the number tray during ordinary tower selection")
	check(scene.hud_nodes.reserve_mode.is_visible_in_tree(), "Battle exposes an explicit reserve planting action")
	await capture("battle")
	await pad(JOY_BUTTON_X)
	check(scene.dock.is_open() and scene.dock.current_panel == "bag", "Reserve navigation fixture begins inside Gear")
	await pad(JOY_BUTTON_START)
	await activate_menu("Plant reserve seeds")
	check(scene.reserve_mode and not scene.dock.is_open() and not scene.menu_open and scene.number_buttons.all(func(b): return b.is_visible_in_tree()), "Start from Gear then reserve planting closes management and opens the usable number tray")
	await capture("reserves")
	root.size = Vector2i(390,844)
	await frames(6)
	scene._layout_ui()
	scene._refresh()
	await frames(6)
	check(scene.hud_nodes.reserve_mode.text == "Done" and not scene.hud_nodes.reserve_mode.get_global_rect().intersects(scene.hud_nodes.camera.get_global_rect()), "Portrait reserve completion fits beside Camera")
	await capture("reserves-portrait")
	root.size = Vector2i(1280,800)
	await frames(6)
	scene._layout_ui()
	scene._refresh()
	var reserve_cell: int = scene.selected_cell
	check(scene.run.board[reserve_cell] == 0, "Reserve mode starts on an empty square")
	await pad(JOY_BUTTON_A)
	check(scene._controller_number_cell == reserve_cell, "A focuses the reserve number picker")
	# Keep this combined fixture valid after its later transition back to Prepare.
	# Illegal combat reserves are covered by the dedicated run/recovery suites.
	for i in range(9):
		if scene.selected_number == scene.run.solution[reserve_cell]: break
		await pad(JOY_BUTTON_RIGHT_SHOULDER)
	var reserve_number: int = scene.selected_number
	var reserves_before: int = scene.run.inventory[reserve_number]
	await pad(JOY_BUTTON_A)
	check(scene.run.board[reserve_cell] == reserve_number and scene.run.inventory[reserve_number] == reserves_before-1, "A places one emergency tower and consumes one reserve")
	check(scene._controller_number_cell == -1 and scene.selected_cell == reserve_cell, "Reserve placement returns to its square")
	await pad(JOY_BUTTON_B)
	check(not scene.reserve_mode and scene.number_buttons.all(func(b): return not b.is_visible_in_tree()), "B leaves reserve mode and hides the tray again")
	await pad(JOY_BUTTON_LEFT_STICK)
	check(scene.camera_mode, "Camera fixture starts with camera controls active")
	await pad(JOY_BUTTON_START)
	await activate_menu("Plant reserve seeds")
	check(scene.reserve_mode and not scene.camera_mode and not scene.dock.is_open(), "Entering reserves from the pause menu clears camera controls")
	await pad(JOY_BUTTON_B)
	# A new planting action must cancel armed targeting even when Gear is closed.
	var returned: Dictionary = scene.run.unequip_item(cells[0],0)
	check(bool(returned.ok), "Fixture returns one owned module for the armed-reserve transition")
	var reserve_module := str(returned.item.id)
	for cell in range(81):
		if scene.run.board[cell] == 0:
			scene._select(cell,false,false)
			break
	await pad(JOY_BUTTON_X)
	await activate_id(scene.dock,"item:"+reserve_module)
	check(scene.armed_item == reserve_module and not scene.dock.is_open(), "Reserve transition starts with a module armed and Gear closed")
	var ownership_before: Dictionary = scene.run.save_data()
	await pad(JOY_BUTTON_START)
	await activate_menu("Plant reserve seeds")
	check(scene.reserve_mode and scene.armed_item.is_empty() and scene.dock._armed_id.is_empty() and scene.dock._selected_module_ids.is_empty(), "Reserve action clears armed and batch targeting before planting")
	check(scene._number_placement_allowed() and scene.run.save_data() == ownership_before, "Canceling targeting keeps all gear ownership and enables planting")
	await pad(JOY_BUTTON_A)
	check(scene._controller_number_cell == scene.selected_cell, "Reserve number picker works immediately after canceling armed gear")
	await pad(JOY_BUTTON_B)
	scene._toggle_reserve_mode()
	check(not scene.reserve_mode and scene.armed_item.is_empty(), "Toggling planting off does not restore canceled gear targeting")
	# Build an eligible cleanup fixture without allowing simulation time to move.
	var combat_before: Dictionary = scene.run.save_data()
	scene.run._spawn()
	scene.run.spawned = scene.run.spawn_total
	scene.run.battle_time = 45.0
	check(scene._cleanup_controls_available(), "Fixture enables late-wave cleanup before planting")
	scene._toggle_cleanup()
	check(scene.cleanup_fast, "Fixture enters fast-forward before the direct Reserve seeds action")
	scene._toggle_reserve_mode()
	check(scene.reserve_mode and not scene.cleanup_fast and not scene._cleanup_controls_available(), "Entering reserve mode stops fast-forward and disables cleanup while planting")
	await pad(JOY_BUTTON_Y)
	check(not scene.cleanup_fast and scene.reserve_mode, "Y cannot start fast-forward while reserve planting is active")
	scene._toggle_reserve_mode()
	check(not scene.reserve_mode and scene._cleanup_controls_available(), "Leaving reserve mode restores explicit cleanup availability")
	check(scene.run.load_data(combat_before), "Cleanup fixture restores the original held combat state")
	scene.run.drain_events()
	scene._refresh()
	# Queued auto-open never takes focus from an active UI or combat.
	scene.auto_open_chests = true
	scene.run.chests.clear()
	scene.run._add_chest("common")
	scene.run._add_chest("common")
	scene.run._add_chest("legendary")
	scene.run.fragments = 10
	scene.run.drain_events()
	var loot_items: int = scene.run.items.size()
	scene._maybe_auto_open_chests()
	check(scene.run.chests.size() == 3 and scene.run.fragments == 10 and not scene.dock.is_open(), "Automatic opening waits through combat")
	phase("prep")
	await pad(JOY_BUTTON_START)
	var focused: Control = root.gui_get_focus_owner()
	scene._maybe_auto_open_chests()
	check(scene.menu_open and root.gui_get_focus_owner() == focused and scene.run.chests.size() == 3, "Automatic opening preserves pause menu and focus")
	await pad(JOY_BUTTON_B)
	await pad(JOY_BUTTON_X)
	focused = root.gui_get_focus_owner()
	scene._maybe_auto_open_chests()
	check(scene.dock.current_panel == "bag" and root.gui_get_focus_owner() == focused and scene.run.chests.size() == 3, "Automatic opening preserves active Gear management")
	await pad(JOY_BUTTON_B)
	scene.manual_pause = true
	scene._maybe_auto_open_chests()
	check(scene.run.chests.size() == 3, "Automatic opening respects a manual pause")
	scene.manual_pause = false
	for gesture in ["mouse_down", "active_touch", "_camera_pointer_id"]:
		scene.board_input.set(gesture, true if gesture == "mouse_down" else 0)
		scene._maybe_auto_open_chests()
		check(scene.run.chests.size() == 3 and not scene.dock.is_open(), "Automatic opening waits for board gesture: " + gesture)
		scene.board_input.cancel_pointer()
	scene._maybe_auto_open_chests()
	await frames()
	check(scene.run.chests.size() == 1 and scene.run.chests[0].rarity == "legendary" and scene.run.fragments == 0, "Safe automatic opening spends exactly affordable costs and retains expensive chests")
	check(scene.run.items.size() == loot_items+2 and scene.dock.current_panel == "loot" and scene.dock._loot_table.reward.rewards.size() == 2, "Automatic opening delivers both rewards in one loot reveal")
	scene._maybe_auto_open_chests()
	check(scene.run.items.size() == loot_items+2 and scene.run.chests.size() == 1 and scene.run.fragments == 0, "Repeated automatic checks cannot duplicate rewards or spend again")
	check(not scene.save_failed and scene.run_save._valid_data(scene.run.save_data()), "Auto-open fixture remains valid for guarded saving: " + str(scene.run_save.last_error))
	var saved = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	check(saved is Dictionary and saved.has("state") and saved.state.items.size() == scene.run.items.size() and saved.state.chests.size() == 1 and int(saved.state.fragments) == 0, "Automatic reward ownership and costs are saved before the reveal")
	await activate_id(scene.dock, "loot:continue")
	await pad(JOY_BUTTON_B)
	phase("won")
	scene.run._add_chest("common")
	scene.run.fragments = 5
	scene.run.drain_events()
	var won_items: int = scene.run.items.size()
	scene._show_result()
	await frames()
	focused = root.gui_get_focus_owner()
	scene._maybe_auto_open_chests()
	check(scene.menu_open and root.gui_get_focus_owner() == focused and scene.run.chests.size() == 2, "Victory result screen retains focus before automatic final rewards")
	await activate_menu("Inspect the board")
	scene._maybe_auto_open_chests()
	check(scene.run.chests.size() == 1 and scene.run.fragments == 0 and scene.run.items.size() == won_items+1 and scene.dock.current_panel == "loot", "Dismissing victory allows affordable final chests to open once")
	scene.queue_free()
	await frames(4)
	if had_save:
		var file := FileAccess.open(RUN_PATH, FileAccess.WRITE)
		file.store_buffer(previous_save)
		file.close()
	else:
		DirAccess.remove_absolute(RUN_PATH)
	print("KAREN_CONTROLLER: %d checks, %d failures (%s)" % [checks, failures, "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"])
	quit(1 if failures else 0)
