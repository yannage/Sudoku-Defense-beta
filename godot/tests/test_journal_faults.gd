extends SceneTree
## Real journal calls with synthetic I/O interruptions; no Steam or player files.
const Save = preload("res://scripts/run_save.gd")
const Run = preload("res://scripts/run.gd")
var checks := 0
var failures := 0
var folder := ""

class FaultSave:
	extends "res://scripts/run_save.gd"
	var fault := ""
	var injected := false
	var foreign_suffix := ""
	var foreign_text := ""
	var read_calls := 0
	func _write_verified(path: String, text: String) -> bool:
		var kind := "backup" if path.ends_with("backup.tmp") or path.ends_with(".bak.tmp") else "snapshot"
		if fault == kind + "_open":
			injected = true
			return false
		if fault == kind + "_partial":
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string("{interrupted")
				file.close()
			injected = true
			return false
		var result := super._write_verified(path, text)
		if result and fault.begins_with(kind + "_external"):
			var file := FileAccess.open(file_path + foreign_suffix, FileAccess.WRITE)
			if file != null:
				file.store_string(foreign_text)
				file.close()
			injected = true
			return not fault.ends_with("_failed")
		if result and fault == kind + "_verified":
			injected = true
			return false
		return result
	func _read_valid(path: String) -> Dictionary:
		var kind := "backup" if path.ends_with("backup.tmp") or path.ends_with(".bak.tmp") else "snapshot"
		if fault == kind + "_verification" and path.ends_with(".tmp"):
			injected = true
			return {}
		var result := super._read_valid(path)
		if fault == "choices_external" and path == file_path + ".bak" and not injected:
			change_original()
		return result
	func _read_best() -> Dictionary:
		var result := super._read_best()
		if fault == "previous_external":
			read_calls += 1
			if read_calls == 2: change_original()
		return result
	func change_original() -> void:
		var file := FileAccess.open(file_path + foreign_suffix, FileAccess.WRITE)
		if file != null:
			file.store_string(foreign_text)
			file.close()
		injected = true
	func _replace(source: String, destination: String) -> bool:
		var stage := "primary_replace" if source.ends_with(".pending") else "backup_replace" if destination.ends_with(".bak") else "pending_publish"
		if fault == stage:
			injected = true
			return false
		var result := super._replace(source, destination)
		if result and fault.begins_with(stage + "_external"):
			var file := FileAccess.open(file_path + foreign_suffix, FileAccess.WRITE)
			if file != null:
				file.store_string(foreign_text)
				file.close()
			injected = true
			return not fault.ends_with("_failed")
		if result and fault == stage + "_after":
			injected = true
			return false
		return result
	func _replace_guarded(source: String, destination: String, expected_signature: String) -> bool:
		var result := super._replace_guarded(source, destination, expected_signature)
		var stage := "primary_replace" if source.ends_with(".pending") else "backup_replace" if destination.ends_with(".bak") else "pending_publish"
		if result and fault == stage + "_guard_external": change_original()
		return result

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fixture(seed_value: int) -> Dictionary:
	var run = Run.new()
	run.new_run(seed_value, {"mode": "campaign", "puzzle_difficulty": "easy", "combat_difficulty": "easy"})
	return run.save_data()

func write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Synthetic fixture can be written")
	if file != null:
		file.store_string(text)
		file.close()

func seed_of(store) -> int:
	var result: Dictionary = store.read_run()
	return int(result.data.state.seed_value) if not result.is_empty() else -1

func setup(name: String, staged: bool = false):
	var store = FaultSave.new()
	store.file_path = folder.path_join(name + "/cloud/run.json")
	DirAccess.make_dir_recursive_absolute(store.file_path.get_base_dir())
	if staged:
		store.staging_path = folder.path_join(name + "/local/staging/run")
		DirAccess.make_dir_recursive_absolute(store.staging_path)
	check(store.write_run(fixture(100)) and store.write_run(fixture(101)), name + " seeds two committed generations")
	return store

func fresh(store):
	var result = Save.new()
	result.file_path = store.file_path
	result.staging_path = store.staging_path
	return result

func saved_bytes(store) -> Dictionary:
	var result := {}
	for suffix: String in ["", ".pending", ".bak"]:
		if FileAccess.file_exists(store.file_path + suffix):
			result[suffix] = FileAccess.get_file_as_string(store.file_path + suffix)
	return result

