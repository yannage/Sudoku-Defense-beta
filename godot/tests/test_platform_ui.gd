extends SceneTree
## Production UI with unique local profiles. Never initializes or awards through
## real Steam. Scoped/cloud labels below use an explicitly injected status mock.
## --render-check requires a real framebuffer; screenshots include Deck/portrait.

const Run = preload("res://scripts/run.gd")
const DEVICE := 47
var scene
var checks := 0
var failures := 0
var rendered := false
var variant := "native"
var output := "res://build/platform-ui-checks"
var folder := "user://pui-%d" % Time.get_ticks_usec()
var sequence := 0

class DisplayPlatform:
	extends Node
	signal stats_stored(success: bool)
	var account_id := "76561198000000001"
	var cloud_enabled := false
	func get_status() -> Dictionary:
		return {"available": false, "ready": false, "account_id": account_id, "app_id": 3721150, "cloud_enabled": cloud_enabled}
	func shutdown() -> void: pass
	func pump(_delta: float) -> void: pass

class DisplayAchievements:
	extends RefCounted
	var pending := 1
	func get_status() -> Dictionary:
		return {"pending_count": pending, "unlocked_count": pending}
	func entries() -> Array[Dictionary]: return []

func _initialize() -> void:
	Engine.max_fps = 120
	rendered = "--render-check" in OS.get_cmdline_user_args()
	variant = "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output = arg.trim_prefix("--capture-dir=")
	if rendered and DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_MINIMIZED
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 4) -> void:
	for index in range(count):
		if is_instance_valid(scene): scene.world.tick(1.0/60.0)
		await process_frame
		if rendered: RenderingServer.force_draw(false)

func press(index: int) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = index
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1 if down else 4)

func button_named(text: String) -> Button:
	for node in scene.overlay.find_children("*", "Button", true, false):
		if node.text == text: return node
	return null

func texts() -> String:
	var result: Array[String] = []
	for node in scene.overlay.find_children("*", "Label", true, false): result.append(node.text)
	return "\n".join(result)

func focused_id() -> String:
	var control := root.gui_get_focus_owner()
	return str(control.get_meta("focus_id", "")) if is_instance_valid(control) else ""

func focus_visible(context: String) -> void:
	var control: Control = root.gui_get_focus_owner()
	check(is_instance_valid(control), context + ": focus exists")
	if not is_instance_valid(control): return
	check(control.is_visible_in_tree() and not control.disabled, context + ": focus usable")
	check(root.get_visible_rect().grow(2).encloses(control.get_global_rect()), context + ": focused action fits viewport")
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			check(parent.get_global_rect().grow(2).encloses(control.get_global_rect()), context + ": focused action is scrolled into view")
		parent = parent.get_parent()

func focus_outline_visible(context: String) -> void:
	var control: Button = root.gui_get_focus_owner()
	check(is_instance_valid(control), context + ": focused Back exists")
	if not is_instance_valid(control): return
	var focus: StyleBoxFlat = control.get_theme_stylebox("focus")
	var outline := control.get_global_rect().grow_individual(focus.expand_margin_left,focus.expand_margin_top,focus.expand_margin_right,focus.expand_margin_bottom)
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			check(parent.get_global_rect().encloses(outline), context + ": entire focus outline fits inside scroll clipping bounds")
		parent = parent.get_parent()

func make_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await frames(2)
	sequence += 1
	var base := folder.path_join(str(sequence))
	check(DirAccess.make_dir_recursive_absolute(base) == OK, "Create unique UI profile")
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = base.path_join("settings.json")
	scene.run_save.file_path = base.path_join("run.json")
	root.add_child(scene)
	await frames(5)
	scene.sound.set_muted(true)
	scene.set_process(false)
	check(not scene.steam_platform.get_status().available, "--no-steam/editor fixture cannot initialize production Steam")
	check(scene.run_save.file_path == base.path_join("run.json"), "Explicit test run path is preserved")
	check(str(scene.achievements.store.file_path).begins_with(base), "Achievement data stays inside same test profile")

func start(seed: int = 784217) -> void:
	scene._show_menu(true)
	await frames()
	scene.seed_input.text = str(seed)
	scene._start_run()
	await frames()

