extends SceneTree
## Real production dialogs and input routing with disposable local saves only.
const Run = preload("res://scripts/run.gd")
const Profile = preload("res://scripts/achievement_profile.gd")
const DEVICE := 47
var scene
var checks := 0
var failures: Array[String] = []
var sequence := 0
var results: Array[Dictionary] = []
var achievement_timeline: Array[Dictionary] = []
var root_folder := "user://recovery-controller"
var rendered := false
var variant := "native"
var output := "res://build/recovery-controller-checks"

class CountingSave:
	extends "res://scripts/run_save.gd"
	var resolutions := 0
	func resolve_candidate(value: String) -> bool:
		resolutions += 1
		return super.resolve_candidate(value)

class FaultAchievementStore:
	extends Profile.ProfileStore
	var fail_writes := true
	var attempts := 0
	func _write_verified(path: String, text: String) -> bool:
		attempts += 1
		if fail_writes: return false
		return super._write_verified(path,text)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func frames(count := 4) -> void:
	for index in range(count):
		if is_instance_valid(scene): scene.world.tick(1.0/60.0)
		await process_frame
		if rendered: RenderingServer.force_draw(false)

func raw_button(index: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE
	event.button_index = index
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(1)

func press(index: int) -> void:
	await raw_button(index,true)
	await raw_button(index,false)
	await frames(3)

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(1)
	await frames(3)

func named(value: String) -> Button:
	if not is_instance_valid(scene.overlay): return null
	for node in scene.overlay.find_children("*","Button",true,false):
		if node.text == value: return node
	return null

func choice() -> Button:
	for node in scene.overlay.find_children("*","Button",true,false):
		if node.text.begins_with("Interrupted save"): return node
	return null

func snapshot_files() -> Dictionary:
	var result := {}
	for path: String in [scene.run_save.file_path,scene.run_save.file_path+".pending",scene.run_save.file_path+".bak",scene.achievements.store.file_path]:
		result[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<absent>"
	return result

func state() -> String:
	return JSON.stringify(scene.run.save_data(),"",true,true)

func write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	check(file != null,"Write isolated synthetic save fixture")
	if file != null:
		file.store_string(JSON.stringify(data,"",true,true))
		file.close()

func make_scene(seed_value := 8111, start_run := true, earn_placement := true) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await frames(3)
	sequence += 1
	var folder: String = root_folder.path_join(str(sequence))
	check(DirAccess.make_dir_recursive_absolute(folder) == OK,"Create disposable profile")
	scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = folder.path_join("settings.json")
	scene.run_save = CountingSave.new()
	scene.run_save.file_path = folder.path_join("run.json")
	root.add_child(scene)
	await frames(5)
	scene.set_process(false)
	scene.sound.set_muted(true)
	check(not scene.steam_platform.get_status().available,"Steam unavailable under --no-steam")
	if not start_run: return
	scene._show_menu(true)
	await frames()
	scene.seed_input.text = str(seed_value)
	scene._start_run()
	await frames()
	check(scene.has_active_run and scene.run.seed_value == seed_value and not scene.save_failed,"Start ordinary local run")
	if earn_placement:
		var blank: int = scene.run.board.find(0)
		scene._select(blank,false,false)
		scene._action(scene.run.place(blank,scene.run.solution[blank]))
		check(scene.achievements.unlocked.has("SD_FIRST_PLANT"),"Ordinary placement supplies real local achievement evidence")
	check(str(scene.achievements.store.file_path).begins_with(folder),"Achievement journal stays in disposable profile")

func add_conflict(seed_value := 9222) -> void:
	var external := Run.new()
	external.new_run(seed_value,{"achievement_run_id":"synthetic-recovery-selected"})
	var payload: Dictionary = external.save_data()
	payload["_journal"] = {"version":1,"parent_sha256":"b".repeat(64)}
	write_json(scene.run_save.file_path+".pending",payload)
	scene.platform_ui.show_saves()
	await frames()
	check(choice() != null,"Actual conflicting journal has validated interrupted choice")

func open_confirmation() -> void:
	var target := choice()
	check(target != null,"Recovery choice remains available")
	if target == null: return
	target.grab_focus()
	await press(JOY_BUTTON_A)
	check(named("Use this run") != null and named("Keep both / go back") != null,"Controller opens explicit confirmation")
	check(root.gui_get_focus_owner() == named("Keep both / go back"),"Confirmation initially focuses non-destructive cancel")

func cancel_and_blocking() -> void:
	for cancel: String in ["button","controller","keyboard"]:
		await make_scene()
		await add_conflict()
		var original := state()
		var files := snapshot_files()
		await open_confirmation()
		var selected: int = scene.selected_cell
		for button: int in [JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_LEFT_STICK]:
			await press(button)
		for code: Key in [KEY_1,KEY_H,KEY_I,KEY_TAB,KEY_P,KEY_HOME,KEY_Q,KEY_E]:
			await key(code)
		check(state() == original and scene.selected_cell == selected,"Overlay blocks gameplay and board movement during "+cancel+" case")
		check(snapshot_files() == files and scene.run_save.resolutions == 0,"Opening and idle inputs preserve all save/progress bytes")
		if cancel == "button":
			# Tab legitimately changes GUI focus; explicitly choose visible Cancel.
			named("Keep both / go back").grab_focus()
			await press(JOY_BUTTON_A)
		elif cancel == "controller": await press(JOY_BUTTON_B)
		else: await key(KEY_ESCAPE)
		check(is_instance_valid(scene.overlay) and scene.overlay.get_meta("saves_panel",false),cancel+" cancellation returns to save choices, matching visible Keep both action")
		check(state() == original and snapshot_files() == files and scene.run_save.resolutions == 0,cancel+" cancellation never resolves/loads/overwrites progress")
		results.append({"case":"cancel-"+cancel,"saves_panel":is_instance_valid(scene.overlay) and scene.overlay.get_meta("saves_panel",false),"resolutions":scene.run_save.resolutions})

func repeated_and_stale() -> void:
	await make_scene(8222)
	await add_conflict(9333)
	await open_confirmation()
	# Replace the candidate after confirmation, as an external sync race.
	var replacement := Run.new()
	replacement.new_run(9444)
	write_json(scene.run_save.file_path+".pending",replacement.save_data())
	var bytes := snapshot_files()
	var original := state()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(state() == original and snapshot_files() == bytes,"Stale explicit confirmation preserves current run and changed originals")
	check(scene.run_save.resolutions == 1 and scene.overlay.get_meta("saves_panel",false),"Rejected stale confirmation returns to refreshed choices")
	# Fresh choices may be explicitly selected once; subsequent presses only Back.
	await open_confirmation()
	named("Use this run").grab_focus()
	await raw_button(JOY_BUTTON_A,true)
	var chosen := state()
	var after := snapshot_files()
	await raw_button(JOY_BUTTON_A,false)
	check(scene.run.seed_value == 9444 and scene.run_save.resolutions == 2,"Fresh choice loads selected run once")
	for repeat in range(2): await press(JOY_BUTTON_A)
	check(scene.run_save.resolutions == 2 and state() == chosen and snapshot_files() == after,"Repeated distinct confirmations do not repeat recovery or mutate board")

func no_candidates() -> void:
	for kind: String in ["future","corrupt"]:
		await make_scene(8555)
		for suffix: String in ["",".pending",".bak"]:
			var data: Dictionary = scene.run.save_data()
			data.version = 2 if kind == "future" else -1
			write_json(scene.run_save.file_path+suffix,data)
		var bytes := snapshot_files()
		var original := state()
		scene.platform_ui.show_saves()
		await frames()
		var buttons: Array[Control] = scene._controller_buttons(scene.overlay)
		check(buttons.size() == 1 and buttons[0].text == "Back",kind+" only exposes safe Back when no choice is valid")
		for button: int in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
			await press(button)
			check(root.gui_get_focus_owner() == named("Back"),kind+" direction preserves the only usable action")
		await frames(20)
		await press(JOY_BUTTON_B)
		check(named("Resume run") != null,kind+" has controller escape to pause")
		check(state() == original and snapshot_files() == bytes and scene.run_save.resolutions == 0,kind+" navigation/cancel never overwrites blocked files")

func practice_recovery() -> void:
	await make_scene(8666)
	var previous := state()
	var achievement_bytes := FileAccess.get_file_as_string(scene.achievements.store.file_path)
	scene.tutorial.start(scene)
	await frames()
	check(scene.tutorial.active and scene.run.seed_value == 784217,"Practice uses its temporary run")
	await add_conflict(9777)
	var originals := snapshot_files()
	await open_confirmation()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.run.seed_value == 9777,"Recovery from practice initially loads chosen run")
	check(not scene.tutorial.active,"Choosing an explicit saved run ends practice before loading it")
	var archive: String = scene.run_save.last_archive_path
	check(not archive.is_empty(),"Recovery from practice retains an archive of original save variants")
	if not archive.is_empty():
		for suffix: String in ["",".pending",".bak"]:
			var path: String = scene.run_save.file_path+suffix
			if originals[path] != "<absent>":
				check(FileAccess.get_file_as_string(archive.path_join(scene.run_save.file_path.get_file()+suffix)) == originals[path],"Practice recovery archive preserves original bytes "+suffix)
	var loaded := state()
	# Invoke the player's actual guide-return action if it remains available.
	scene._show_pause_menu()
	await frames()
	var skip := named("Skip guide / return")
	if skip != null:
		skip.grab_focus()
		await press(JOY_BUTTON_A)
	check(scene.run.seed_value == 9777 and state() == loaded,"Leaving practice cannot restore stale pre-recovery snapshot over the chosen run")
	check(scene._save(),"Recovered active run can be saved")
	var stored: Dictionary = scene.run_save.read_run()
	check(int(stored.data.state.seed_value) == 9777,"Next save preserves explicitly chosen recovery rather than stale practice backup")
	check(FileAccess.get_file_as_string(scene.achievements.store.file_path) == achievement_bytes,"Recovery/practice transitions preserve original earned achievement journal")
	results.append({"case":"practice-recovery","tutorial_active":scene.tutorial.active,"final_seed":scene.run.seed_value,"persisted_seed":stored.data.state.seed_value,"prior_snapshot_restored":state()==previous})

func practice_cancellation_and_stale() -> void:
	await make_scene(8777)
	scene.tutorial.start(scene)
	await frames()
	await add_conflict(9888)
	var practice := state()
	var previous: String = JSON.stringify(scene.tutorial.previous,"",true,true)
	var bytes := snapshot_files()
	for cancel: String in ["button","controller","keyboard"]:
		scene.platform_ui.show_saves()
		await frames()
		await open_confirmation()
		if cancel == "button": await press(JOY_BUTTON_A)
		elif cancel == "controller": await press(JOY_BUTTON_B)
		else: await key(KEY_ESCAPE)
		check(scene.tutorial.active and state() == practice and JSON.stringify(scene.tutorial.previous,"",true,true) == previous,cancel+" cancellation preserves active practice and prior run snapshot")
		check(snapshot_files() == bytes and scene.run_save.resolutions == 0,cancel+" cancellation in practice preserves every original file")
	scene.platform_ui.show_saves()
	await frames()
	await open_confirmation()
	var changed := Run.new()
	changed.new_run(9999)
	write_json(scene.run_save.file_path+".pending",changed.save_data())
	bytes = snapshot_files()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.tutorial.active and state() == practice and JSON.stringify(scene.tutorial.previous,"",true,true) == previous,"Rejected stale recovery does not end practice or discard its prior snapshot")
	check(snapshot_files() == bytes and scene.run_save.resolutions == 1,"Rejected stale recovery in practice preserves changed files")
	# Return through the actual guide action after cancel/rejection: old run remains.
	scene._show_pause_menu()
	await frames()
	named("Skip guide / return").grab_focus()
	await press(JOY_BUTTON_A)
	check(not scene.tutorial.active and scene.run.seed_value == 8777,"Cancel/rejected recovery still permits returning to the original real run")
	check(snapshot_files() == bytes,"Returning from canceled/rejected recovery cannot overwrite conflict evidence")

