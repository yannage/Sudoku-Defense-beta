extends SceneTree
## Production overlays and joypad events; disposable injected profiles only.
const DEVICE := 51
var scene
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var sequence := 0
var rendered := false

func _initialize() -> void:
	Engine.max_fps = 120
	rendered = OS.get_cmdline_user_args().has("--render-check")
	if rendered and DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func frames(count := 3) -> void:
	for index in range(count):
		await process_frame
		if rendered: RenderingServer.force_draw(false)

func capture(name: String) -> void:
	if not rendered: return
	check(DisplayServer.get_name() != "headless","Capture requires actual framebuffer")
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(),"Capture has framebuffer pixels")
	if image == null or image.is_empty(): return
	DirAccess.make_dir_recursive_absolute("user://captures")
	check(image.save_png("user://captures/"+name+".png") == OK,"Capture saved")

func button(prefix: String) -> Button:
	if not is_instance_valid(scene.overlay): return null
	for node in scene.overlay.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and node.text.begins_with(prefix): return node
	return null

func focused_text() -> String:
	var owner := root.gui_get_focus_owner()
	return owner.text if owner is Button else "<none>"

func edge(index: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(2)

func press(index: int) -> void:
	await edge(index,true)
	await edge(index,false)

func activate(prefix: String) -> void:
	var target := button(prefix)
	check(is_instance_valid(target),"Controller action exists: "+prefix)
	if not is_instance_valid(target): return
	target.grab_focus()
	await frames()
	await press(JOY_BUTTON_A)

func focus_visible(context: String) -> void:
	var focused: Control = root.gui_get_focus_owner()
	check(is_instance_valid(focused),context+" focus exists")
	if not is_instance_valid(focused): return
	check(focused.is_visible_in_tree() and not focused.disabled,context+" focus usable")
	check(root.get_visible_rect().grow(2).encloses(focused.get_global_rect()),context+" focused control fits viewport")
	var parent := focused.get_parent()
	var bounds: Array[Dictionary] = []
	while parent != null:
		if parent is ScrollContainer:
			check(parent.get_global_rect().grow(2).encloses(focused.get_global_rect()),context+" focus scrolled into view")
			bounds.append({"rect":str(parent.get_global_rect()),"scroll_vertical":parent.scroll_vertical})
		parent = parent.get_parent()
	observations.append({"context":context,"focus":focused_text(),"focus_rect":str(focused.get_global_rect()),"viewport":str(root.get_visible_rect()),"scrolls":bounds})

func snapshot() -> String:
	return JSON.stringify(scene.run.save_data(),"",true,true)

func make_scene(size: Vector2i, start_run := true) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await frames()
	sequence += 1
	root.size = size
	var base := "user://overlay-transitions-%d" % sequence
	check(DirAccess.make_dir_recursive_absolute(base) == OK,"Create isolated profile")
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = base.path_join("settings.json")
	scene.run_save.file_path = base.path_join("run.json")
	root.add_child(scene)
	await frames(7)
	scene.set_process(false)
	scene.sound.set_muted(true)
	check(not scene.steam_platform.get_status().available,"Real Steam is disabled")
	check(scene.achievements.store.file_path.begins_with(base),"Achievement profile is inside isolated base")
	if not start_run: return
	scene.seed_input.text = "784217"
	await activate("Start run")
	check(scene.has_active_run and not scene.menu_open,"A starts the seeded synthetic run")
	var cell: int = scene.run.board.find(0)
	check(scene.run.place(cell,scene.run.solution[cell]).ok,"Actual placement earns normal progress")
	scene._save()
	scene._select(scene.run.board.find(0),false,false)
	await frames()

func overlay_cycle(size: Vector2i) -> void:
	await make_scene(size)
	var label := str(size)
	var initial := snapshot()
	var selection: int = scene.selected_cell
	var run_bytes := FileAccess.get_file_as_string(scene.run_save.file_path)
	var achievement_bytes := FileAccess.get_file_as_string(scene.achievements.store.file_path)
	await press(JOY_BUTTON_START)
	check(scene.menu_open and button("Resume run") != null,label+" Start opens pause")
	await activate("Achievements")
	check(scene.overlay.get_meta("achievements_panel",false),label+" Achievements opens")
	for index in [JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_DPAD_RIGHT]:
		await press(index)
		check(scene.menu_open and snapshot() == initial and scene.selected_cell == selection,label+" overlay blocks gameplay button "+str(index))
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_B)
	check(scene.menu_open and button("Resume run") != null,label+" B returns achievements to pause")
	focus_visible(label+" achievement return")
	await activate("Settings / How to play")
	check(button("Got it") != null,label+" Help opens")
	await frames(20)
	focus_visible(label+" help default")
	await capture("help-default-%dx%d" % [size.x,size.y])
	for prefix in ["Reduced motion:","Sound:","Notes:","Battle speed:"]:
		var before := focused_text()
		await activate(prefix)
		var actual := focused_text()
		observations.append({"size":str(size),"control":prefix,"focus_after":actual,"prior_default":before})
		check(actual.begins_with(prefix),label+" Help setting retains focus after update: "+prefix+" -> "+actual)
		check(scene.menu_open and snapshot() == initial,label+" Help setting never changes run")
		await press(JOY_BUTTON_A)
		check(scene.menu_open and focused_text().begins_with(prefix),label+" Second complete A adjusts same Help setting rather than closing Help: "+prefix)
		if not scene.menu_open: await press(JOY_BUTTON_BACK)
	await activate("Audio settings")
	check(scene.overlay.get_meta("audio_settings",false),label+" Help opens audio")
	focus_visible(label+" audio initial")
	var volume: float = scene.master_volume
	await edge(JOY_BUTTON_A,true)
	for tick in range(60): await process_frame
	check(is_equal_approx(scene.master_volume,volume-0.05),label+" Holding A adjusts audio only once")
	await edge(JOY_BUTTON_A,false)
	check(is_equal_approx(scene.master_volume,volume-0.05),label+" Release does not adjust audio again")
	for repeat in range(3): await press(JOY_BUTTON_A)
	check(is_equal_approx(scene.master_volume,volume-0.20),label+" Three complete presses each adjust audio once")
	await activate("Done")
	check(not scene.menu_open and scene._controller_number_cell == -1,label+" Done leaves an escape path without opening board picker")
	check(snapshot() == initial and scene.selected_cell == selection,label+" Closing settings preserves run and board selection")
	await press(JOY_BUTTON_BACK)
	check(button("Got it") != null,label+" View opens Help again")
	await activate("Play guided first round")
	check(scene.tutorial.active and scene.overlay.get_meta("first_round_guide",false),label+" Help starts isolated guide")
	await activate("Try it")
	check(not scene.menu_open and scene._controller_number_cell == -1,label+" Guide card confirmation cannot plant or open picker underneath")
	var practice_cell: int = scene.run.board.find(0)
	check(scene.run.place(practice_cell,scene.run.solution[practice_cell]).ok,label+" Actual practice placement")
	scene._observe_achievements()
	scene._save()
	await press(JOY_BUTTON_START)
	await activate("Achievements")
	await press(JOY_BUTTON_B)
	check(button("Skip guide / return") != null,label+" Practice achievement Back reaches escape action")
	await activate("Skip guide / return")
	check(not scene.tutorial.active and not scene.menu_open and scene._controller_number_cell == -1,label+" Skip returns to original board without confirm leaking")
	check(snapshot() == initial and scene.selected_cell == selection,label+" Practice exit restores original run and selection")
	check(FileAccess.get_file_as_string(scene.run_save.file_path) == run_bytes,label+" Menus and practice preserve run journal bytes")
	check(FileAccess.get_file_as_string(scene.achievements.store.file_path) == achievement_bytes,label+" Practice preserves original achievement journal bytes")
	for repeat in range(3): await press(JOY_BUTTON_B)
	check(snapshot() == initial,label+" Repeated cancel cannot alter restored run")
	await press(JOY_BUTTON_START)
	await activate("New run")
	await activate("Guided first round")
	await activate("Skip guide / return")
	check(not scene.tutorial.active and snapshot() == initial,label+" Guide launched from New Run setup preserves current run")

