extends SceneTree
## Only synthetic files in a unique, redirected test profile are accessed.

const Run = preload("res://scripts/run.gd")
const Save = preload("res://scripts/run_save.gd")
const Journal = preload("res://scripts/journal_store.gd")
const Profile = preload("res://scripts/cloud_profile.gd")
const Achievements = preload("res://scripts/achievement_profile.gd")
const ACCOUNT_A := "76561198000000001"
const ACCOUNT_B := "76561198000000002"
var checks := 0
var failures := 0
var folder := ""

class FailingPromotion:
	extends "res://scripts/run_save.gd"
	func _replace(source: String, destination: String) -> bool:
		if source.ends_with(".pending"): return false
		return super._replace(source, destination)

class UnreadableFile:
	extends "res://scripts/run_save.gd"
	var blocked_path := ""
	func _committed_file_issue(path: String) -> Dictionary:
		if path == blocked_path: return {"code": "unreadable_save", "message": "Injected inaccessible committed file"}
		return super._committed_file_issue(path)

class FailingCompletedClaim:
	extends "res://scripts/cloud_profile.gd"
	func _write_claim(claim, steam_id: String, sources: Dictionary) -> bool:
		if not sources.is_empty():
			claim.last_error = {"code": "io_error", "message": "Injected interruption after migration copy"}
			return false
		return super._write_claim(claim, steam_id, sources)

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
	check(file != null, "Synthetic fixture writable")
	if file != null:
		file.store_string(text)
		file.close()