func fault_matrix() -> void:
	var stages := ["snapshot_open", "snapshot_partial", "snapshot_verification", "snapshot_verified", "backup_open", "backup_partial", "backup_verification", "backup_verified", "backup_replace", "backup_replace_after", "pending_publish", "pending_publish_after", "primary_replace", "primary_replace_after"]
	for staged: bool in [false, true]:
		for stage: String in stages:
			for same_session: bool in [false, true]:
				var label := "%s-staged%s-retry%s" % [stage, staged, same_session]
				var store = setup(label, staged)
				var before := saved_bytes(store)
				store.fault = stage
				check(not store.write_run(fixture(102)) and store.injected, label + " interrupts the actual transaction")
				check(str(store.last_error.get("code", "")) == "io_error", label + " reports I/O failure")
				var committed := stage in ["pending_publish_after", "primary_replace", "primary_replace_after"]
				var restarted = fresh(store)
				check(seed_of(restarted) == (102 if committed else 101), label + " restart returns exactly the committed generation")
				if stage != "primary_replace_after":
					check(FileAccess.get_file_as_string(store.file_path) == before[""], label + " retains original primary before final promotion")
				var backup_changed := stage in ["backup_replace_after", "pending_publish", "pending_publish_after", "primary_replace", "primary_replace_after"]
				check(FileAccess.get_file_as_string(store.file_path + ".bak") == before["" if backup_changed else ".bak"], label + " last-good backup survives interruption")
				var recovered := restarted.read_run()
				store.fault = ""
				var retry = store if same_session else restarted
				check(retry.write_run(fixture(103)), label + " retry succeeds")
				check(seed_of(fresh(store)) == 103, label + " retry survives another restart")
				check(FileAccess.get_file_as_string(store.file_path + ".bak") == str(recovered.text), label + " retry backs up the committed generation")

func recovery_matrix() -> void:
	for stage: String in ["snapshot_open", "snapshot_partial", "snapshot_verification", "snapshot_verified", "pending_publish", "pending_publish_after", "primary_replace", "primary_replace_after"]:
		for corrupt_primary: bool in [false, true]:
			var label := "recovery-%s-corrupt%s" % [stage, corrupt_primary]
			var store = setup(label, true)
			# An unrelated valid journal requires an explicit choice. A damaged
			# primary must itself remain available in the recovery archive.
			var pending := fixture(102)
			pending["_journal"] = {"version": 1, "parent_sha256": "f".repeat(64)}
			write_text(store.file_path + ".pending", JSON.stringify(pending))
			if corrupt_primary: write_text(store.file_path, "{damaged-primary")
			var originals := saved_bytes(store)
			var selected: String = originals[".bak"]
			check(store.conflict_candidates().size() == (2 if corrupt_primary else 3), label + " offers all valid choices")
			store.fault = stage
			check(not store.resolve_candidate(selected.sha256_text()) and store.injected, label + " interrupts explicit recovery")
			check(str(store.last_error.get("code", "")) == "io_error", label + " reports I/O failure")
			for suffix: String in originals:
				check(FileAccess.get_file_as_string(store.last_archive_path.path_join("run.json" + suffix)) == originals[suffix], label + " archives exact original " + suffix)
			var published := stage in ["pending_publish_after", "primary_replace", "primary_replace_after"]
			var restarted = fresh(store)
			if published:
				check(seed_of(restarted) == 100, label + " chosen backup survives restart after commit")
			else:
				check(restarted.read_run().is_empty() and str(restarted.last_error.get("code", "")) == "sync_conflict", label + " unpublished recovery retains unresolved originals")
				check(saved_bytes(store) == originals, label + " unpublished failure preserves all original bytes")
			restarted.conflict_candidates()
			check(restarted.resolve_candidate(selected.sha256_text()), label + " refreshed choice retries successfully")
			check(seed_of(fresh(store)) == 100, label + " final choice persists")