func practice_without_prior_run() -> void:
	await make_scene(0,false)
	var guide := named("Guided first round")
	check(guide != null and not scene.has_active_run,"Initial menu has practice without an active real run")
	guide.grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.tutorial.active and not scene.tutorial.previous_active,"Guide started from initial menu through real controller event")
	var primary := Run.new()
	primary.new_run(9011)
	write_json(scene.run_save.file_path,primary.save_data())
	await add_conflict(9022)
	await open_confirmation()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(not scene.tutorial.active and scene.has_active_run and scene.run.seed_value == 9022,"Recovery from initial-menu practice becomes a normal active chosen run")
	scene._show_pause_menu()
	await frames()
	check(named("Skip guide / return") == null,"No stale guide-return action survives initial-menu recovery")
	check(scene._save() and int(scene.run_save.read_run().data.state.seed_value) == 9022,"Initial-menu recovery remains the active persistent run")

func layout_checks() -> void:
	await make_scene(9033)
	await add_conflict(9044)
	for size: Vector2i in [Vector2i(1280,800),Vector2i(720,1280),Vector2i(960,600)]:
		root.size = size
		await frames(8)
		scene.platform_ui.show_saves()
		await frames()
		await open_confirmation()
		for label: String in ["Keep both / go back","Use this run"]:
			var control := named(label)
			control.grab_focus()
			await frames()
			check(root.get_visible_rect().grow(2).encloses(control.get_global_rect()),"Recovery action fits viewport at "+str(size)+": "+label)
			var parent := control.get_parent()
			while parent != null:
				if parent is ScrollContainer: check(parent.get_global_rect().grow(2).encloses(control.get_global_rect()),"Focused recovery action is visible inside scroll container")
				parent = parent.get_parent()
		if rendered:
			var image: Image = root.get_texture().get_image()
			check(image != null and not image.is_empty() and image.get_size() == size,"Actual recovery framebuffer matches requested size")
			if image != null and not image.is_empty():
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
				check(image.save_png(output.path_join("%s-confirm-%dx%d.png" % [variant,size.x,size.y])) == OK,"Save recovery screenshot")
		await press(JOY_BUTTON_B)
	root.size = Vector2i(1280,800)

