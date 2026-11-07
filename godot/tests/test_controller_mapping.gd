extends SceneTree
## Synthetic mapping and modal routing only. Never moves the native cursor.
const Bindings = preload("res://scripts/controller_bindings.gd")
const Preferences = preload("res://scripts/preferences.gd")
const Controller = preload("res://scripts/controller_input.gd")
var checks := 0
var failures := 0
var scene
var actions: Array[String] = []
var captured: Array[String] = []
var pointers: Array[String] = []
var settings_path := "user://mapping-test.json"

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in count: await process_frame

func event_button(target, index: int, down: bool, device := 57) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = down
	target._input(event)

func event_axis(target, index: int, value: float, device := 57) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = index
	event.axis_value = value
	target._input(event)

func press(index: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.device = 57
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames()

func control(id: String) -> Button:
	for item in scene.overlay.find_children("*","Button",true,false):
		if item.get_meta("focus_id","") == id: return item
	return null

func exercise() -> void:
	var defaults := Bindings.DEFAULTS.duplicate()
	check(Bindings.validate(null) == defaults,"Missing mapping defaults")
	check(Bindings.validate([]) == defaults,"Wrong root defaults")
	for invalid in [null,0,1.5,true,"b11","t0",{},[]]:
		var malformed := defaults.duplicate()
		malformed.confirm = invalid
		check(Bindings.validate(malformed) == defaults,"Invalid binding rejected: " + str(invalid))
	var duplicate := defaults.duplicate()
	duplicate.cancel = duplicate.confirm
	check(Bindings.validate(duplicate) == defaults,"Duplicate mapping rejected atomically")
	var changed := Bindings.swap_binding(defaults,"confirm","t5")
	check(changed.confirm == "t5" and changed.drag == "b0","Conflicting input swaps without orphaning action")
	check(Bindings.validate(changed) == changed,"Valid trigger mapping retained")
	var store := Preferences.new()
	store.file_path = settings_path
	check(store.write_settings({"controller_bindings":changed,"muted":true}),"Mapping write succeeds")
	check(store.read_settings().controller_bindings == changed and store.read_settings().muted,"Mapping round trip preserves other preferences")
	var input := Controller.new()
	root.add_child(input)
	input.action_pressed.connect(func(action: String): actions.append(action))
	input.binding_captured.connect(func(token: String): captured.append(token))
	input.pointer_button_changed.connect(func(source: String, down: bool): pointers.append(source+str(down)))
	input.set_bindings(changed)
	event_axis(input,JOY_AXIS_TRIGGER_RIGHT,0.7)
	event_axis(input,JOY_AXIS_TRIGGER_RIGHT,0.8)
	check(actions == ["confirm"],"Remapped trigger fires once with hysteresis")
	event_axis(input,JOY_AXIS_TRIGGER_RIGHT,0.2)
	event_axis(input,JOY_AXIS_TRIGGER_RIGHT,0.6)
	check(actions.size() == 2,"Trigger re-arms after release")
	event_axis(input,JOY_AXIS_TRIGGER_RIGHT,0.0)
	event_button(input,JOY_BUTTON_A,true)
	event_button(input,JOY_BUTTON_A,false)
	check(pointers == ["triggertrue","triggerfalse"],"Remapped button routes drag press and release")
	input.begin_capture()
	event_button(input,JOY_BUTTON_B,true)
	check(captured == ["b1"] and actions.size() == 2,"Capture isolates B from gameplay")
	event_button(input,JOY_BUTTON_B,true)
	event_button(input,JOY_BUTTON_B,false)
	check(actions.size() == 2,"Captured held input and release do not leak")
	input.begin_capture()
	event_axis(input,JOY_AXIS_RIGHT_X,0.9)
	check(input.capturing and input._right_axis == Vector2.ZERO,"Capture ignores cursor axes")
	input.cancel_capture()
	event_axis(input,JOY_AXIS_RIGHT_X,0.8)
	check(input._right_axis == Vector2.ZERO,"Held stick remains blocked after cancel")
	event_axis(input,JOY_AXIS_RIGHT_X,0.0)
	input.begin_capture()
	event_button(input,JOY_BUTTON_X,true,58)
	check(not input.capturing and captured.size() == 1,"Changing input device cancels capture")
	input.begin_capture()
	event_button(input,JOY_BUTTON_DPAD_LEFT,true)
	check(not input.capturing,"Fixed D-pad Left cancels capture using only controller")
	event_button(input,JOY_BUTTON_DPAD_LEFT,false)
	input.begin_capture()
	input._connection_changed(57,false)
	check(not input.capturing and input._pointer_buttons == {"stick":false,"trigger":false},"Disconnect cancels capture and pointer")
	input.begin_capture()
	input._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not input.capturing,"Focus loss cancels capture")
	input._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	input.set_bindings(defaults)
	event_button(input,JOY_BUTTON_A,true)
	input._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	event_button(input,JOY_BUTTON_A,false)
	input._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	var before := actions.size()
	event_button(input,JOY_BUTTON_A,true)
	check(actions.size() == before+1,"Release while unfocused does not swallow next press")
	input._connection_changed(57,false)
	before = actions.size()
	event_button(input,JOY_BUTTON_A,true)
	check(actions.size() == before+1,"Reused disconnected device ID has fresh edge state")
	event_button(input,JOY_BUTTON_A,false)
	input.set_settings_mode(true)
	event_button(input,JOY_BUTTON_A,true,58)
	check(input.active_device == 58,"Settings activation claims the invoking controller")
	input.begin_capture()
	event_button(input,JOY_BUTTON_X,true,58)
	check(captured.back() == "b2","Invoking controller can finish capture after device switch")
	input.queue_free()
	await frames()
	root.size = Vector2i(1280,800)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = settings_path
	scene.run_save.file_path = "user://mapping-run.json"
	root.add_child(scene)
	await frames(5)
	scene.sound.set_muted(true)
	scene.set_process(false)
	check(scene.controller.bindings == changed,"Fresh scene loads saved mapping")
	check(scene.get_viewport().disable_3d == ("--canvas-graphics" in OS.get_cmdline_user_args()),"Requested native or Canvas route is active")
	scene._show_controller_settings()
	await frames()
	check(control("mapping:confirm").text.ends_with("RT"),"Mapping panel shows current binding")
	control("mapping:confirm").grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.controller.capturing,"Fixed A opens capture even when gameplay A is drag")
	await press(JOY_BUTTON_X)
	check(not scene.controller.capturing and scene._bindings_draft.confirm == "b2","Capture updates draft")
	check(scene.controller.bindings == changed,"Capture does not apply before Save")
	await press(JOY_BUTTON_B)
	check(not scene.controller.settings_mode and scene.controller.bindings == changed,"Fixed B discards draft and leaves panel")
	scene._show_controller_settings()
	scene._capture_controller_binding("confirm")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	Input.flush_buffered_events()
	await frames()
	check(scene.controller.settings_mode and not scene.controller.capturing,"Escape cancels capture but keeps mapping panel")
	scene._capture_controller_binding("confirm")
	scene.controller.cancel_capture()
	scene._help()
	await frames()
	check(not scene.controller.settings_mode,"Deferred capture cancellation cannot reopen over newer navigation")
	scene._show_controller_settings()
	scene._bindings_draft = Bindings.swap_binding(changed,"confirm","b2")
	scene.preferences.file_path = "user://missing-directory/mapping.json"
	scene._save_controller_settings()
	check(scene.controller.settings_mode and scene.controller.bindings == changed,"Save failure leaves old live mapping and draft open")
	check(scene._binding_message.contains("Could not save"),"Save failure explains retry")
	scene.preferences.file_path = settings_path
	scene._save_controller_settings()
	check(scene.controller.bindings.confirm == "b2" and store.read_settings().controller_bindings.confirm == "b2","Retry saves and applies mapping")
	check(scene._controller_hint("A plant / X gear") == "X plant / RT gear","Hints use mapped bindings without cascading replacement")
	scene._show_controller_settings()
	for item in scene.overlay.find_children("*","Button",true,false):
		if item.text.begins_with("Reset to defaults"):
			item.pressed.emit()
			break
	check(scene._bindings_draft == defaults and scene.controller.bindings.confirm == "b2","Reset is staged until Save")
	scene._save_controller_settings()
	check(scene.controller.bindings == defaults and store.read_settings().controller_bindings == defaults,"Reset saves defaults")
	scene._show_controller_settings()
	scene._capture_controller_binding("camera")
	scene.controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await frames()
	check(not scene.controller.capturing and scene.controller.settings_mode,"Interrupted UI capture returns safely to settings")
	scene.controller._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	scene._close_overlay()
	scene.queue_free()
	await frames()
	DirAccess.remove_absolute(settings_path)
	print("CONTROLLER_MAPPING_PASS %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
