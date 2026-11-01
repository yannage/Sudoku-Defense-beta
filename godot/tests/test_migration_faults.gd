extends SceneTree
## Migration boundaries are exercised with disposable files and synthetic IDs.
## No Steam adapter, real profile, native cursor, or browser is involved.

const Run = preload("res://scripts/run.gd")
const Save = preload("res://scripts/run_save.gd")
const Journal = preload("res://scripts/journal_store.gd")
const Profile = preload("res://scripts/cloud_profile.gd")
const Achievements = preload("res://scripts/achievement_profile.gd")
const ACCOUNT_A := "76561198000000001"
const ACCOUNT_B := "76561198000000002"
const FAULTS := [
	"reserve:snapshot_write", "reserve:snapshot_verify", "reserve:publish", "reserve:promote", "reserve:readback",
	"copy:snapshot_write", "copy:snapshot_verify", "copy:publish", "copy:promote", "copy:readback",
	"complete:snapshot_write", "complete:snapshot_verify", "complete:backup_write", "complete:backup_verify",
	"complete:backup_promote", "complete:publish", "complete:promote", "complete:readback"
]
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var folder := ""

class FaultJournal:
	extends "res://scripts/journal_store.gd"
	var domain := "claim"
	var fault := ""
	var transactions := 0
	var injected := false

	func stage() -> String:
		if domain != "claim": return "copy"
		return "reserve" if transactions == 1 else "complete"

	func hit(operation: String) -> bool:
		if injected or fault != stage() + ":" + operation: return false
		injected = true
		return true

	func _valid_data(data: Variant) -> bool:
		if domain == "run": return Save.new()._valid_data(data)
		if domain == "achievements": return Achievements.ProfileStore.new()._valid_data(data)
		return super._valid_data(data)

	func _write_transaction(data: Dictionary, expected_signature: String) -> bool:
		transactions += 1
		return super._write_transaction(data, expected_signature)

	func _write_verified(path: String, text: String) -> bool:
		var operation := "backup" if path.ends_with(".bak.tmp") or path.ends_with("/backup.tmp") else "snapshot"
		if hit(operation + "_write"):
			var partial := FileAccess.open(path, FileAccess.WRITE)
			if partial != null:
				partial.store_string(text.left(7))
				partial.close()
			return false
		var result := super._write_verified(path, text)
		if hit(operation + "_verify"):
			var damaged := FileAccess.open(path, FileAccess.WRITE)
			if damaged != null:
				damaged.store_string("{truncated")
				damaged.close()
			return false
		return result

	func _replace(source: String, destination: String) -> bool:
		var operation := "backup_promote" if destination.ends_with(".bak") else "publish" if destination.ends_with(".pending") else "promote"
		if hit(operation): return false
		return super._replace(source, destination)

	func read_data() -> Dictionary:
		if transactions > 0 and hit("readback"):
			last_error = {"code":"unreadable_save", "message":"Injected post-commit verification read failure"}
			return {}
		return super.read_data()

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func write_text(path: String, text: String) -> void:
	check(DirAccess.make_dir_recursive_absolute(path.get_base_dir()) == OK, "Create synthetic fixture directory")
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Open synthetic fixture")
	if file != null:
		file.store_string(text)
		file.close()

func fixture(kind: String) -> Dictionary:
	if kind == "achievements":
		return {"version":1, "account_id":"", "unlocked":{"SD_FIRST_PLANT":true,"SD_FIRST_UNIT":true}, "confirmed":{"SD_FIRST_PLANT":true}}
	var run = Run.new()
	run.new_run(7341, {"mode":"campaign", "puzzle_difficulty":"easy", "combat_difficulty":"easy", "achievement_run_id":"synthetic-migration-evidence"})
	var cell: int = run.board.find(0)
	check(run.place(cell,run.solution[cell]).ok, "Synthetic run earns its placement through gameplay")
	return run.save_data()

func plain_store(kind: String, path: String):
	var store = Save.new() if kind == "run" else Achievements.ProfileStore.new()
	store.file_path = path
	return store

