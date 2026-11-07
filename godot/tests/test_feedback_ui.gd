extends SceneTree
var scene
var failures := 0
var opened: Array[String] = []
var copied: Array[String] = []
func _initialize() -> void: call_deferred("exercise")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func frames(count: int = 3) -> void:
	for i in count: await process_frame
func press(index: int) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 42
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		await frames()
func action(id: String) -> Button:
	for node in scene.overlay.find_children("*", "Button", true, false):
		if node.get_meta("focus_id", "") == "feedback:" + id: return node
	return null
func activate(id: String) -> void:
	var button := action(id)
	check(is_instance_valid(button), "Action exists " + id)
	if button == null: return
	button.grab_focus()
	await press(JOY_BUTTON_A)
func exercise() -> void:
	root.size = Vector2i(1280, 800)
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = "user://feedback-settings.json"
	scene.run_save.file_path = "user://feedback-run.json"
	root.add_child(scene)
	await frames(8)
	scene.sound.set_muted(true)
	var feedback = scene.feedback_ui
	feedback.service.opener = func(url: String) -> int: opened.append(url); return ERR_CANT_OPEN
	feedback.copy_writer = func(text: String): copied.append(text)
	# Exercise the installed route through injected browser/clipboard boundaries.
	var installed_enabled: bool = feedback.service.configured()
	if feedback.service.route.get("verified", false):
		check(installed_enabled, "Verified release route is valid")
	feedback.show_panel()
	await frames()
	check(action("bug").disabled == (not installed_enabled) and action("idea").disabled == (not installed_enabled), "Installed route controls online actions")
	if installed_enabled:
		await activate("bug")
		check(action("cancel").has_focus() and opened.is_empty(), "Installed route requires deliberate confirmation")
		feedback.service.opener = func(url: String) -> int: opened.append(url); return OK
		await activate("open")
		check(opened.size() == 1 and opened[0] == feedback.service.report_url("bug", feedback._version(), feedback._platform()), "Installed route opens only its expected URL via the stub")
		check(copied.is_empty(), "Installed route attaches no report outline automatically")
		await press(JOY_BUTTON_B)
	opened.clear()
	feedback.service.opener = func(url: String) -> int: opened.append(url); return ERR_CANT_OPEN
	feedback.service.route = {} # Explicit disabled fixture; never depend on release config.
	feedback.show_panel()
	await frames()
	check(action("bug").disabled and action("idea").disabled, "Unconfigured online actions disabled")
	check(opened.is_empty() and copied.is_empty(), "Opening feedback has no side effects")
	await activate("copy_bug")
	check(copied.size() == 1 and copied[0].contains("Platform:"), "Explicit local copy")
	await press(JOY_BUTTON_B)
	check(scene.menu_open and not scene.overlay.get_meta("feedback_panel", false), "Back returns to start menu")
	feedback.service.route = {"mode":"form", "url":"https://example.com/feedback", "verified":true, "notice":"No account is needed. Submitted reports are private to YAKStudios and its Trello triage board."}
	check(feedback.service.privacy_notice().contains("No account"), "Form privacy notice includes account requirements")
	feedback.show_panel()
	await frames()
	await activate("bug")
	check(scene.overlay.get_meta("feedback_confirmation", false), "Action requests confirmation")
	check(action("cancel").has_focus() and opened.is_empty(), "Cancel focused to prevent repeated-button launch")
	await press(JOY_BUTTON_A)
	check(not scene.overlay.get_meta("feedback_confirmation", false) and opened.is_empty(), "Repeated confirm safely cancels")
	await activate("idea")
	await activate("open")
	check(opened.size() == 1 and feedback.status.text.contains("Could not open"), "Browser error actionable, no success claim")
	feedback.service.opener = func(url: String) -> int: opened.append(url); return OK
	await activate("open")
	feedback._open()
	check(opened.size() == 2 and action("open").disabled, "Repeated open cannot launch twice")
	check(opened.all(func(url: String): return url == "https://example.com/feedback"), "Form opens only its exact URL without metadata")
	await press(JOY_BUTTON_B)
	check(scene.overlay.get_meta("feedback_panel", false) and not scene.overlay.get_meta("feedback_confirmation", false), "B backs out of confirmation")
	scene._start_run()
	await frames()
	feedback.show_panel()
	await frames()
	check(scene.has_active_run and scene.menu_open, "Feedback pauses active run")
	await press(JOY_BUTTON_B)
	check(scene.has_active_run and scene.menu_open and not scene.overlay.get_meta("feedback_panel", false), "Back stays in paused menu")
	feedback.show_panel()
	await frames()
	root.size = Vector2i(390, 844)
	await frames(8)
	check(scene.menu_open and is_instance_valid(action("back")), "Portrait modal remains reachable")
	await press(JOY_BUTTON_B)
	scene.queue_free()
	await frames()
	print("FEEDBACK UI TESTS: " + ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures else 0)