func record_achievement(label: String) -> void:
	achievement_timeline.append({"stage":label,"seed":scene.run.seed_value,"practice":scene.tutorial.active,"unlocked":scene.achievements.unlocked.duplicate(true),"pending":scene.achievements.pending_keys(),"dirty":scene.achievements._dirty,"blocked":scene.achievements._blocked,"save_failed":scene.achievement_save_failed,"resolutions":scene.run_save.resolutions,"files":snapshot_files()})

func open_saves_from_pause() -> void:
	var saves := named("Saves & Steam")
	check(saves != null,"Pause menu retains Saves & Steam escape/re-entry action")
	if saves == null: return
	saves.grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.overlay.get_meta("saves_panel",false),"Controller re-enters Saves from pause")

func unsaved_achievement_recovery(empty_profile: bool, practice: bool) -> void:
	await make_scene(7331,true,false)
	var label := "empty-profile-%s-practice-%s" % [empty_profile,practice]
	var path: String = scene.achievements.store.file_path
	if empty_profile:
		check(scene.achievements.store.write_data({"version":1,"account_id":"","unlocked":{},"confirmed":{}}),"Create valid empty achievement journal without awarding keys")
	var original_profile := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<absent>"
	var failing := FaultAchievementStore.new()
	failing.file_path = path
	failing.staging_path = scene.achievements.store.staging_path
	failing.read_data()
	scene.achievements.store = failing
	var cell: int = scene.run.board.find(0)
	scene._select(cell,false,false)
	scene._action(scene.run.place(cell,scene.run.solution[cell]))
	check(failing.attempts > 0 and scene.achievement_save_failed,"Legal placement reaches controlled journal failure")
	check(scene.achievements.unlocked.has("SD_FIRST_PLANT") and scene.achievements.pending_keys() == ["SD_FIRST_PLANT"] and scene.achievements._dirty,"Actually earned key remains pending in memory after failed persistence")
	check((FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<absent>") == original_profile,"Failed achievement write preserves earlier disk bytes")
	if practice:
		scene.tutorial.start(scene)
		await frames()
	await add_conflict(7330)
	var original_run := state()
	var originals := snapshot_files()
	var previous: String = JSON.stringify(scene.tutorial.previous,"",true,true)
	record_achievement(label+"-before-recovery")
	await open_confirmation()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.overlay.get_meta("achievements_panel",false),"Unsaved achievement routes recovery to explicit achievement attention UI")
	check(scene.run_save.resolutions == 0 and state() == original_run and snapshot_files() == originals,"Persistent achievement failure blocks run resolution before any file or active run replacement")
	check(scene.tutorial.active == practice and JSON.stringify(scene.tutorial.previous,"",true,true) == previous,"Persistent achievement failure does not leave practice or discard its previous run")
	check(scene.achievements._dirty and scene.achievement_save_failed and scene.achievements.pending_keys() == ["SD_FIRST_PLANT"],"Blocked recovery retains dirty earned key, offline queue and visible failure")
	record_achievement(label+"-blocked-recovery")
	var retry := named("Retry saving achievements")
	check(retry != null,"Achievement attention exposes a real UI retry action")
	if retry == null: return
	retry.grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.achievement_save_failed and scene.achievements._dirty and snapshot_files() == originals,"Retry during persistent failure leaves run and achievement originals unchanged")
	await press(JOY_BUTTON_B)
	check(named("Resume run") != null,"Blocked achievement attention always has controller Back escape")
	await open_saves_from_pause()
	await open_confirmation()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.run_save.resolutions == 0 and snapshot_files() == originals and scene.tutorial.active == practice,"Repeated recovery attempt remains non-destructive while achievement persistence fails")
	# Only the disposable I/O injector is repaired; retry still uses production UI.
	failing.fail_writes = false
	retry = named("Retry saving achievements")
	check(retry != null,"Retry remains reachable after the second blocked choice")
	if retry == null: return
	retry.grab_focus()
	await press(JOY_BUTTON_A)
	check(not scene.achievement_save_failed and not scene.achievements._dirty and scene.achievements.pending_keys() == ["SD_FIRST_PLANT"],"Actual UI retry persists earned evidence without falsely confirming Steam")
	var disk := Profile.new()
	check(disk.configure(path,"","").ok and disk.pending_keys() == ["SD_FIRST_PLANT"],"Retry makes the pending key durable before run recovery")
	disk.close()
	record_achievement(label+"-after-ui-retry")
	await press(JOY_BUTTON_B)
	await open_saves_from_pause()
	await open_confirmation()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.run.seed_value == 7330 and not scene.tutorial.active and scene.run_save.resolutions == 1,"Older run may be selected once after achievement persistence succeeds")
	check(not scene.run.achievement_stats.earned.has("SD_FIRST_PLANT") and scene.achievements.pending_keys() == ["SD_FIRST_PLANT"],"Lifetime achievement survives an older run that lacks its earned event")
	check(scene._save(),"Selected run saves normally after achievement repair")
	disk = Profile.new()
	check(disk.configure(path,"","").ok and disk.unlocked.has("SD_FIRST_PLANT") and disk.pending_keys() == ["SD_FIRST_PLANT"],"Fresh profile restart retains earned evidence and offline queue after older recovery")
	disk.close()
	record_achievement(label+"-after-successful-recovery")