func first_blank() -> int:
	for cell in range(81):
		if scene.run.board[cell] == 0: return cell
	return -1

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Fixture writes only its isolated path")
	if file == null: return
	file.store_string(JSON.stringify(value))
	file.close()

func capture(stage: String, size := Vector2i(1280,800), check_focus := true) -> void:
	if not rendered: return
	scene._layout_ui()
	scene._refresh()
	scene.notice.hide()
	scene.notice_time = 0
	scene._update_context_visibility()
	await frames(8)
	var image: Image = root.get_texture().get_image()
	check(image != null and not image.is_empty(), stage + ": framebuffer exists")
	if image == null or image.is_empty(): return
	check(image.get_size() == size, stage + ": expected capture resolution")
	var colors := {}
	var bright := 0
	for y in range(0,size.y,8):
		for x in range(0,size.x,8):
			var color := image.get_pixel(x,y)
			colors[color.to_rgba32()] = true
			if color.r+color.g+color.b > 1.2: bright += 1
	check(colors.size() > 100 and bright > 100, stage + ": visible text and graphics")
	if check_focus: focus_visible(stage)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	check(image.save_png(output.path_join(variant+"-"+stage+".png")) == OK, stage + ": capture saved")

func gameplay_and_practice() -> void:
	await start()
	check(scene.has_active_run and not scene.save_failed, "Ordinary local new run saves successfully")
	check(scene.run_save.staging_path.is_empty(), "Local saves use sibling staging fallback")
	check(FileAccess.file_exists(scene.run_save.file_path), "Normal local run file exists")
	var id: String = scene.run.achievement_stats.run_id
	check(id.length() == 32, "Actual player run receives a unique tracking ID")
	var reference := Run.new()
	reference.new_run(784217, {"mode":"campaign", "puzzle_difficulty":"easy", "combat_difficulty":"easy"})
	check(scene.run.rng.state == reference.rng.state and scene.run.board == reference.board and scene.run.items == reference.items, "Tracking ID does not consume gameplay RNG")
	var cell := first_blank()
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	check(scene._controller_number_cell == cell, "Controller A still opens number picker")
	var correct: int = scene.run.solution[cell]
	for attempt in range(9):
		if scene.selected_number == correct: break
		await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.selected_number == correct, "Controller bumpers select the correct tray number")
	await press(JOY_BUTTON_A)
	check(scene.run.board[cell] == correct and scene.selected_cell == cell and scene._controller_number_cell == -1, "Controller placement returns to selected square")
	check(scene.achievements.unlocked.has("SD_FIRST_PLANT") and scene.achievements.pending_keys().has("SD_FIRST_PLANT"), "Actual placement saves pending local achievement")
	check(not scene.achievement_save_failed, "Local achievement profile saved successfully")
	var real_run := FileAccess.get_file_as_string(scene.run_save.file_path)
	var real_achievements := FileAccess.get_file_as_string(scene.achievements.store.file_path)
	var unlocked: int = scene.achievements.get_status().unlocked_count
	scene.tutorial.start(scene)
	await frames()
	check(scene.tutorial.active and str(scene.run.achievement_stats.run_id).is_empty(), "Guide never receives an eligible player ID")
	scene._action(scene.run.place(first_blank(),scene.run.solution[first_blank()]))
	scene._observe_achievements()
	check(scene.achievements.get_status().unlocked_count == unlocked, "Practice actions never award profile achievements")
	check(FileAccess.get_file_as_string(scene.run_save.file_path) == real_run and FileAccess.get_file_as_string(scene.achievements.store.file_path) == real_achievements, "Practice preserves both real save files byte-for-byte")
	scene.tutorial.restore()
	await frames()
	check(scene.run.achievement_stats.run_id == id and scene.run.board[cell] == correct, "Leaving practice restores original run and tracking identity")
	# Exercise existing quick gear controller sequence with ordinary planted
	# towers and starting inventory; no arbitrary real-account achievements.
	for index in range(6):
		var blank := first_blank()
		scene._action(scene.run.place(blank,scene.run.solution[blank]))
	scene._action(scene.run.advance_phase())
	scene._close_overlay()
	scene._select(cell,false,false)
	await press(JOY_BUTTON_A)
	check(focused_id() == "slot:0", "Controller workshop still focuses first empty socket")
	await press(JOY_BUTTON_A)
	check(focused_id().begins_with("item:"), "Socket confirmation still focuses available module")
	await press(JOY_BUTTON_A)
	check(scene.run.towers[cell].attachments.size() == 1 and scene.selected_cell != cell, "Module equips once and selects next eligible tower")
	check(scene.achievements.unlocked.has("SD_FIRST_MODULE"), "Successful controller equip reaches achievement observer")
	await press(JOY_BUTTON_RIGHT_SHOULDER)
	check(scene.run.towers.has(scene.selected_cell), "Bumper still selects an eligible tower")
	await press(JOY_BUTTON_B)
	check(not scene.dock.is_open(), "B backs from upgrade context without losing board")
	# Same seed retry must start a new tracking record, preserving seed output.
	scene.run.phase = "lost"
	scene.run.health = 0
	scene._save()
	scene._show_result()
	scene._retry_same_seed()
	await frames()
	check(scene.run.seed_value == 784217 and scene.run.phase == "solve", "Same seed retry remains usable")
	check(scene.run.achievement_stats.run_id != id and scene.run.achievement_stats.run_id.length() == 32, "Same seed retry receives a fresh tracking identity")
	check(scene.run.rng.state == reference.rng.state and scene.run.board == reference.board, "Retry tracking does not change seed gameplay")

