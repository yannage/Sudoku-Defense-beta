extends SceneTree
## Uses a unique directory and injects scene stores before _ready. Never opens
## the player's run/settings files, even outside the build helper.

const Run = preload("res://scripts/run.gd")
const Save = preload("res://scripts/run_save.gd")
var checks := 0
var failures := 0
var folder: String
var path: String

class FailingPromotion:
	extends "res://scripts/run_save.gd"
	var fail_suffix := ""
	func _replace(source: String, destination: String) -> bool:
		if not fail_suffix.is_empty() and source.ends_with(fail_suffix): return false
		return super._replace(source, destination)

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func write_text(target: String, value: String) -> void:
	var file := FileAccess.open(target, FileAccess.WRITE)
	check(file != null, "Fixture can write " + target)
	if file == null: return
	file.store_string(value)
	file.close()

func clear_snapshots() -> void:
	for suffix in ["", ".tmp", ".pending", ".bak", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)

func seed_of(store) -> int:
	var saved: Dictionary = store.read_run()
	return int(saved.data.state.seed_value) if not saved.is_empty() else -1

func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in range(a.size()):
			if not equivalent(a[index], b[index]): return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return a == b

func exercise() -> void:
	folder = "user://save-regression-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create isolated test directory")
	path = folder + "/run.json"
	var store = Save.new()
	store.file_path = path
	var first = Run.new()
	first.new_run(4501, {"mode": "campaign", "puzzle_difficulty": "easy", "combat_difficulty": "easy"})
	var second = Run.new()
	second.new_run(4502, {"mode": "campaign", "puzzle_difficulty": "easy", "combat_difficulty": "easy"})
	var old_text := JSON.stringify(first.save_data())
	var new_text := JSON.stringify(second.save_data())
	check(not store.has_save() and store.read_run().is_empty(), "Missing save is a normal fresh start")
	write_text(path, old_text)
	check(seed_of(store) == 4501 and not store.read_run().recovered, "Existing version-1 save loads without migration")
	check(store.write_run(second.save_data()), "Verified transaction replaces a legacy file")
	check(seed_of(store) == 4502, "Latest snapshot loads after replacement")
	check(FileAccess.get_file_as_string(path + ".bak") == old_text, "Last-good backup preserves the complete previous snapshot")
	check(not FileAccess.file_exists(path + ".pending") and not FileAccess.file_exists(path + ".tmp"), "Successful save consumes journal and staging file")
	for index in range(8):
		second.credits += 1
		var before := FileAccess.get_file_as_string(path)
		check(store.write_run(second.save_data()), "Repeated save %d succeeds" % index)
		check(FileAccess.get_file_as_string(path + ".bak") == before, "Repeated save retains immediately previous state")
	write_text(path, "{truncated")
	check(seed_of(store) == 4502 and store.read_run().recovered, "Truncated primary falls back to last-good backup")
	var kept_backup := FileAccess.get_file_as_string(path + ".bak")
	check(store.write_run(first.save_data()), "Saving after recovery repairs the primary")
	check(FileAccess.get_file_as_string(path + ".bak") == kept_backup, "Repair never rotates corrupt primary over the backup")
	var damaged: Dictionary = first.save_data()
	damaged.state.erase("timer")
	write_text(path, JSON.stringify(damaged))
	check(store.read_run().recovered, "Complete JSON with incomplete state also falls back")
	for field in ["items", "chests", "active_effects", "passives", "enemies"]:
		damaged = first.save_data()
		damaged.state[field] = {} if field == "passives" else ([{"pos": [0, 0]}] if field == "enemies" else [{}])
		write_text(path, JSON.stringify(damaged))
		check(store.read_run().recovered, "Malformed nested %s falls back before gameplay can access it" % field)
		check(not store.write_run(damaged), "Malformed %s cannot be persisted over a known-good save" % field)
	# Staging is uncommitted; the published journal must win even when the
	# primary still exists. Enumerate interruption boundaries on real files.
	for stage in ["partial_temp", "verified_temp", "backup_temp", "backup_published", "journal_published", "primary_removed"]:
		clear_snapshots()
		write_text(path, old_text)
		write_text(path + ".tmp", "{partial" if stage == "partial_temp" else new_text)
		if stage == "backup_temp": write_text(path + ".bak.tmp", old_text)
		if stage in ["backup_published", "journal_published", "primary_removed"]: write_text(path + ".bak", old_text)
		if stage in ["journal_published", "primary_removed"]:
			check(DirAccess.rename_absolute(path + ".tmp", path + ".pending") == OK, "Publish fixture journal")
		if stage == "primary_removed": DirAccess.remove_absolute(path)
		var committed: bool = stage in ["journal_published", "primary_removed"]
		check(seed_of(store) == (4502 if committed else 4501), "Interruption at %s restores exactly the committed snapshot" % stage)
		check(store.write_run(first.save_data()), "A new save completes after interruption at " + stage)
		check(seed_of(store) == 4501, "Interrupted transaction does not mask a subsequent save")
	clear_snapshots()
	write_text(path + ".pending", new_text)
	check(store.has_save() and seed_of(store) == 4502, "First save interrupted after commit is discoverable without primary")
	write_text(path, old_text)
	write_text(path + ".pending", "broken")
	check(seed_of(store) == 4501, "Malformed journal never masks valid primary")
	# Actual failed I/O and injected rename failures preserve recoverable data.
	clear_snapshots()
	write_text(path, old_text)
	check(DirAccess.make_dir_absolute(path + ".tmp") == OK, "Create unwritable staging fixture")
	check(not store.write_run(second.save_data()), "Staging open failure is reported")
	check(seed_of(store) == 4501, "Staging failure preserves prior run")
	DirAccess.remove_absolute(path + ".tmp")
	var broken = FailingPromotion.new()
	broken.file_path = path
	for suffix in [".bak.tmp", ".tmp", ".pending"]:
		clear_snapshots()
		write_text(path, old_text)
		broken.read_run() # Each injected disk fixture is a fresh loaded session.
		broken.fail_suffix = suffix
		check(not broken.write_run(second.save_data()), "Rename failure at %s is reported" % suffix)
		check(seed_of(store) == (4502 if suffix == ".pending" else 4501), "Rename failure leaves the correct committed run recoverable")
		broken.fail_suffix = ""
		check(broken.write_run(first.save_data()), "Retry succeeds after rename failure")
	# Mid-battle replay keeps RNG, ownership, enemy and timer state intact.
	clear_snapshots()
	store.read_run() # Adopt the explicitly cleared fixture before starting it.
	for cell in range(81):
		if first.board[cell] == 0: first.place(cell, first.solution[cell])
		if first.towers.size() == 8: break
	first.equip_item(int(first.towers.keys()[0]), first.items[0].id)
	first.advance_phase()
	first.advance_phase()
	first.update(2.5)
	check(store.write_run(first.save_data()), "Mid-battle run passes write validation")
	var resumed = Run.new()
	check(resumed.load_data(store.read_run().data), "Committed battle restores")
	for index in range(30):
		first.update(0.1)
		resumed.update(0.1)
	check(first.rng.state == resumed.rng.state, "Recovered battle preserves exact RNG state")
	check(equivalent(first.save_data(), resumed.save_data()), "Recovered battle continues deterministically without duplicate rewards")
	# Scene feedback persists across action toasts and a failed close request.
	root.size = Vector2i(1280, 800)
	var scene = load("res://scenes/main.tscn").instantiate()
	scene.run_save.file_path = folder + "/missing/run.json"
	# Platform profile setup may create the parent; block the actual staging
	# file so this still tests a real write failure independently of setup.
	DirAccess.make_dir_recursive_absolute(scene.run_save.file_path + ".tmp")
	scene.preferences.file_path = folder + "/settings.json"
	root.add_child(scene)
	await process_frame
	scene.seed_input.text = "4503"
	scene._start_run()
	check(scene.save_failed and scene.notice.visible, "Save failure is visible when starting a run")
	scene._toast("ordinary action")
	check(scene.notice.text == "ordinary action" and scene.hud_nodes.menu.text == "Save!", "Save indicator persists without suppressing gameplay feedback")
	scene.notice.hide()
	scene._update_context_visibility()
	check(scene.selected_label.visible and scene.candidate_label.visible, "Unsaved state does not permanently hide Sudoku context")
	scene._show_pause_menu()
	var retry: Button
	for control in scene.overlay.find_children("*", "Button", true, false):
		if control.text == "Retry saving": retry = control
	check(is_instance_valid(retry), "Pause menu offers a controller-focusable save retry")
	scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(scene.overlay.get_meta("unsaved_quit", false), "Failed close opens explicit save/keep playing/quit choice")
	scene.tutorial.start(scene)
	check(scene.tutorial.active, "Practice can open while the real run has unsaved progress")
	scene._retry_save_from_menu()
	check(not scene.tutorial.active and scene.run.seed_value == 4503 and scene.save_failed, "Explicit retry returns from practice and attempts the real run save")
	scene.tutorial.start(scene)
	scene._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(not scene.tutorial.active and scene.run.seed_value == 4503, "Closing practice restores the real run before saving")
	check(scene.overlay.get_meta("unsaved_quit", false) and scene.save_failed, "Practice cannot bypass a real run's failed-save close warning")
	scene.run_save.file_path = path
	check(scene._save() and not scene.save_failed, "Successful retry clears failure status")
	check(scene.notice.text.contains("Progress saved"), "Successful retry confirms saved progress")
	write_text(path, "broken")
	check(scene._load() and scene.save_recovered, "Scene reports fallback recovery to the continue flow")
	scene.queue_free()
	await process_frame
	clear_snapshots()
	if FileAccess.file_exists(folder + "/settings.json"): DirAccess.remove_absolute(folder + "/settings.json")
	DirAccess.remove_absolute(folder)
	print("RUN_SAVE_PASS %d checks / %d failures" % [checks, failures])
	quit(1 if failures else 0)