func future_achievement_recovery() -> void:
	await make_scene(7441,true,false)
	var path: String = scene.achievements.store.file_path
	write_json(path,{"version":2,"account_id":"","unlocked":{},"confirmed":{}})
	scene.achievements.configure(path,"","")
	scene._observe_achievements()
	check(scene.achievements._blocked and not scene.achievements._dirty and scene.achievements.unlocked.is_empty(),"Future achievement schema is blocked without any dirty in-memory keys")
	await add_conflict(7440)
	var original_run := state()
	var originals := snapshot_files()
	await open_confirmation()
	named("Use this run").grab_focus()
	await press(JOY_BUTTON_A)
	check(scene.overlay.get_meta("achievements_panel",false),"Protected achievement schema routes to achievement attention before recovery")
	check(scene.run_save.resolutions == 0 and state() == original_run and snapshot_files() == originals,"Protected achievement file blocks run replacement even when no keys are dirty")
	var retry := named("Retry saving achievements")
	check(retry != null,"Protected achievement panel retains explicit retry and Back controls")
	if retry != null:
		retry.grab_focus()
		await press(JOY_BUTTON_A)
	check(scene.achievements._blocked and not scene.achievements._dirty and snapshot_files() == originals,"Retry cannot overwrite newer-format achievement evidence")
	await press(JOY_BUTTON_B)
	check(named("Resume run") != null,"Protected achievement panel has a usable controller escape")
	check(scene.run_save.resolutions == 0 and state() == original_run and snapshot_files() == originals,"Back leaves both run and future achievement file unchanged")
	record_achievement("future-schema-blocked-back")