func achievement_navigation() -> void:
	check(texts().contains("D-pad / left stick: scroll"), "Achievement list explains controller scrolling")
	focus_outline_visible("achievement top")
	var scroll: ScrollContainer = scene.overlay.find_children("*", "ScrollContainer", true, false)[0]
	var limit := int(scroll.get_v_scroll_bar().max_value-scroll.size.y)
	check(limit > scroll.size.y and scroll.scroll_vertical == 0, "Achievement list starts at its top and spans multiple screens")
	await press(JOY_BUTTON_DPAD_DOWN)
	check(scroll.scroll_vertical > 0 and scroll.scroll_vertical < limit, "First D-pad Down reveals interior cards without jumping to the bottom")
	await capture("achievements-middle-deck",Vector2i(1280,800),false)
	for step in range(64):
		if scroll.scroll_vertical >= limit: break
		await press(JOY_BUTTON_DPAD_DOWN)
	check(scroll.scroll_vertical >= limit and focused_id() == "platform:back_bottom", "Repeated Down reaches the bottom with a useful Back action")
	focus_outline_visible("achievement bottom")
	var last_card: Control
	for node in scene.overlay.find_children("*", "PanelContainer", true, false):
		if node.has_meta("achievement_id"): last_card = node
	check(is_instance_valid(last_card) and scroll.get_global_rect().grow(2).encloses(last_card.get_global_rect()), "Last achievement card is visible after controller scrolling")
	await capture("achievements-bottom-deck")
	await press(JOY_BUTTON_A)
	check(button_named("Resume run") != null, "A on bottom Back returns to pause")
	button_named("Achievements").pressed.emit()
	await frames()
	scroll = scene.overlay.find_children("*", "ScrollContainer", true, false)[0]
	for step in range(64):
		if scroll.scroll_vertical >= limit: break
		await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_DPAD_UP)
	check(scroll.scroll_vertical > 0 and scroll.scroll_vertical < limit, "First Up from the bottom returns to interior cards")
	for step in range(64):
		if scroll.scroll_vertical == 0: break
		await press(JOY_BUTTON_DPAD_UP)
	check(scroll.scroll_vertical == 0 and focused_id() == "platform:back", "Repeated Up returns to the top Back action")
	focus_outline_visible("achievement return to top")
	await press(JOY_BUTTON_A)
	check(button_named("Resume run") != null, "A on achievement Back returns to pause")
	button_named("Achievements").pressed.emit()
	await frames()
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_B)
	check(button_named("Resume run") != null, "B returns from the middle of achievement list")
	# A also remains a predictable Back action while reading interior cards.
	button_named("Achievements").pressed.emit()
	await frames()
	await press(JOY_BUTTON_DPAD_DOWN)
	await press(JOY_BUTTON_A)
	check(button_named("Resume run") != null, "A backs out while reading interior achievement cards")