func exercise() -> void:
	folder = "user://cloud-regression-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create isolated test directory")
	var profile := Profile.new()
	var local: Dictionary = profile.configure("", folder)
	check(local.ok and not local.scoped and local.run_path == folder.path_join(Profile.LEGACY_RUN), "Unavailable Steam retains ordinary local path without guessing prior identity")
	check(not profile.configure("../wrong", folder).ok, "Untrusted identity cannot escape profile directory")
	var old_text := JSON.stringify(fixture(1001))
	write_text(local.run_path, old_text)
	var local_awards := JSON.stringify({"version": 1, "account_id": "", "unlocked": {"SD_FIRST_PLANT": true}, "confirmed": {"SD_FIRST_PLANT": true}})
	write_text(local.achievement_path, local_awards)
	var configured: Dictionary = profile.configure(ACCOUNT_A, folder)
	check(configured.ok and configured.scoped and configured.migrated, "First account migrates validated legacy run")
	check(FileAccess.get_file_as_string(local.run_path) == old_text, "Legacy run remains byte-for-byte intact")
	check(str(configured.run_path).ends_with("steam/" + ACCOUNT_A + "/cloud/run.json"), "Run uses account-specific portable cloud path")
	check(str(configured.achievement_path).ends_with("/cloud/achievements.json"), "Achievement profile uses its own exact cloud file")
	var achievement_store = Achievements.ProfileStore.new()
	achievement_store.file_path = configured.achievement_path
	var achievements: Dictionary = achievement_store.read_data()
	check(achievements.data.account_id == ACCOUNT_A and achievements.data.unlocked.has("SD_FIRST_PLANT") and achievements.data.confirmed.is_empty(), "Local awards migrate to verified account and require fresh Steam acknowledgement")
	check(FileAccess.get_file_as_string(local.achievement_path) == local_awards, "Original local achievement profile remains byte-for-byte intact")
	check(str(configured.staging_root).contains("/local/"), "Uncommitted staging stays outside cloud")
	var store := Save.new()
	store.file_path = configured.run_path
	store.staging_path = str(configured.staging_root).path_join("run")
	check(int(store.read_run().data.state.seed_value) == 1001, "Migrated run loads exactly")
	check(store.write_run(fixture(1002)), "Account save uses verified journal")
	check(profile.configure(ACCOUNT_A, folder).ok, "Repeat startup preserves scoped run")
	check(int(store.read_run().data.state.seed_value) == 1002, "Legacy run cannot overwrite newer account run")
	var other: Dictionary = profile.configure(ACCOUNT_B, folder)
	check(other.ok and not other.migrated and not FileAccess.file_exists(other.run_path), "Switching account never imports already-claimed legacy progress")
	check(not FileAccess.file_exists(other.achievement_path), "Second Steam account never receives first account's local achievements")
	check(not local.run_path == other.run_path, "Offline legacy and second account are separate")
	# The checked-in Steam rules include exactly these six committed files.
	check(not FileAccess.file_exists(str(configured.run_path) + ".tmp"), "Successful staging never appears in cloud directory")
	# A valid committed pending snapshot must name the prior primary, even
	# when a cloud client or second process replaces only one file.
	var fail := FailingPromotion.new()
	fail.file_path = configured.run_path
	fail.staging_path = store.staging_path
	check(not fail.write_run(fixture(1003)), "Interrupted promotion reports failure")
	check(int(store.read_run().data.state.seed_value) == 1003, "Matching committed journal wins over its parent")
	var pending_text := FileAccess.get_file_as_string(str(configured.run_path) + ".pending")
	var foreign := Save.new()
	foreign.file_path = folder.path_join("foreign/run.json")
	DirAccess.make_dir_recursive_absolute(foreign.file_path.get_base_dir())
	check(foreign.write_run(fixture(9001)), "Second device fixture saves")
	var foreign_text := FileAccess.get_file_as_string(foreign.file_path)
	write_text(configured.run_path, foreign_text)
	check(store.read_run().is_empty() and store.last_error.code == "sync_conflict", "Unrelated cloud primary and stale journal block loading")
	check(not store.write_run(fixture(1004)) and store.last_error.code == "sync_conflict", "Conflict cannot be overwritten by autosave or New Run")
	check(FileAccess.get_file_as_string(configured.run_path) == foreign_text and FileAccess.get_file_as_string(str(configured.run_path) + ".pending") == pending_text, "Conflicting variants remain byte-identical")
	check(not profile.configure(ACCOUNT_A, folder).ok, "Profile exposes conflict for startup UI")
	var choices: Array[Dictionary] = store.conflict_candidates()
	check(choices.size() == 3 and choices[0].label == "Saved run" and choices[1].label == "Interrupted save", "Conflict choices identify every valid committed variant")
	var selected_hash := pending_text.sha256_text()
	write_text(configured.run_path, old_text)
	check(not store.resolve_candidate(selected_hash) and store.last_error.code == "external_change", "Choice refuses any intervening disk change")
	write_text(configured.run_path, foreign_text)
	store.conflict_candidates()
	check(store.resolve_candidate(selected_hash), "Explicit current choice publishes selected run")
	check(int(store.read_run().data.state.seed_value) == 1003, "Chosen interrupted save becomes current run")
	check(FileAccess.get_file_as_string(store.last_archive_path.path_join("run.json")) == foreign_text, "Unchosen primary preserved byte-for-byte outside cloud")
	check(FileAccess.get_file_as_string(store.last_archive_path.path_join("run.json.pending")) == pending_text, "Chosen original journal preserved byte-for-byte outside cloud")
	check(store.last_archive_path.contains("/local/conflicts/"), "Conflict archives are machine-local")
	check(not FileAccess.file_exists(str(configured.run_path) + ".pending"), "Resolved journal is fully promoted")
	# After an ordinary load, unexpected external change blocks an in-memory
	# session from replacing a newer downloaded save.
	check(not store.read_run().is_empty(), "Explicit fixture resolution restores readable primary")
	write_text(configured.run_path, old_text)
	check(not store.check_current() and store.last_error.code == "external_change", "New Run preflight checks without resetting observed save baseline")
	check(not store.write_run(fixture(1005)) and store.last_error.code == "external_change", "Changed file after load blocks stale-session overwrite")
	check(FileAccess.get_file_as_string(configured.run_path) == old_text, "External snapshot remains untouched")
	# A stale journal also cannot mask a later valid backup when the primary
	# was damaged or removed during a separate interrupted sync.
	var chain := Save.new()
	chain.file_path = folder.path_join("chain/run.json")
	DirAccess.make_dir_recursive_absolute(chain.file_path.get_base_dir())
	check(chain.write_run(fixture(7001)), "Adversarial chain A commits")
	check(chain.write_run(fixture(7002)), "Adversarial chain B commits")
	var stale_b := FileAccess.get_file_as_string(chain.file_path)
	check(chain.write_run(fixture(7003)) and chain.write_run(fixture(7004)), "Adversarial chain advances through C to D")
	var backup_c := FileAccess.get_file_as_string(chain.file_path + ".bak")
	write_text(chain.file_path + ".pending", stale_b)
	write_text(chain.file_path, "{corrupt")
	check(chain.read_run().is_empty() and chain.last_error.code == "sync_conflict", "Stale B journal cannot mask newer C backup behind corrupt primary")
	check(not chain.write_run(fixture(7005)) and FileAccess.get_file_as_string(chain.file_path + ".bak") == backup_c, "Stale journal cannot overwrite newer backup during next save")
	DirAccess.remove_absolute(chain.file_path)
	check(chain.read_run().is_empty() and chain.last_error.code == "sync_conflict", "Missing primary also compares journal parent against backup")
	var chain_choices := chain.conflict_candidates()
	check(chain_choices.size() == 2, "Conflict exposes both valid journal and newer backup")
	check(chain.resolve_candidate(backup_c.sha256_text()), "Explicit backup selection resolves the damaged-primary conflict")
	check(int(chain.read_run().data.state.seed_value) == 7003, "Selected newer backup restores C")
	# Unsupported committed versions are never treated as corruption and
	# replaced with a compatible but older backup.
	for suffix in ["", ".pending", ".bak"]:
		var isolated := folder.path_join("future" + str(checks))
		DirAccess.make_dir_recursive_absolute(isolated)
		var future_store := Save.new()
		future_store.file_path = isolated.path_join("run.json")
		write_text(future_store.file_path, old_text)
		var future := fixture(2001)
		future.version = 2
		var future_text := JSON.stringify(future)
		write_text(future_store.file_path + suffix, future_text)
		check(future_store.read_run().is_empty() and future_store.last_error.code == "newer_version", "Future schema in committed " + suffix + " blocks rollback")
		check(future_store.conflict_candidates().is_empty(), "Future schema cannot be discarded through old-version recovery choices")
		check(not future_store.write_run(fixture(2002)), "Future schema cannot be replaced")
		check(FileAccess.get_file_as_string(future_store.file_path + suffix) == future_text, "Future schema bytes preserved")
	# Size limits cannot turn an unknown/newer committed file into corruption
	# and silently roll it back. One bounded >8 MiB fixture is removed each pass.
	var oversized_text := '{"version":2,"padding":"' + " ".repeat(Journal.MAX_BYTES) + '"}'
	for suffix: String in ["", ".pending", ".bak"]:
		var oversized := Save.new()
		oversized.file_path = folder.path_join("oversized-" + str(checks) + "/run.json")
		write_text(oversized.file_path, old_text)
		write_text(oversized.file_path + ".bak", old_text)
		write_text(oversized.file_path + suffix, oversized_text)
		check(oversized.read_run().is_empty() and oversized.last_error.code == "oversized_save", "Oversized committed " + suffix + " blocks unknown-schema fallback")
		check(not oversized.write_run(fixture(3001)) and oversized.conflict_candidates().is_empty(), "Oversized unknown data cannot be discarded by save or recovery")
		var large_file := FileAccess.open(oversized.file_path + suffix, FileAccess.READ)
		check(large_file != null and large_file.get_length() == oversized_text.length(), "Oversized original remains intact")
		large_file.close()
		DirAccess.remove_absolute(oversized.file_path + suffix)
		var denied := UnreadableFile.new()
		denied.file_path = folder.path_join("unreadable-" + str(checks) + "/run.json")
		write_text(denied.file_path, old_text)
		write_text(denied.file_path + suffix, old_text)
		denied.blocked_path = denied.file_path + suffix
		check(denied.read_run().is_empty() and denied.last_error.code == "unreadable_save", "Unreadable committed " + suffix + " blocks fallback")
		check(not denied.write_run(fixture(3002)) and denied.conflict_candidates().is_empty(), "Unreadable original cannot be overwritten or chosen away")
		check(FileAccess.get_file_as_string(denied.blocked_path) == old_text, "Unreadable fixture preserves original bytes")
	# Broken primary recovers a same-version backup on another synthetic device.
	var recovery_root := folder.path_join("recovery")
	write_text(recovery_root.path_join(Profile.LEGACY_RUN), "{truncated")
	write_text(recovery_root.path_join(Profile.LEGACY_RUN) + ".bak", old_text)
	var recovered: Dictionary = profile.configure(ACCOUNT_A, recovery_root)
	check(recovered.ok and recovered.migrated, "Migration can recover last-good legacy backup")
	check(FileAccess.get_file_as_string(recovery_root.path_join(Profile.LEGACY_RUN)) == "{truncated", "Recovery migration preserves damaged source for inspection")
	# Simulate interruption between committed migration and local claim.
	var interrupted_root := folder.path_join("migration-interrupted")
	write_text(interrupted_root.path_join(Profile.LEGACY_RUN), old_text)
	var first: Dictionary = profile.configure(ACCOUNT_A, interrupted_root)
	check(first.ok, "Migration setup commits")
	DirAccess.remove_absolute(interrupted_root.path_join(Profile.MIGRATION_CLAIM))
	check(profile.configure(ACCOUNT_A, interrupted_root).ok, "Restart finishes migration claim from verified committed target")
	check(not profile.configure(ACCOUNT_B, interrupted_root).migrated, "Interrupted migration cannot duplicate legacy into another account")
	var failed_claim_root := folder.path_join("migration-claim-failure")
	write_text(failed_claim_root.path_join(Profile.LEGACY_RUN), old_text)
	DirAccess.make_dir_absolute(failed_claim_root.path_join(Profile.MIGRATION_CLAIM) + ".tmp")
	var failed_claim: Dictionary = profile.configure(ACCOUNT_A, failed_claim_root)
	check(not failed_claim.ok and not FileAccess.file_exists(failed_claim.run_path), "Ownership reservation failure blocks copying before account progress commits")
	check(FileAccess.get_file_as_string(failed_claim_root.path_join(Profile.LEGACY_RUN)) == old_text, "Failed claim never changes original run")
	DirAccess.remove_absolute(failed_claim_root.path_join(Profile.MIGRATION_CLAIM) + ".tmp")
	check(profile.configure(ACCOUNT_A, failed_claim_root).ok, "Retry reserves ownership and finishes migration after claim storage recovers")
	var failed_copy_root := folder.path_join("migration-copy-failure")
	write_text(failed_copy_root.path_join(Profile.LEGACY_RUN), old_text)
	var blocked_stage := failed_copy_root.path_join("steam/" + ACCOUNT_A + "/local/staging/run/snapshot.tmp")
	DirAccess.make_dir_recursive_absolute(blocked_stage)
	var failed_copy: Dictionary = profile.configure(ACCOUNT_A, failed_copy_root)
	check(not failed_copy.ok and not FileAccess.file_exists(failed_copy.run_path), "Copy failure leaves no committed account run")
	var reserved_claim: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(failed_copy_root.path_join(Profile.MIGRATION_CLAIM)))
	check(reserved_claim.owner == ACCOUNT_A and reserved_claim.sources.is_empty(), "Ownership reservation survives interrupted copy without marking a source complete")
	check(not profile.configure(ACCOUNT_B, failed_copy_root).migrated, "Another account cannot take over a reserved migration")
	DirAccess.remove_absolute(blocked_stage)
	var retried_copy: Dictionary = profile.configure(ACCOUNT_A, failed_copy_root)
	check(retried_copy.ok and retried_copy.migrated, "Reserved owner retries and completes the previously failed copy")
	# A different account can be the first launch after a crash. Ownership must
	# already be durable when the copy commits, even before completion is logged.
	for kind: String in ["run", "achievements"]:
		var switched_root := folder.path_join("migration-switch-after-copy-" + kind)
		var legacy_name := Profile.LEGACY_RUN if kind == "run" else Profile.LOCAL_ACHIEVEMENTS
		var original_text := old_text if kind == "run" else local_awards
		write_text(switched_root.path_join(legacy_name), original_text)
		var interrupted = FailingCompletedClaim.new()
		var incomplete: Dictionary = interrupted.configure(ACCOUNT_A, switched_root)
		var copied_path: String = incomplete.run_path if kind == "run" else incomplete.achievement_path
		check(not incomplete.ok and FileAccess.file_exists(copied_path), kind + " copy commits before injected completion failure")
		var copied_text := FileAccess.get_file_as_string(copied_path)
		var switched: Dictionary = profile.configure(ACCOUNT_B, switched_root)
		var other_path: String = switched.run_path if kind == "run" else switched.achievement_path
		check(switched.ok and not switched.migrated and not FileAccess.file_exists(other_path), "Account switch after interrupted " + kind + " migration cannot import the first account's legacy progress")
		check(FileAccess.get_file_as_string(copied_path) == copied_text and FileAccess.get_file_as_string(switched_root.path_join(legacy_name)) == original_text, "Interrupted " + kind + " migration preserves original and committed copy")
		check(profile.configure(ACCOUNT_A, switched_root).ok, "Original account can complete interrupted " + kind + " claim")
	print("CLOUD_PROFILE_PASS %d checks / %d failures" % [checks, failures])
	print("CLOUD_PROFILE_TEST_ROOT " + ProjectSettings.globalize_path(folder))
	quit(1 if failures else 0)