func schema_and_backup() -> void:
	for suffix: String in ["", ".pending", ".bak"]:
		var store = setup("future-journal-" + str(checks), true)
		var future := fixture(104)
		future["_journal"] = {"version": 2, "parent_sha256": ""}
		write_text(store.file_path + suffix, JSON.stringify(future))
		var originals := saved_bytes(store)
		check(store.read_run().is_empty() and str(store.last_error.get("code", "")) == "newer_version", "Future journal schema blocks " + suffix)
		check(store.conflict_candidates().is_empty() and not store.write_run(fixture(105)), "Future journal cannot be overwritten or chosen away")
		check(saved_bytes(store) == originals, "Every committed future-journal original preserved")
	var corrupt = setup("all-corrupt", true)
	for suffix: String in ["", ".pending", ".bak"]: write_text(corrupt.file_path + suffix, "{corrupt" + suffix)
	var originals := saved_bytes(corrupt)
	check(corrupt.read_run().is_empty() and str(corrupt.last_error.get("code", "")) == "invalid_save", "No valid generation is explicitly blocked")
	check(not corrupt.write_run(fixture(106)) and corrupt.conflict_candidates().is_empty(), "All-corrupt evidence cannot be replaced by autosave")
	check(saved_bytes(corrupt) == originals, "All corrupt originals preserved")
	for stage: String in ["snapshot_open", "snapshot_partial", "snapshot_verification", "pending_publish", "pending_publish_after", "primary_replace", "primary_replace_after"]:
		var restored = setup("backup-restoration-" + stage, true)
		write_text(restored.file_path, "{broken-primary")
		var backup := FileAccess.get_file_as_string(restored.file_path + ".bak")
		check(seed_of(restored) == 100, stage + " loads backup before repair")
		restored.fault = stage
		check(not restored.write_run(fixture(107)) and restored.injected, stage + " repair interruption occurs")
		check(seed_of(fresh(restored)) == (107 if stage in ["pending_publish_after", "primary_replace", "primary_replace_after"] else 100), stage + " repair interruption preserves committed progress")
		check(FileAccess.get_file_as_string(restored.file_path + ".bak") == backup, stage + " corrupt primary never rotates into backup")