func panels() -> void:
	scene._show_pause_menu()
	check(button_named("Achievements") != null and button_named("Saves & Steam") != null, "Pause offers both platform panels")
	button_named("Achievements").pressed.emit()
	await frames()
	check(scene.overlay.get_meta("achievements_panel",false), "Achievements opens from pause")
	check(focused_id() == "platform:back", "Achievement panel starts on a useful Back action")
	var cards := 0
	var icons := 0
	for node in scene.overlay.find_children("*", "PanelContainer", true, false):
		if node.has_meta("achievement_id"):
			cards += 1
			for icon in node.find_children("*", "TextureRect", true, false):
				if icon.texture != null: icons += 1
	check(cards == 26 and icons == 26, "All26 achievements have descriptions and readable icon resources")
	check(texts().contains("Local achievements") and texts().contains("awaiting Steam"), "Local unlocks accurately show pending Steam status")
	await capture("achievements-deck")
	await achievement_navigation()
	check(not scene.overlay.get_meta("platform_panel",false) and button_named("Resume run") != null, "B returns from achievements to pause")
	focus_visible("achievement return")
	button_named("Saves & Steam").pressed.emit()
	await frames()
	check(texts().contains("Local saves on this device") and not texts().contains("Steam Cloud is enabled"), "Local Saves panel does not claim Cloud sync")
	await capture("local-saves-deck")
	await press(JOY_BUTTON_B)
	check(button_named("Resume run") != null, "B returns from Saves to pause")
	var mock := DisplayPlatform.new()
	scene.steam_platform.shutdown()
	scene.steam_platform.queue_free()
	scene.add_child(mock)
	scene.steam_platform = mock
	scene._configure_profiles(mock.get_status())
	check(scene.cloud_profile_status.get("scoped",false), "Mock account uses real scoped-path configuration without Steam calls")
	scene.platform_ui.show_saves()
	await frames()
	check(texts().contains("Cloud is unavailable or disabled") and texts().contains("still saved on this device"), "Scoped offline state explains local save safety")
	mock.cloud_enabled = true
	scene.platform_ui.show_saves()
	await frames()
	check(texts().contains("wait for Steam to report Up to date") and texts().contains("Suspend does not promise"), "Enabled Cloud status explains actual session boundaries")
	await capture("cloud-status-mock-deck")
	var saved_profile = scene.achievements
	var display_profile := DisplayAchievements.new()
	scene.achievements = display_profile
	scene.platform_ui.show_achievements()
	await frames()
	check(texts().contains("1 unlock waiting for Steam confirmation"), "A single pending unlock uses singular copy")
	display_profile.pending = 2
	scene.platform_ui.show_achievements()
	await frames()
	check(texts().contains("2 unlocks waiting for Steam confirmation"), "Multiple pending unlocks use plural copy")
	scene.achievements = saved_profile
	scene.platform_ui.show_achievements()
	await frames()
	check(texts().contains("waiting for Steam confirmation"), "Scoped pending unlock count remains explicit")
	root.size = Vector2i(720,1280)
	await frames(8)
	await capture("achievements-portrait",Vector2i(720,1280))
	scene.platform_ui.show_saves()
	await frames()
	await capture("saves-portrait",Vector2i(720,1280))
	root.size = Vector2i(1280,800)
	await frames(8)
	# A scoped achievement conflict must be recoverable from the actual panel,
	# including the aggregate profile error that initially blocks gameplay.
	var achievement_path: String = scene.achievements.store.file_path
	var archive_root: String = scene.achievements.store.staging_path.get_base_dir().get_base_dir().path_join("conflicts")
	var first := {"version":1,"account_id":mock.account_id,"unlocked":{"SD_FIRST_PLANT":true},"confirmed":{}}
	var second := {"version":1,"account_id":mock.account_id,"unlocked":{"SD_FIRST_BOSS":true},"confirmed":{},"_journal":{"version":1,"parent_sha256":"b".repeat(64)}}
	write_json(achievement_path,first)
	write_json(achievement_path+".pending",second)
	var first_text := FileAccess.get_file_as_string(achievement_path)
	var second_text := FileAccess.get_file_as_string(achievement_path+".pending")
	scene._configure_profiles(mock.get_status())
	check(not scene.cloud_profile_status.get("ok",true) and scene.achievements.get_status().recoverable, "Scoped achievement conflict blocks aggregate profile and exposes recovery")
	scene.platform_ui.show_achievements()
	await frames()
	var recover := button_named("Recover saved unlocks")
	check(recover != null and texts().contains("archives every original"), "Achievements offers explicit explained recovery action")
	if recover != null:
		check(texts().contains("Up at the top: save action"), "Recovery panel explains how to reach its action")
		await press(JOY_BUTTON_DPAD_UP)
		check(root.gui_get_focus_owner() == recover, "Up from top Back reaches explicit recovery without pointer assistance")
		focus_visible("achievement recovery action")
		await press(JOY_BUTTON_DPAD_UP)
		check(root.gui_get_focus_owner() == recover, "Up at the first recovery action retains useful focus")
		await press(JOY_BUTTON_DPAD_DOWN)
		check(focused_id() == "platform:back", "Down from recovery returns to top Back before scrolling")
		await press(JOY_BUTTON_DPAD_DOWN)
		var scroll: ScrollContainer = scene.overlay.find_children("*", "ScrollContainer", true, false)[0]
		check(scroll.scroll_vertical > 0 and root.gui_get_focus_owner() != recover, "Scrolling recovery panel cannot leave recovery selected")
		for step in range(64):
			if scroll.scroll_vertical == 0: break
			await press(JOY_BUTTON_DPAD_UP)
		await press(JOY_BUTTON_DPAD_UP)
		check(root.gui_get_focus_owner() == recover, "Recovery remains reachable after browsing cards")
		# Model wheel/touch scrolling while the recovery button retains GUI focus.
		scroll.scroll_vertical = 200
		await frames()
		await press(JOY_BUTTON_DPAD_DOWN)
		check(scroll.scroll_vertical > 200 and focused_id() == "platform:back", "Switching from pointer scrolling to controller replaces hidden recovery focus with Back")
		for step in range(64):
			if scroll.scroll_vertical == 0: break
			await press(JOY_BUTTON_DPAD_UP)
		await press(JOY_BUTTON_DPAD_UP)
		check(root.gui_get_focus_owner() == recover, "Explicit recovery remains reachable after changing input methods")
		await press(JOY_BUTTON_A)
		check(scene.cloud_profile_status.get("ok",false) and not scene.achievement_save_failed, "Recovery UI refreshes overall profile status")
		check(scene.achievements.unlocked.has("SD_FIRST_PLANT") and scene.achievements.unlocked.has("SD_FIRST_BOSS"), "Recovery UI retains union of both saved unlock sets")
		check(button_named("Recover saved unlocks") == null, "Successful recovery exits permanent error loop")
		var archived_both := false
		for directory in DirAccess.get_directories_at(ProjectSettings.globalize_path(archive_root)):
			var path: String = archive_root.path_join(directory)
			if FileAccess.file_exists(path.path_join("achievements.json")) and FileAccess.file_exists(path.path_join("achievements.json.pending")):
				archived_both = FileAccess.get_file_as_string(path.path_join("achievements.json")) == first_text and FileAccess.get_file_as_string(path.path_join("achievements.json.pending")) == second_text
		check(archived_both, "Recovery UI archives original achievement variants byte-for-byte")