func exercise() -> void:
	check("--no-steam" in OS.get_cmdline_user_args(),"Required isolated --no-steam launch")
	if not "--no-steam" in OS.get_cmdline_user_args(): quit(1); return
	root.size = Vector2i(1280,800)
	await cancel_and_blocking()
	await repeated_and_stale()
	await no_candidates()
	await practice_recovery()
	await practice_cancellation_and_stale()
	await practice_without_prior_run()
	await layout_checks()
	for empty_profile: bool in [false,true]:
		for practice: bool in [false,true]:
			await unsaved_achievement_recovery(empty_profile,practice)
	await future_achievement_recovery()
	var file := FileAccess.open("user://recovery-controller-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"achievement_timeline":achievement_timeline},"\t",true,true))
	file.close()
	for failure in failures: push_error(failure)
	print("RECOVERY_CONTROLLER_%s %d checks / %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	scene.queue_free()
	await frames(2)
	quit(0 if failures.is_empty() else 1)

func _initialize() -> void:
	Engine.max_fps = 120
	rendered = "--render-check" in OS.get_cmdline_user_args()
	variant = "canvas" if "--canvas-graphics" in OS.get_cmdline_user_args() else "native"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
	if rendered:
		if DisplayServer.get_name() == "headless": quit(1); return
		root.mode = Window.MODE_MINIMIZED
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
		RenderingServer.viewport_set_update_mode(root.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	call_deferred("exercise")
