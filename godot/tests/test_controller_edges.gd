extends SceneTree
## Synthetic controller events only. No native cursor movement or player data.
const DEVICE := 57
const OTHER := 58
var scene
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var serial := 0
var label := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(label + ": " + message)

func frames(count := 4) -> void:
	for index in range(count): await process_frame

func button(index: int, down: bool, device := DEVICE) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(index: int, device := DEVICE, held := 1) -> void:
	button(index,true,device)
	await frames(held)
	button(index,false,device)
	await frames()

func axis(index: int, value: float, device := DEVICE) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = index
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func state() -> String:
	return JSON.stringify(scene.run.save_data(),"",true,true)

func disk() -> String:
	return FileAccess.get_file_as_string(scene.run_save.file_path) if FileAccess.file_exists(scene.run_save.file_path) else ""

func focus() -> String:
	var owner := root.gui_get_focus_owner()
	if not is_instance_valid(owner): return "none"
	return str(owner.get_meta("focus_id","")) + ":" + str(owner.text if owner is BaseButton else owner.name)

func scope_has_focus(scope: Control) -> bool:
	var owner := root.gui_get_focus_owner()
	return is_instance_valid(owner) and scope.is_ancestor_of(owner) and owner.is_visible_in_tree()

func fixture(size: Vector2i, prep := false, empty := false) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await frames()
	serial += 1
	root.size = size
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = "user://edge-%d-settings.json" % serial
	scene.run_save.file_path = "user://edge-%d-run.json" % serial
	root.add_child(scene)
	await frames(6)
	scene.sound.set_muted(true)
	scene.set_process(false)
	scene.run.new_run(875,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy"})
	scene.has_active_run = true
	scene._close_overlay()
	scene.dock.reset_for_run()
	var cell: int = scene.run.board.find(0)
	if prep:
		check(scene.run.place(cell,scene.run.solution[cell]).ok,"Fixture legally plants one tower")
		check(scene.run.advance_phase().ok,"Fixture advances normally to prepare")
	if empty: scene.run.items.clear() # Explicit UI availability fixture only.
	scene.last_phase = scene.run.phase
	scene.world.setup(scene.run)
	scene._select(cell,false,false)
	scene._refresh()
	await frames(8)
	check(scene._save(),"Synthetic run snapshot saved")

func disconnect_number_picker(size: Vector2i) -> void:
	label = "number-picker-disconnect " + str(size)
	await fixture(size)
	var original := state()
	var original_disk := disk()
	var cell: int = scene.selected_cell
	await press(JOY_BUTTON_A)
	check(scene._controller_number_cell == cell,"A opens number chooser")
	button(JOY_BUTTON_DPAD_RIGHT,true)
	await frames(2)
	Input.joy_connection_changed.emit(DEVICE,false)
	await frames(12)
	check(scene.menu_open and scene._controller_number_cell == -1,"Disconnect cancels chooser and opens pause")
	check(scene.controller.active_device == -1 and scene.controller._direction == Vector2i.ZERO,"Disconnect releases input ownership and repeat")
	check(scope_has_focus(scene.overlay),"Pause owns visible focus after disconnect")
	check(focus() == ":Resume run","Pause defaults to Resume")
	button(JOY_BUTTON_DPAD_RIGHT,false)
	button(JOY_BUTTON_A,false)
	await frames(45)
	check(state() == original and disk() == original_disk,"Late releases and no-input pause preserve run and disk")
	Input.joy_connection_changed.emit(OTHER,true)
	await press(JOY_BUTTON_A,OTHER,45)
	check(not scene.menu_open and scene._controller_number_cell == -1,"One held reconnect A resumes only, without opening number chooser")
	check(scene.selected_cell == cell and state() == original,"Resume leaves board selection and run unchanged")
	await press(JOY_BUTTON_A,OTHER)
	check(scene._controller_number_cell == cell,"Next explicit A can reopen chooser")
	await press(JOY_BUTTON_B,OTHER)
	check(scene._controller_number_cell == -1 and not scene.menu_open,"B escapes reopened chooser")

func disconnect_module_picker(size: Vector2i, empty: bool) -> void:
	label = "module-picker-disconnect empty=%s %s" % [empty,size]
	await fixture(size,true,empty)
	var original := state()
	var original_disk := disk()
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_A)
	check(scene.dock.controller_picker_slot == 0,"A/A opens module chooser")
	check(scope_has_focus(scene.dock._shell),"Module chooser owns focus")
	if empty: check(focus().begins_with("upgrade:back:"),"Empty chooser defaults to Back")
	Input.joy_connection_changed.emit(DEVICE,false)
	await frames(12)
	observations.append({"case":label,"focus_after_disconnect":focus(),"overlay_has_focus":scope_has_focus(scene.overlay),"dock_open":scene.dock.is_open(),"context":scene.dock.controller_context_active()})
	check(scene.menu_open and not scene.dock.controller_context_active(),"Disconnect opens pause and clears contextual selection")
	check(scope_has_focus(scene.overlay),"Disconnect pause owns focus rather than covered workshop")
	check(focus() == ":Resume run","Disconnect pause focuses Resume after deferred UI rebuild")
	check(state() == original and disk() == original_disk,"Disconnect does not consume or move a module")
	Input.joy_connection_changed.emit(OTHER,true)
	await press(JOY_BUTTON_A,OTHER,45)
	check(not scene.menu_open,"First reconnect A resumes rather than merely repairing hidden focus")
	check(state() == original,"Reconnect A cannot buy, equip or remove through covered workshop")
	if scene.menu_open: await press(JOY_BUTTON_B,OTHER)
	check(not scene.dock.is_open() or scope_has_focus(scene.dock._shell),"Resuming restores visible focus if the covered workshop remains open")
	if scene.dock.is_open(): await press(JOY_BUTTON_B,OTHER)
	check(not scene.menu_open and not scene.dock.is_open(),"B sequence has an escape to board")