func unsaved_achievement_guard() -> void:
	await make_scene()
	await start(4590)
	var path: String = scene.achievements.store.file_path
	var missing: String = folder.path_join("achievement-io-blocked/missing/profile.json")
	scene.achievements.configure(missing,"","")
	var cell := first_blank()
	scene._action(scene.run.place(cell,scene.run.solution[cell]))
	check(scene.achievement_save_failed and not scene._save(), "Achievement I/O failure makes combined save fail")
	var seed: int = scene.run.seed_value
	scene._show_menu(true)
	scene.seed_input.text = "4591"
	scene._start_run()
	await frames()
	check(scene.run.seed_value == seed and scene.overlay.get_meta("achievements_panel",false), "Unsaved achievements block replacing run evidence")
	scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(scene.overlay.get_meta("unsaved_quit",false), "Quit offers retry/keep-playing when achievement save failed")
	# The fixture restores the path explicitly; player flow uses the retry button
	# once its storage problem is resolved.
	DirAccess.make_dir_recursive_absolute(missing.get_base_dir())
	check(scene.achievements.retry_save(), "Achievement I/O recovery keeps earned evidence")
	scene._observe_achievements()
	check(not scene.achievement_save_failed and scene._save(), "Combined save becomes safe after achievement retry")
	check(scene.achievements.unlocked.has("SD_FIRST_PLANT"), "Failure and recovery never lose earned unlock")
	check(not FileAccess.file_exists(path), "Failure fixture never writes a different achievement path")

