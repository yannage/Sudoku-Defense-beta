extends SceneTree
## Real scenes with synthetic focus/Steam overlay notifications and input events.
## Every run uses an isolated save path. No physical Deck or Steam account access.
const DEVICE := 73
var scene
var checks := 0
var failures: Array[String] = []
var serial := 0
var label := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(label + ": " + message)

func frames(count := 4) -> void:
	for index in range(count): await process_frame

func button(index: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(index: int) -> void:
	button(index,true)
	await frames()
	button(index,false)
	await frames()

func axis(index: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func state() -> String:
	return JSON.stringify(scene.run.save_data(),"",true,true)

func fixture(phase := "solve") -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await frames()
	serial += 1
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = "user://deck-focus-%d-settings.json" % serial
	scene.run_save.file_path = "user://deck-focus-%d-run.json" % serial
	root.add_child(scene)
	await frames(6)
	scene.sound.set_muted(true)
	scene.set_process(false)
	scene.run.new_run(875,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	scene.has_active_run = true
	scene._close_overlay()
	scene.dock.reset_for_run()
	var cell: int = scene.run.board.find(0)
	if phase != "solve":
		check(scene.run.place(cell,scene.run.solution[cell]).ok,"Fixture plants a real tower")
		check(scene.run.advance_phase().ok,"Fixture enters preparation")
		if phase == "battle": check(scene.run.advance_phase().ok,"Fixture enters battle")
	scene.last_phase = scene.run.phase
	scene.world.setup(scene.run)
	scene._select(cell,false,false)
	scene._refresh()
	await frames(6)
	check(scene._save(),"Fixture saves to isolated profile")

func interrupted_board(phase: String, overlay: bool) -> void:
	label = "%s-%s" % [phase,"overlay" if overlay else "focus"]
	await fixture(phase)
	scene._advance_gameplay(0.05)
	var before := state()
	var timer: float = scene.run.timer
	if overlay: scene.steam_platform.overlay_changed.emit(true)
	else: scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await frames()
	check(scene.menu_open,"Active board opens a pause menu")
	check(scene._background_active(),"Background interruption blocks gameplay")
	var restored = load("res://scripts/run.gd").new()
	var snapshot: Dictionary = scene.run_save.read_run()
	check(not snapshot.is_empty() and restored.load_data(snapshot.get("data",{})),"Background snapshot loads through normal validation")
	check(JSON.stringify(restored.save_data(),"",true,true) == before,"Latest active progress is saved before waiting")
	for index in range(10): scene._advance_gameplay(0.5)
	check(state() == before,"Solve timer/combat state cannot advance while interrupted")
	# Deflection that starts while backgrounded must also be released, not only
	# controls that were held at the instant focus was lost.
	axis(JOY_AXIS_LEFT_Y,0.95)
	button(JOY_BUTTON_A,true)
	if overlay: scene.steam_platform.overlay_changed.emit(false)
	else: scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await frames()
	axis(JOY_AXIS_LEFT_Y,0.96)
	button(JOY_BUTTON_A,true)
	scene.controller._process(1.0)
	check(scene.controller._direction == Vector2i.ZERO,"Held background stick cannot resume navigation")
	check(scene.menu_open,"Held background confirm cannot resume the run")
	check(scene.run.timer == timer,"Returning alone never restarts the timer")
	axis(JOY_AXIS_LEFT_Y,0.0)
	button(JOY_BUTTON_A,false)
	await frames()
	await press(JOY_BUTTON_A)
	check(not scene.menu_open,"Fresh confirm resumes from the pause menu")
	scene._advance_gameplay(0.05)
	check(scene.run.timer != timer,"Gameplay continues after explicit resume")

func preserved_context() -> void:
	label = "workshop-context"
	await fixture("prep")
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_A)
	var context_cell: int = scene.dock.controller_workshop_cell
	var picker: int = scene.dock.controller_picker_slot
	var focused := root.gui_get_focus_owner()
	scene.steam_platform.overlay_changed.emit(true)
	await frames()
	check(not scene.menu_open and scene.dock.is_open(),"Overlay preserves the open workshop")
	check(scene.dock.controller_workshop_cell == context_cell and scene.dock.controller_picker_slot == picker,"Overlay preserves tower/socket context")
	check(root.gui_get_focus_owner() == focused,"Overlay preserves focused module action")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	scene.steam_platform.overlay_changed.emit(false)
	check(scene._background_active() and not scene.controller._input_available(),"Focus loss still blocks input when overlay closes first")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(not scene._background_active(),"Both interruption sources must clear")
	await press(JOY_BUTTON_B)
	check(scene.dock.controller_picker_slot == -1,"Fresh Back exits only the module chooser")
	check(scene.dock.controller_workshop_cell == context_cell,"Workshop remains usable after return")
	label = "modal-context"
	scene._help()
	var original_overlay: Control = scene.overlay
	focused = root.gui_get_focus_owner()
	scene.steam_platform.overlay_changed.emit(true)
	scene.steam_platform.overlay_changed.emit(false)
	await frames()
	check(scene.overlay == original_overlay and root.gui_get_focus_owner() == focused,"Existing modal and focus survive overlay open/close")
	check(scene.menu_open,"Existing modal remains paused until explicitly closed")

func pointer_button(point: Vector2, down: bool, use_touch: bool) -> void:
	if use_touch:
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

func background_number_and_loot() -> void:
	label = "overlay-preserved-number-tray"
	await fixture("solve")
	scene.dock.open_panel("bag",scene.selected_cell)
	scene._refresh()
	await frames()
	var point := Vector2.ZERO
	var number := 0
	for index in range(scene.number_buttons.size()):
		var candidate: Vector2 = scene.number_buttons[index].get_global_rect().get_center()
		if scene.seed_pointer._number_at(candidate) == index+1:
			point = candidate
			number = index+1
			break
	check(number > 0,"Fixture exposes a number-tray input beside the preserved Gear panel")
	var original_number: int = scene.selected_number
	var before := state()
	scene.steam_platform.overlay_changed.emit(true)
	check(not scene.menu_open and scene.dock.is_open(),"Steam overlay preserves Gear rather than replacing it")
	check(not scene._number_input_allowed(),"Background guard rejects number input even with a preserved dock")
	for use_touch in [false,true]:
		pointer_button(point,true,use_touch)
		check(not scene.seed_pointer.is_active(),"Background number press cannot acquire a mouse/touch gesture")
		pointer_button(point,false,use_touch)
		await frames()
	check(scene.selected_number == original_number and state() == before,"Background number gestures cannot change selection, run state or inventory")
	scene.steam_platform.overlay_changed.emit(false)

	label = "overlay-pending-auto-open"
	await fixture("prep")
	scene.run.fragments = 100
	scene.run._add_chest("common")
	scene.auto_open_chests = true
	scene.dock.open_panel("loot",scene.selected_cell)
	await frames()
	check(int(scene.run.chest_open_plan().count) > 0,"Fixture has an affordable pending automatic opening")
	before = state()
	scene.steam_platform.overlay_changed.emit(true)
	check(not scene.menu_open and scene.dock.current_panel == "loot","Overlay preserves the open Loot panel")
	for index in range(3): scene._maybe_auto_open_chests()
	check(state() == before,"Pending automatic opening cannot spend fragments, grant items, consume chests or advance RNG behind overlay")
	scene.steam_platform.overlay_changed.emit(false)
	scene._maybe_auto_open_chests()
	check(scene.run.chests.is_empty() and scene.run.fragments < 100,"Opt-in automatic opening remains usable after returning")

func tower_overlay_release() -> void:
	label = "tower-aim-overlay-release"
	await fixture()
	var towers: Array[int] = []
	for cell in range(81):
		if scene.run.board[cell] != 0: continue
		check(scene.run.place(cell,scene.run.solution[cell]).ok,"Fixture plants a legal directional target")
		towers.append(cell)
		if towers.size() == 6: break
	check(towers.size() >= 2,"Fixture has multiple towers")
	if towers.size() < 2: return
	check(scene.run.advance_phase().ok,"Fixture enters tower preparation")
	scene.last_phase = scene.run.phase
	scene.world.setup(scene.run)
	for index in range(120): scene.world.tick(1.0/60.0)
	var origin: int = towers[0]
	scene._select(origin,false,false)
	scene.controller.active_device = DEVICE
	axis(JOY_AXIS_LEFT_X,0.0)
	axis(JOY_AXIS_LEFT_Y,0.0)
	await frames()
	var start: Vector2 = scene.world.cell_screen_position(origin)
	var direction: Vector2 = (scene.world.cell_screen_position(towers[1])-start).normalized()
	axis(JOY_AXIS_LEFT_X,direction.x)
	axis(JOY_AXIS_LEFT_Y,direction.y)
	await frames()
	check(scene.tower_aim._stick_active and scene.tower_aim.target != origin,"Initial stick gesture previews another tower")
	scene.steam_platform.overlay_changed.emit(true)
	await frames()
	check(not scene.tower_aim._stick_active and scene.tower_aim.target == -1,"Steam overlay cancels the pending tower preview")
	axis(JOY_AXIS_LEFT_X,0.0)
	axis(JOY_AXIS_LEFT_Y,0.0)
	await frames()
	check(scene.selected_cell == origin,"Neutral release behind overlay cannot commit the old target")
	scene.steam_platform.overlay_changed.emit(false)
	await frames()
	check(scene.menu_open and scene.selected_cell == origin,"Closing the overlay leaves explicit resume pending")
	await press(JOY_BUTTON_A)
	check(not scene.menu_open,"Fresh confirm resumes the tower board")
	axis(JOY_AXIS_LEFT_X,direction.x)
	axis(JOY_AXIS_LEFT_Y,direction.y)
	await frames()
	var expected: int = scene.tower_aim.target
	check(scene.tower_aim._stick_active and expected >= 0 and expected != origin,"Neutral observed during overlay rearms a fresh tower gesture")
	axis(JOY_AXIS_LEFT_X,0.0)
	axis(JOY_AXIS_LEFT_Y,0.0)
	await frames()
	check(scene.selected_cell == expected,"Fresh post-overlay release selects exactly the new preview")

func quit_controls() -> void:
	label = "native-quit-controls"
	await fixture()
	scene._show_menu(true)
	var initial: Array[Control] = scene._controller_buttons(scene.overlay)
	var quit_button: BaseButton
	for control in initial:
		if control.text == "Quit game": quit_button = control
	check(is_instance_valid(quit_button),"Native main menu has a controller-focusable Quit action")
	scene._show_pause_menu()
	var saved_quit: BaseButton
	for control in scene._controller_buttons(scene.overlay):
		if control.text == "Save and quit": saved_quit = control
	check(is_instance_valid(saved_quit),"Pause menu has a controller-focusable Save and quit action")
	# Force the existing profile guard to fail; never terminate this test tree.
	scene.cloud_profile_status["ok"] = false
	scene._request_quit()
	check(scene.menu_open and bool(scene.overlay.get_meta("unsaved_quit",false)),"Quit failure routes to recoverable save warning")
	var actions: Array[String] = []
	for control in scene._controller_buttons(scene.overlay): actions.append(control.text)
	check(actions.has("Retry save and quit") and actions.has("Keep playing") and actions.has("Quit without saving"),"Save failure offers all existing controller recovery actions")

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func exercise() -> void:
	for phase in ["solve","battle"]:
		for overlay in [false,true]: await interrupted_board(phase,overlay)
	await preserved_context()
	await background_number_and_loot()
	await tower_overlay_release()
	await quit_controls()
	if is_instance_valid(scene): scene.queue_free()
	await frames()
	for failure in failures: push_error(failure)
	print("DECK_FOCUS_%s %d checks / %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