func target_path(root_path: String, account: String, kind: String) -> String:
	return root_path.path_join("steam/" + account + "/cloud/" + kind + ".json")

func check_copy(kind: String, path: String, original: Dictionary, owner: String, label: String) -> void:
	var loaded: Dictionary = plain_store(kind,path).read_data()
	check(not loaded.is_empty(), label + " committed copy loads")
	if loaded.is_empty(): return
	check(loaded.data._steam_migration.owner == owner and loaded.data._steam_migration.kind == kind, label + " copy has intended owner and kind")
	if kind == "run":
		check(loaded.data.state == original.state and loaded.data.rng_state == original.rng_state, label + " run and achievement counters remain exact")
	else:
		check(loaded.data.account_id == owner and loaded.data.unlocked == original.unlocked and loaded.data.confirmed.is_empty(), label + " achievements preserve evidence and require account acknowledgement")

func migration_case(kind: String, fault: String, other_first: bool) -> void:
	var label := kind + " " + fault + (" B-first" if other_first else " A-restart")
	var before := failures.size()
	var root_path := folder.path_join("case-" + str(cases.size()))
	var text := JSON.stringify(fixture(kind))
	# JSON reads numbers as floats; compare the on-disk representation on both
	# sides rather than strict Variant dictionary equality against runtime ints.
	var original: Dictionary = JSON.parse_string(text)
	var legacy_path := root_path.path_join(Profile.LEGACY_RUN if kind == "run" else Profile.LOCAL_ACHIEVEMENTS)
	write_text(legacy_path, text)
	var destination := FaultJournal.new()
	destination.domain = kind
	destination.file_path = target_path(root_path,ACCOUNT_A,kind)
	destination.staging_path = root_path.path_join("steam/" + ACCOUNT_A + "/local/staging/" + kind)
	DirAccess.make_dir_recursive_absolute(destination.file_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(destination.staging_path)
	var claim := FaultJournal.new()
	claim.file_path = root_path.path_join(Profile.MIGRATION_CLAIM)
	if fault.begins_with("copy:"): destination.fault = fault
	else: claim.fault = fault
	var result: Dictionary = Profile.new()._migrate_file(kind,plain_store(kind,legacy_path),destination,claim,ACCOUNT_A)
	check(claim.injected or destination.injected, label + " reaches the intended failure boundary")
	check(not result.ok, label + " reports failure")
	check(FileAccess.get_file_as_string(legacy_path) == text, label + " preserves legacy bytes after failure")
	var claim_probe := Journal.new()
	claim_probe.file_path = claim.file_path
	var reserved: Dictionary = claim_probe.read_data()
	var has_reservation := not reserved.is_empty()
	check(has_reservation == not fault in ["reserve:snapshot_write","reserve:snapshot_verify","reserve:publish"], label + " ownership follows pending commit point")
	if has_reservation:
		check(reserved.data.owner == ACCOUNT_A, label + " durable reservation belongs to A")
	else:
		check(not destination.has_save(), label + " no account copy precedes durable ownership")
	if other_first:
		var switched: Dictionary = Profile.new().configure(ACCOUNT_B,root_path)
		check(switched.ok, label + " fresh account B startup succeeds")
		if has_reservation:
			check(not switched.migrated and not plain_store(kind,target_path(root_path,ACCOUNT_B,kind)).has_save(), label + " B receives none of reserved A evidence")
		else:
			check(switched.migrated, label + " first committed owner can legitimately be B")
			check_copy(kind,target_path(root_path,ACCOUNT_B,kind),original,ACCOUNT_B,label)
	var restarted: Dictionary = Profile.new().configure(ACCOUNT_A,root_path)
	check(restarted.ok, label + " fresh A restart succeeds")
	if other_first and not has_reservation:
		check(not restarted.migrated and not plain_store(kind,destination.file_path).has_save(), label + " A cannot copy progress subsequently claimed by B")
	else:
		check_copy(kind,destination.file_path,original,ACCOUNT_A,label)
		var finished: Dictionary = claim_probe.read_data()
		check(not finished.is_empty() and finished.data.sources.get(kind) == text.sha256_text(), label + " restart records exact completed source hash")
	check(FileAccess.get_file_as_string(legacy_path) == text, label + " all restarts preserve original bytes")
	cases.append({"case":label,"reserved_at_failure":has_reservation,"passed":failures.size() == before})

func claim_validation() -> void:
	var original := JSON.stringify(fixture("run"))
	for suffix: String in ["", ".pending", ".bak"]:
		for variant: String in ["future-domain", "future-journal", "invalid-owner", "invalid-source", "truncated"]:
			var label := variant + " claim " + suffix
			var root_path := folder.path_join("validation-" + str(checks))
			var legacy_path := root_path.path_join(Profile.LEGACY_RUN)
			var claim_path := root_path.path_join(Profile.MIGRATION_CLAIM) + suffix
			write_text(legacy_path,original)
			var data: Dictionary = {"version":1,"owner":ACCOUNT_A,"sources":{}}
			if variant == "future-domain": data.version = 2
			if variant == "future-journal": data._journal = {"version":2,"parent_sha256":""}
			if variant == "invalid-owner": data.owner = "../escape"
			if variant == "invalid-source": data.sources = {"run":"not-a-hash"}
			var text := "{truncated" if variant == "truncated" else JSON.stringify(data)
			write_text(claim_path,text)
			for owner: String in [ACCOUNT_A,ACCOUNT_B]:
				var result: Dictionary = Profile.new().configure(owner,root_path)
				check(not result.ok, label + " blocks migration for " + owner)
				check(not plain_store("run",target_path(root_path,owner,"run")).has_save(), label + " creates no account copy")
			check(FileAccess.get_file_as_string(claim_path) == text and FileAccess.get_file_as_string(legacy_path) == original, label + " preserves claim and legacy bytes")
	# A valid last-good reservation still prevents account B from adopting A's
	# legacy evidence after the primary claim is truncated.
	var restored := folder.path_join("claim-backup-restoration")
	write_text(restored.path_join(Profile.LEGACY_RUN),original)
	var reservation := JSON.stringify({"version":1,"owner":ACCOUNT_A,"sources":{}})
	write_text(restored.path_join(Profile.MIGRATION_CLAIM),"{truncated")
	write_text(restored.path_join(Profile.MIGRATION_CLAIM)+".bak",reservation)
	var other: Dictionary = Profile.new().configure(ACCOUNT_B,restored)
	check(other.ok and not other.migrated and not FileAccess.file_exists(other.run_path), "Recovered claim backup excludes B")
	var owner: Dictionary = Profile.new().configure(ACCOUNT_A,restored)
	check(owner.ok and owner.migrated, "Recovered claim backup allows A to finish")
	check(FileAccess.get_file_as_string(restored.path_join(Profile.LEGACY_RUN)) == original, "Claim backup recovery keeps original run")
	check(FileAccess.get_file_as_string(restored.path_join(Profile.MIGRATION_CLAIM)+".bak") == reservation, "Claim backup recovery preserves the last-good reservation")

func exercise() -> void:
	folder = "user://migration-faults-%s-%s" % [OS.get_process_id(),Time.get_ticks_usec()]
	for kind: String in ["run","achievements"]:
		for fault: String in FAULTS:
			for other_first: bool in [false,true]: migration_case(kind,fault,other_first)
	claim_validation()
	var evidence := FileAccess.open(folder.path_join("evidence.json"),FileAccess.WRITE)
	if evidence != null:
		evidence.store_string(JSON.stringify({"checks":checks,"failures":failures,"cases":cases},"\t"))
		evidence.close()
	for failure: String in failures: push_error(failure)
	print("MIGRATION_FAULTS_%s %d checks / %d failures; %d actual-boundary cases" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size(),cases.size()])
	print("MIGRATION_FAULTS_ROOT " + ProjectSettings.globalize_path(folder))
	quit(0 if failures.is_empty() else 1)