func focus_loss_and_handoff(size: Vector2i) -> void:
	label = "focus-loss-handoff " + str(size)
	await fixture(size,true)
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_A)
	var original := state()
	var original_disk := disk()
	var old_focus := focus()
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await frames()
	# Backgrounding now saves before waiting. Subsequent ignored input must not
	# mutate that committed snapshot.
	original_disk = disk()
	for index in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_START,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_RIGHT_SHOULDER]:
		await press(index)
	axis(JOY_AXIS_LEFT_Y,0.9)
	button(JOY_BUTTON_DPAD_DOWN,true)
	await frames(55)
	check(scene.controller._direction == Vector2i.ZERO,"Unfocused inputs cannot start a navigation repeat")
	check(scene.dock.controller_picker_slot == 0 and focus() == old_focus,"Focus loss ignores confirm/cancel/menu and preserves chooser")
	check(state() == original and disk() == original_disk,"Ignored unfocused input preserves run and persisted bytes")
	scene.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	axis(JOY_AXIS_LEFT_Y,0.0)
	button(JOY_BUTTON_DPAD_DOWN,false)
	await press(JOY_BUTTON_B,OTHER,45)
	check(scene.controller.active_device == OTHER,"New controller can claim on a fresh action")
	check(scene.dock.controller_picker_slot == -1 and scene.dock.controller_context_active(),"Fresh held B returns one chooser layer only")
	Input.joy_connection_changed.emit(DEVICE,false)
	await frames()
	check(not scene.menu_open and scene.controller.active_device == OTHER,"Disconnect of the previous inactive controller leaves active chooser usable")
	button(JOY_BUTTON_A,false,DEVICE)
	button(JOY_BUTTON_B,false,DEVICE)
	axis(JOY_AXIS_LEFT_X,0.0,DEVICE)
	await frames(55)
	check(scene.controller.active_device == OTHER and scene.controller._direction == Vector2i.ZERO,"Stale releases from former controller do not steal ownership or repeat")
	check(state() == original,"Controller handoff preserves modules/resources")
	await press(JOY_BUTTON_B,OTHER)
	check(not scene.dock.is_open() and not scene.menu_open,"Fresh B reaches board")