func conflict_and_future() -> void:
	await make_scene()
	await start(4501)
	var original_seed: int = scene.run.seed_value
	var path: String = scene.run_save.file_path
	var replacement := Run.new()
	replacement.new_run(4502)
	write_json(path,replacement.save_data())
	var external := FileAccess.get_file_as_string(path)
	scene.platform_ui.show_saves()
	await frames()
	check(texts().contains("changed outside this session"), "Saves panel explains external file change")
	check(not scene.run_save.check_current(), "Opening Saves cannot reset external-change baseline")
	check(not scene._can_replace_saved_run(), "External change blocks New Run replacement after panel inspection")
	check(FileAccess.get_file_as_string(path) == external and scene.run.seed_value == original_seed, "Inspecting changed files never loads or overwrites them")
	var pending := Run.new()
	pending.new_run(4503)
	var pending_data: Dictionary = pending.save_data()
	pending_data["_journal"] = {"version":1,"parent_sha256":"a".repeat(64)}
	write_json(path+".pending",pending_data)
	var pending_text := FileAccess.get_file_as_string(path+".pending")
	scene.platform_ui.show_saves()
	await frames()
	check(texts().contains("after syncing"), "Cross-device journal conflict is visible")
	var choice: Button
	for node in scene.overlay.find_children("*", "Button", true, false):
		if node.text.begins_with("Interrupted save"): choice = node
	check(choice != null, "Validated interrupted version has an explicit choice")
	await capture("conflict-deck")
	if choice != null:
		choice.grab_focus()
		await press(JOY_BUTTON_A)
		check(button_named("Use this run") != null and button_named("Keep both / go back") != null, "Conflict choice opens concrete confirmation")
		check(root.gui_get_focus_owner() == button_named("Keep both / go back"), "Confirmation defaults to keeping both versions")
		check(FileAccess.get_file_as_string(path) == external, "Confirmation alone preserves primary")
		button_named("Use this run").grab_focus()
		await press(JOY_BUTTON_A)
		check(scene.run.seed_value == 4503 and scene.has_active_run, "Explicit choice loads chosen run")
		var archive: String = scene.run_save.last_archive_path
		check(not archive.is_empty(), "Resolution exposes local archive evidence")
		if not archive.is_empty():
			check(FileAccess.get_file_as_string(archive.path_join(path.get_file())) == external, "Previous primary archived byte-for-byte before load")
			check(FileAccess.get_file_as_string(archive.path_join(path.get_file()+".pending")) == pending_text, "Interrupted version archived byte-for-byte before load")
	await make_scene()
	await start(4510)
	path = scene.run_save.file_path
	var newer: Dictionary = scene.run.save_data()
	newer.version = 2
	write_json(path,newer)
	var newer_text := FileAccess.get_file_as_string(path)
	scene._show_menu(true)
	scene.seed_input.text = "4511"
	scene._start_run()
	await frames()
	check(scene.run.seed_value == 4510 and scene.overlay.get_meta("saves_panel",false), "Future schema blocks New Run and opens save explanation")
	check(texts().contains("newer game version") and button_named("Use this run") == null, "Future format cannot be selected by older game")
	check(FileAccess.get_file_as_string(path) == newer_text, "Future save remains byte-for-byte")
	await capture("future-version-deck")

func exercise() -> void:
	if rendered and DisplayServer.get_name() == "headless":
		push_error("Platform render checks require a real graphics renderer")
		quit(1)
		return
	check("--no-steam" in OS.get_cmdline_user_args(), "Platform UI test explicitly requires --no-steam")
	if not "--no-steam" in OS.get_cmdline_user_args():
		quit(1)
		return
	root.size = Vector2i(1280,800)
	await make_scene()
	await gameplay_and_practice()
	await panels()
	await unsaved_achievement_guard()
	await conflict_and_future()
	print("PLATFORM_UI_%s %d checks / %d failures (%s%s)" % ["PASS" if failures == 0 else "FAIL",checks,failures,variant,", rendered" if rendered else ", headless"])
	scene.queue_free()
	await frames(2)
	quit(1 if failures else 0)
