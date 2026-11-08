extends SceneTree
## Keep these tests away from the player's settings and restore any prior run.

const Preferences = preload("res://scripts/preferences.gd")
const SETTINGS_PATH := "user://preferences-regression.json"
const RUN_PATH := "user://sudoku-defense-run.json"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func make_scene():
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.preferences.file_path = SETTINGS_PATH
	root.add_child(scene)
	return scene

func exercise() -> void:
	root.size = Vector2i(1280,800)
	var had_run := FileAccess.file_exists(RUN_PATH)
	var old_run: PackedByteArray = FileAccess.get_file_as_bytes(RUN_PATH) if had_run else PackedByteArray()
	DirAccess.remove_absolute(SETTINGS_PATH)
	DirAccess.remove_absolute(SETTINGS_PATH + ".tmp")
	var store = Preferences.new()
	store.file_path = SETTINGS_PATH
	check(store.read_settings() == Preferences.DEFAULTS,"Missing settings use safe defaults")
	write_text(SETTINGS_PATH,"{truncated settings")
	check(store.read_settings() == Preferences.DEFAULTS,"Malformed settings use defaults without breaking startup")
	write_text(SETTINGS_PATH,'{"muted":"false","reduced_motion":true,"board_notes":0,"unrelated":true}')
	var expected: Dictionary = Preferences.DEFAULTS.duplicate()
	expected.reduced_motion = true
	check(store.read_settings() == expected,"Legacy boolean options restore while new audio and auto-open choices default")
	write_text(SETTINGS_PATH,'{"master_volume":0.35,"music_volume":-1,"effects_volume":2,"muted":true}')
	check(store.read_settings().master_volume == 0.35 and store.read_settings().music_volume == 0.0 and store.read_settings().effects_volume == 1.0,"Numeric levels restore and clamp to safe bounds")
	check(store.validate({"master_volume":"0.2","music_volume":true,"effects_volume":NAN}) == Preferences.DEFAULTS,"Malformed and nonfinite volume values use defaults")
	write_text(SETTINGS_PATH,"[]")
	check(store.read_settings() == Preferences.DEFAULTS,"Wrong root type uses defaults")
	check(store.write_settings(Preferences.DEFAULTS),"Settings file can replace prior content")
	check(not FileAccess.file_exists(SETTINGS_PATH + ".tmp"),"Successful save leaves no temporary file")
	var scene = make_scene()
	await process_frame
	check(not scene.muted and not scene.reduced_motion and scene.board_notes and not scene.auto_open_chests,"First scene starts with documented defaults and opt-in automatic chests")
	scene.hud_nodes.mute.pressed.emit()
	check(scene.muted and scene.sound.muted,"Sound button immediately mutes playback")
	scene._help()
	var reduce: Button
	for control in scene.overlay.find_children("*","Button",true,false):
		if control.text.begins_with("Reduced motion:"): reduce = control
	check(is_instance_valid(reduce),"Help offers reduced-motion preference")
	if is_instance_valid(reduce): reduce.pressed.emit()
	check(scene.reduced_motion and scene.world.reduced_motion and scene.dock.reduced_motion,"Reduced motion reaches the board and loot presentation")
	scene.hud_nodes.notes.pressed.emit()
	check(not scene.board_notes and scene.hud_nodes.notes.text.ends_with("OFF"),"Notes button changes and displays its persistent state")
	expected = Preferences.DEFAULTS.duplicate()
	scene._toggle_auto_open_chests()
	check(scene.auto_open_chests,"Automatic chest opening can be enabled independently of a run")
	expected.merge({"muted":true,"reduced_motion":true,"board_notes":false,"auto_open_chests":true},true)
	check(store.read_settings() == expected,"All toggles are saved immediately before quit, preserving audio defaults")
	scene.queue_free()
	await process_frame
	scene = make_scene()
	await process_frame
	check(scene.muted and scene.sound.muted,"Fresh launch restores mute to sound playback")
	check(scene.auto_open_chests,"Fresh launch restores the player's automatic chest preference")
	check(scene.reduced_motion and scene.world.reduced_motion and scene.dock.reduced_motion,"Fresh launch applies reduced motion before interaction")
	check(not scene.board_notes and scene.hud_nodes.notes.text.ends_with("OFF"),"Fresh launch restores notes and its visible button label")
	for art in scene.overlay.find_children("*","Control",true,false):
		if art.get_script() == preload("res://scripts/menu_diorama.gd"):
			check(art.reduced_motion,"Launch menu art honors saved reduced motion")
	scene.seed_input.text = "12345"
	scene._start_run()
	check(scene.muted and scene.reduced_motion and not scene.board_notes and scene.auto_open_chests,"Starting a new run retains player preferences")
	check(scene.world.reduced_motion and scene.dock.reduced_motion,"Resetting the world retains reduced motion")
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.pressed = true
	scene._unhandled_input(event)
	check(not scene.muted and not scene.sound.muted and not store.read_settings().muted,"Keyboard mute shortcut saves through the same path")
	var run_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUN_PATH))
	check(run_file is Dictionary and not run_file.has("muted") and not run_file.has("reduced_motion") and not run_file.has("board_notes"),"Run save format remains independent of settings")
	scene.queue_free()
	await process_frame
	write_text(SETTINGS_PATH,"broken")
	scene = make_scene()
	await process_frame
	check(not scene.muted and not scene.reduced_motion and scene.board_notes,"Corrupt settings do not prevent a fresh game launch")
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(SETTINGS_PATH)
	DirAccess.remove_absolute(SETTINGS_PATH + ".tmp")
	if had_run:
		var restore := FileAccess.open(RUN_PATH,FileAccess.WRITE)
		restore.store_buffer(old_run)
		restore.close()
	else:
		DirAccess.remove_absolute(RUN_PATH)
	print("PREFERENCES_PASS %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