func same_frame_overlay(size: Vector2i, picker: bool, disconnect: bool) -> void:
	label = "same-frame-overlay picker=%s disconnect=%s %s" % [picker,disconnect,size]
	await fixture(size,true)
	var original := state()
	var original_disk := disk()
	if picker: await press(JOY_BUTTON_A)
	# Real event batch: open workshop/chooser, then Start or loss signal before
	# any deferred dock focus callback can finish. No private action callback.
	button(JOY_BUTTON_A,true)
	if disconnect: Input.joy_connection_changed.emit(DEVICE,false)
	else: button(JOY_BUTTON_START,true)
	await frames(12)
	observations.append({"case":label,"focus_after_overlay":focus(),"overlay_has_focus":scope_has_focus(scene.overlay) if scene.menu_open else false})
	check(scene.menu_open,"Same-frame modal opens")
	check(scope_has_focus(scene.overlay) and focus() == ":Resume run","Already queued dock focus cannot steal modal focus")
	button(JOY_BUTTON_A,false)
	button(JOY_BUTTON_START,false)
	await frames()
	check(state() == original and disk() == original_disk,"Opening and releasing the event batch preserves run and saved bytes")
	if disconnect: Input.joy_connection_changed.emit(OTHER,true)
	var device: int = OTHER if disconnect else DEVICE
	await press(JOY_BUTTON_A,device)
	check(not scene.menu_open,"First explicit A after the event batch resumes")
	if scene.menu_open: await press(JOY_BUTTON_B,device)
	check(not scene.dock.is_open() or scope_has_focus(scene.dock._shell),"Modal escape restores focus to the remaining workshop")
	if scene.dock.is_open(): await press(JOY_BUTTON_B,device)
	check(not scene.menu_open and not scene.dock.is_open() and state() == original,"Repeated Back escape cannot mutate the run")

func no_input_and_disabled(size: Vector2i) -> void:
	label = "no-input-empty-workshop " + str(size)
	await fixture(size,true,true)
	scene.run.credits = 0 # Explicit disabled-purchase UI fixture.
	scene._refresh()
	check(scene._save(),"Disabled purchase fixture saved")
	var original := state()
	var original_disk := disk()
	await frames(60)
	check(state() == original,"No controller input leaves stable fixture unchanged")
	await press(JOY_BUTTON_A)
	await press(JOY_BUTTON_A)
	check(focus().begins_with("upgrade:back:"),"No modules provides a usable escape action")
	await frames(60)
	check(scope_has_focus(scene.dock._shell) and focus().begins_with("upgrade:back:"),"Idle empty chooser retains safe focus")
	await press(JOY_BUTTON_A,DEVICE,45)
	check(scene.dock.controller_picker_slot == -1 and state() == original,"Held confirm on empty chooser only returns, with no purchase")
	await press(JOY_BUTTON_B,DEVICE,45)
	check(not scene.dock.is_open() and state() == original and disk() == original_disk,"Held Back exits without spending or altering saved state")

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("exercise")

func exercise() -> void:
	for size in [Vector2i(1280,800),Vector2i(800,600)]:
		await disconnect_number_picker(size)
		await disconnect_module_picker(size,false)
		await disconnect_module_picker(size,true)
		await focus_loss_and_handoff(size)
		await no_input_and_disabled(size)
		for picker: bool in [false,true]:
			for disconnect: bool in [false,true]:
				await same_frame_overlay(size,picker,disconnect)
	if is_instance_valid(scene): scene.queue_free()
	await frames()
	var result := {"checks":checks,"failures":failures,"observations":observations,"method":"Headless real scenes with Input.parse_input_event, joy_connection_changed signal and propagated window notifications. Synthetic UI fixtures, no native cursor or real hotplug."}
	var file := FileAccess.open("user://controller-edge-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t",true,true))
	file.close()
	for failure in failures: push_error(failure)
	print("CONTROLLER_EDGES_%s %d checks / %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