func concurrent_changes() -> void:
	for recovery: bool in [false, true]:
		for fault: String in ["snapshot_external", "snapshot_external_failed", "backup_external", "backup_external_failed", "backup_replace_external", "backup_replace_external_failed", "pending_publish_external", "pending_publish_external_failed", "primary_replace_external", "primary_replace_external_failed", "backup_replace_guard_external", "pending_publish_guard_external", "primary_replace_guard_external"]:
			if recovery and fault.begins_with("backup"): continue
			for suffix: String in ["", ".pending", ".bak"]:
				var label := "external-%s-recovery%s-%s" % [fault, recovery, str(checks)]
				var store = setup(label, true)
				store.foreign_suffix = suffix
				store.foreign_text = JSON.stringify(fixture(999))
				store.fault = fault
				var choices: Array = store.conflict_candidates() if recovery else []
				var result: bool = store.resolve_candidate(str(choices[0].hash)) if recovery else store.write_run(fixture(108))
				check(store.injected and not result, label + " refuses a transaction-time external change")
				check(str(store.last_error.get("code", "")) == "external_change", label + " identifies the conflict instead of a transient I/O failure")
				check(FileAccess.get_file_as_string(store.file_path + suffix) == store.foreign_text, label + " preserves changed original byte-for-byte")
				store.fault = ""
				check(not store.write_run(fixture(109)) and str(store.last_error.get("code", "")) in ["external_change", "sync_conflict"], label + " ordinary retry cannot adopt the external change silently")
				var refreshed := store.conflict_candidates()
				check(not refreshed.is_empty(), label + " offers explicit refreshed recovery")
				check(store.resolve_candidate(store.foreign_text.sha256_text()), label + " explicit current choice can preserve external progress")
				check(seed_of(fresh(store)) == 999, label + " chosen external progress survives restart")
	var previous = setup("previous-read-external", true)
	previous.foreign_text = JSON.stringify(fixture(999))
	previous.fault = "previous_external"
	check(not previous.write_run(fixture(108)) and previous.injected, "Change during previous-snapshot read blocks the transaction")
	check(str(previous.last_error.get("code", "")) == "external_change", "Read-boundary change is reported as external conflict")
	check(FileAccess.get_file_as_string(previous.file_path) == previous.foreign_text, "Read-boundary change remains byte-identical")
	previous.fault = ""
	check(not previous.write_run(fixture(109)), "Read-boundary conflict cannot be retried over newer progress")
	var choices = setup("choices-read-external", true)
	choices.foreign_text = JSON.stringify(fixture(999))
	choices.fault = "choices_external"
	check(choices.conflict_candidates().is_empty() and choices.injected, "Changed choices are not authenticated with a fresh signature")
	check(str(choices.last_error.get("code", "")) == "external_change", "Choice-read change reports explicit conflict")
	check(FileAccess.get_file_as_string(choices.file_path) == choices.foreign_text, "Choice enumeration preserves newer original")
	for existing: bool in [false, true]:
		var unobserved = FaultSave.new()
		unobserved.file_path = folder.path_join("unobserved-%s/run.json" % existing)
		DirAccess.make_dir_recursive_absolute(unobserved.file_path.get_base_dir())
		if existing: write_text(unobserved.file_path, JSON.stringify(fixture(100)))
		unobserved.foreign_text = JSON.stringify(fixture(999))
		unobserved.fault = "snapshot_external"
		check(not unobserved.write_run(fixture(108)) and unobserved.injected, "First write detects an external change without a prior load")
		check(str(unobserved.last_error.get("code", "")) == "external_change", "First-write conflict is reported")
		unobserved.fault = ""
		check(not unobserved.write_run(fixture(109)), "First-write conflict keeps its original baseline for retry")
		check(FileAccess.get_file_as_string(unobserved.file_path) == unobserved.foreign_text, "First-write retry preserves external original")
	var recovery_seed = setup("unobserved-recovery", true)
	var unobserved_recovery = FaultSave.new()
	unobserved_recovery.file_path = recovery_seed.file_path
	unobserved_recovery.staging_path = recovery_seed.staging_path
	unobserved_recovery.foreign_text = JSON.stringify(fixture(999))
	unobserved_recovery.fault = "snapshot_external"
	var recovery_choices := unobserved_recovery.conflict_candidates()
	check(not unobserved_recovery.resolve_candidate(str(recovery_choices[0].hash)) and unobserved_recovery.injected, "Fresh recovery detects external change without loading")
	unobserved_recovery.fault = ""
	check(not unobserved_recovery.write_run(fixture(109)), "Fresh recovery conflict retains the original baseline for ordinary retry")
	check(FileAccess.get_file_as_string(unobserved_recovery.file_path) == unobserved_recovery.foreign_text, "Fresh recovery retry preserves external original")

func preflight_conflicts() -> void:
	for entry: String in ["run", "merged", "enumeration"]:
		var initial = setup("fresh-preflight-" + entry, true)
		var store = FaultSave.new()
		store.file_path = initial.file_path
		store.staging_path = initial.staging_path
		store.foreign_text = JSON.stringify(fixture(999))
		if entry == "enumeration":
			store.fault = "choices_external"
			check(store.conflict_candidates().is_empty(), "Fresh enumeration refuses changed files")
		elif entry == "run":
			var choices := store.conflict_candidates()
			store.change_original()
			check(not store.resolve_candidate(str(choices[0].hash)), "Fresh run recovery refuses stale choices before transaction")
		else:
			var snapshot: Dictionary = store.recovery_snapshot()
			store.change_original()
			check(not store.resolve_merged(snapshot.candidates[0].data, str(snapshot.token)), "Fresh merged recovery refuses stale token before transaction")
		check(str(store.last_error.get("code", "")) == "external_change", entry + " preflight reports external change")
		store.fault = ""
		check(not store.write_run(fixture(109)), entry + " early recovery rejection cannot establish a newer retry baseline")
		check(FileAccess.get_file_as_string(store.file_path) == store.foreign_text, entry + " early recovery rejection preserves newer original")

func exercise() -> void:
	folder = "user://journal-faults-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create isolated fault test root")
	if not OS.get_cmdline_user_args().has("--journal-preflight-only"):
		fault_matrix()
		recovery_matrix()
		schema_and_backup()
		concurrent_changes()
	preflight_conflicts()
	print("JOURNAL_FAULTS_PASS %d checks / %d failures" % [checks, failures])
	print("JOURNAL_FAULTS_TEST_ROOT " + ProjectSettings.globalize_path(folder))
	quit(1 if failures else 0)