func initial_menu_practice() -> void:
	await make_scene(Vector2i(1280,800),false)
	check(not scene.has_active_run and scene.menu_open,"Fresh setup has no active run")
	await activate("Guided first round")
	check(scene.tutorial.active,"Fresh setup can enter guide with controller")
	await activate("Skip guide / return")
	check(not scene.tutorial.active and not scene.has_active_run and scene.menu_open,"Guide skip returns to fresh setup without starting a run")
	focus_visible("Fresh setup after guide")
	check(not FileAccess.file_exists(scene.run_save.file_path),"Fresh-menu practice creates no normal run save")
	check(not FileAccess.file_exists(scene.achievements.store.file_path),"Fresh-menu practice creates no normal achievement save")
	for repeat in range(3): await press(JOY_BUTTON_B)
	check(scene.menu_open and not scene.has_active_run,"Repeated Back on fresh setup cannot start or save a run")

func exercise() -> void:
	check(OS.get_cmdline_user_args().has("--no-steam"),"Required no-Steam flag")
	for size in [Vector2i(1280,800),Vector2i(960,540),Vector2i(600,1066)]: await overlay_cycle(size)
	await initial_menu_practice()
	var data := {"checks":checks,"failures":failures,"observations":observations,"variant":"canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native","method":"Real scene and Input.parse_input_event; disposable synthetic profiles; held-A emits one down and one up; public gameplay placement only."}
	var file := FileAccess.open("user://overlay-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t",true,true))
	file.close()
	for failure in failures: push_error(failure)
	print("OVERLAY_TRANSITIONS_%s %d checks / %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	scene.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
