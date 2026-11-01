extends SceneTree
## No Steam initialization: every platform call below targets this test mock.
## All files live in a unique user:// test directory, never a player's profile.

const Profile = preload("res://scripts/achievement_profile.gd")
var checks := 0
var failures := 0
var folder := ""
var sequence := 0

class Evidence:
	extends RefCounted
	var achievement_stats := {"run_id": "", "earned": {}}

class FakePlatform:
	extends RefCounted
	signal stats_stored(success: bool)
	var available := true
	var ready := true
	var account_id := "76561198000000001"
	var app_id := 3721150
	var known := true
	var set_ok := true
	var store_ok := true
	var pending := false
	var sets: Array[String] = []
	var stores := 0
	var queries := 0
	var server: Dictionary = {}
	var client: Dictionary = {}
	var on_set: Callable
	func get_status() -> Dictionary:
		return {"available": available, "ready": ready, "account_id": account_id, "app_id": app_id, "store_pending": pending}
	func query_achievement(key: String) -> Dictionary:
		queries += 1
		return {"known": known, "achieved": client.has(key) or server.has(key)}
	func set_achievement(key: String) -> bool:
		if on_set.is_valid(): on_set.call(key)
		if not set_ok: return false
		sets.append(key)
		client[key] = true
		return true
	func store_achievements() -> bool:
		stores += 1
		pending = store_ok
		return store_ok
	func finish(success: bool) -> void:
		pending = false
		if success: server.merge(client, true)
		stats_stored.emit(success)

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func write_json(path: String, data: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Test fixture opens " + path)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()

func fresh(account: String = "76561198000000001"):
	sequence += 1
	var root_path := folder.path_join(str(sequence))
	check(DirAccess.make_dir_recursive_absolute(root_path.path_join("staging")) == OK, "Create isolated profile directory")
	var profile = Profile.new()
	check(profile.configure(root_path.path_join("achievements.json"), root_path.path_join("staging"), account).ok, "Fresh profile opens")
	return profile

func evidence(keys: Array, run_id: String = "real-run-1"):
	var run = Evidence.new()
	run.achievement_stats.run_id = run_id
	for key: String in keys: run.achievement_stats.earned[key] = true
	return run

func exercise() -> void:
	folder = "user://achievement-profile-tests-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "Create test root")
	var profile = fresh()
	check(profile.entries().size() == 26 and profile.get_status().total_count == 26, "All26 catalog entries are available to UI")
	check(profile.observe_run(evidence(["SD_FIRST_PLANT"], "")), "Practice/test empty-ID evidence is harmless")
	check(profile.get_status().unlocked_count == 0 and not profile.store.has_save(), "Empty-ID evidence never writes unlocks")
	# Each manager-facing key is durable, duplicate-safe, and survives a new
	# instance. The separate rules suite validates actual gameplay conditions.
	var expected := 0
	for entry: Dictionary in profile.entries():
		var key: String = str(entry.id)
		check(profile.observe_run(evidence([key])), key + " persists before publishing")
		expected += 1
		check(profile.get_status().unlocked_count == expected, key + " counted once")
		var old_text := FileAccess.get_file_as_string(profile.store.file_path)
		check(profile.observe_run(evidence([key, key])), key + " duplicate accepted")
		check(FileAccess.get_file_as_string(profile.store.file_path) == old_text, key + " duplicate causes no write")
		var resumed = Profile.new()
		check(resumed.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001").ok, key + " reload succeeds")
		check(resumed.unlocked.has(key) and resumed.get_status().unlocked_count == expected, key + " reload preserves all earlier unlocks")
		profile = resumed
	check(profile.pending_keys().size() == 26, "All offline unlocks wait for Steam")
	var steam = FakePlatform.new()
	steam.available = false
	check(not profile.synchronize(steam) and steam.sets.is_empty() and steam.stores == 0, "Offline service never discards or sends queue")
	steam.available = true
	steam.on_set = func(key: String):
		var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.store.file_path))
		check(disk.unlocked.has(key), "Every Steam SetAchievement has durable prior evidence")
	check(profile.synchronize(steam), "Reconnected account submits offline batch")
	check(steam.sets.size() == 26 and steam.stores == 1, "All earned keys submit in one StoreStats batch")
	check(profile.pending_keys().size() == 26 and profile.get_status().store_pending, "Submission alone never acknowledges queue")
	check(not profile.synchronize(steam) and steam.stores == 1, "Duplicate sync cannot create concurrent batch")
	steam.finish(false)
	check(profile.pending_keys().size() == 26 and not profile.get_status().store_pending, "Failed asynchronous store preserves entire queue")
	profile.pump(15.0)
	check(steam.stores == 2 and profile.pending_keys().size() == 26, "Client cached SetAchievement flags cannot falsely acknowledge failed StoreStats")
	steam.finish(true)
	check(profile.pending_keys().is_empty() and profile.confirmed.size() == 26, "Success callback acknowledges exact submitted batch")
	var restored = Profile.new()
	check(restored.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001").ok and restored.pending_keys().is_empty(), "Steam acknowledgement persists across launch")
	check(restored.synchronize(steam) and steam.stores == 2, "Already unlocked Steam keys are idempotent")
	# New evidence while a batch is in flight cannot be acknowledged by that
	# earlier callback. It gets its own durable, subsequent batch.
	profile = fresh()
	steam = FakePlatform.new()
	profile.observe_run(evidence(["SD_FIRST_PLANT"]))
	profile.synchronize(steam)
	profile.observe_run(evidence(["SD_FIRST_MODULE"]))
	steam.finish(true)
	check(profile.confirmed.has("SD_FIRST_PLANT") and not profile.confirmed.has("SD_FIRST_MODULE"), "Only in-flight snapshot keys acknowledge")
	profile.pump(3.0)
	check(steam.stores == 2 and profile.get_status().store_pending, "Later unlock waits for and then submits a second batch")
	steam.finish(true)
	check(profile.pending_keys().is_empty(), "Second batch completes normally")
	for failure_kind in ["set", "store"]:
		profile = fresh()
		steam = FakePlatform.new()
		profile.observe_run(evidence(["SD_FIRST_UPGRADE"]))
		steam.set_ok = failure_kind != "set"
		steam.store_ok = failure_kind != "store"
		check(not profile.synchronize(steam), "Immediate " + failure_kind + " failure is reported")
		check(profile.pending_keys().size() == 1 and not profile.get_status().store_pending, "Immediate " + failure_kind + " failure retains durable pending key")
		steam.set_ok = true
		steam.store_ok = true
		profile.pump(15.0)
		check(profile.get_status().store_pending and profile.confirmed.is_empty(), failure_kind + " retry waits for callback, even with cached Steam flag")
		steam.finish(true)
		check(profile.pending_keys().is_empty(), failure_kind + " retry eventually succeeds")
	# A bounded timeout retries idempotently. Late unrelated callbacks cannot
	# acknowledge anything when there is no in-flight batch.
	profile = fresh()
	steam = FakePlatform.new()
	profile.observe_run(evidence(["SD_FIRST_CLEAR"]))
	profile.synchronize(steam)
	profile.pump(46.0)
	check(not profile.get_status().store_pending and profile.pending_keys().size() == 1, "Missing callback times out without losing evidence")
	steam.finish(true)
	check(profile.pending_keys().size() == 1, "Late callback after timeout does not acknowledge unrelated state")
	profile.pump(15.0)
	check(steam.stores == 2, "Timeout retries through standard idempotent Steam APIs")
	steam.finish(true)
	check(profile.pending_keys().is_empty(), "Timeout recovery eventually acknowledges")
	# Steam is an additional durable source. Union it into the same account's
	# local progress, but never infer an unlock for another identity.
	profile = fresh()
	steam = FakePlatform.new()
	steam.server["SD_FIRST_BOSS"] = true
	check(profile.synchronize(steam), "Remote existing achievement can reconcile")
	check(profile.unlocked.has("SD_FIRST_BOSS") and profile.confirmed.has("SD_FIRST_BOSS"), "Remote union persists known unlock locally")
	profile.pump(15.0)
	steam.server.clear()
	profile.pump(15.0)
	check(profile.pending_keys().size() == 1 and steam.stores == 1, "Locally earned evidence requeues if current Steam state lacks it")
	steam.finish(true)
	profile = fresh()
	steam = FakePlatform.new()
	profile.observe_run(evidence(["SD_FIRST_PLANT"]))
	steam.known = false
	check(not profile.synchronize(steam) and steam.sets.is_empty(), "Missing platform definitions never trigger blind writes")
	steam.known = true
	profile.pump(3.0)
	check(steam.stores == 1, "Definition availability recovery preserves pending award")
	steam.account_id = "76561198000000002"
	steam.finish(true)
	check(profile.confirmed.is_empty() and profile.pending_keys().size() == 1, "Account change cannot acknowledge previous account's queue")
	profile.pump(30.0)
	check(steam.stores == 1, "Wrong account is never awarded")
	var local = fresh("")
	local.observe_run(evidence(["SD_FIRST_PLANT"]))
	check(not local.synchronize(FakePlatform.new()), "Unscoped local progress is not silently awarded to a Steam account")
	steam = FakePlatform.new()
	steam.app_id = 480
	check(not profile.synchronize(steam) and steam.sets.is_empty(), "Wrong Steam app never receives achievements")
	# Account ownership and future schemas fail closed without overwriting.
	var own_path: String = profile.store.file_path
	var own_before := FileAccess.get_file_as_string(own_path)
	var other = Profile.new()
	check(not other.configure(own_path, profile.store.staging_path, "76561198000000002").ok, "A different account cannot adopt scoped progress")
	check(not other.observe_run(evidence(["SD_FIRST_BOSS"])) and FileAccess.get_file_as_string(own_path) == own_before, "Account mismatch keeps file byte-for-byte")
	profile = fresh()
	write_json(profile.store.file_path, {"version": 2, "account_id": "76561198000000001", "unlocked": {}, "confirmed": {}})
	var future_text := FileAccess.get_file_as_string(profile.store.file_path)
	other = Profile.new()
	check(not other.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001").ok, "Future schema blocks older game")
	check(not other.observe_run(evidence(["SD_FIRST_PLANT"])) and FileAccess.get_file_as_string(profile.store.file_path) == future_text, "Future progress is never reset")
	profile = fresh()
	write_json(profile.store.file_path, {"version": 1, "account_id": "76561198000000001", "unlocked": {}, "confirmed": {"SD_FIRST_PLANT": true}})
	other = Profile.new()
	check(not other.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001").ok, "Malformed acknowledgement without earned evidence is rejected")
	profile = fresh()
	write_json(profile.store.file_path, {"version": 1, "account_id": "76561198000000001", "unlocked": {"SD_FUTURE_PURPOSEFUL_FEAT": true}, "confirmed": {}})
	other = Profile.new()
	check(other.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001").ok, "Additive unknown achievement keys remain recoverable")
	check(other.observe_run(evidence(["SD_FIRST_PLANT"])), "Known new unlock coexists with additive unknown evidence")
	check(other.unlocked.has("SD_FUTURE_PURPOSEFUL_FEAT") and other.pending_keys() == ["SD_FIRST_PLANT"], "Unknown keys are preserved but never sent to Steam")
	var validator = Profile.ProfileStore.new()
	for invalid in [1, "true", false, null]:
		check(not validator._valid_data({"version": 1, "account_id": "", "unlocked": {"SD_FIRST_PLANT": invalid}, "confirmed": {}}), "Unlock flags require actual boolean true")
	check(not validator._valid_data({"version": true, "account_id": "", "unlocked": {}, "confirmed": {}}), "Schema version is numeric, not a truthy flag")
	# I/O failure retains memory and blocks platform writes until a verified
	# local journal commit succeeds; this also tests explicit retry.
	profile = Profile.new()
	var missing: String = folder.path_join("initially-missing")
	check(profile.configure(missing.path_join("profile.json"), "", "76561198000000001").ok, "Missing profile is a normal fresh state")
	check(not profile.observe_run(evidence(["SD_FIRST_PLANT"])), "Failed profile write reports failure")
	check(profile.get_status().save_failed and profile.unlocked.has("SD_FIRST_PLANT"), "Unsaved unlock remains in memory and visible")
	steam = FakePlatform.new()
	check(not profile.synchronize(steam) and steam.sets.is_empty(), "Steam cannot receive unsaved evidence")
	DirAccess.make_dir_recursive_absolute(missing)
	check(profile.retry_save() and not profile.get_status().save_failed, "I/O recovery saves pending evidence")
	profile.pump(15.0)
	check(steam.stores == 1, "Saved retry allows Steam submission")
	steam.finish(true)
	# Another process/cloud replacing a valid file mid-session is not silently
	# overwritten even by otherwise monotonic local additions.
	profile = fresh()
	profile.observe_run(evidence(["SD_FIRST_PLANT"]))
	write_json(profile.store.file_path, {"version": 1, "account_id": "76561198000000001", "unlocked": {"SD_FIRST_BOSS": true}, "confirmed": {}})
	var external_text := FileAccess.get_file_as_string(profile.store.file_path)
	check(not profile.observe_run(evidence(["SD_FIRST_MODULE"])) and profile.get_status().blocked, "External change blocks automatic overwrite")
	check(FileAccess.get_file_as_string(profile.store.file_path) == external_text, "Externally replaced valid progress remains intact")
	steam = FakePlatform.new()
	check(not profile.synchronize(steam) and steam.sets.is_empty(), "Conflicted profile blocks publication")
	check(profile.get_status().recoverable, "Same-account external change offers explicit safe recovery")
	check(profile.recover_conflict(), "Explicit recovery merges disk and unsaved in-memory evidence")
	check(profile.unlocked.has("SD_FIRST_PLANT") and profile.unlocked.has("SD_FIRST_MODULE") and profile.unlocked.has("SD_FIRST_BOSS"), "Recovery is a monotonic union, never a choice that loses unlocks")
	check(not profile.get_status().blocked and not profile.get_status().save_failed, "Successful recovery unblocks profile")
	var archive: String = profile.store.last_archive_path
	check(not archive.is_empty() and FileAccess.get_file_as_string(archive.path_join(profile.store.file_path.get_file())) == external_text, "Recovery archives original external file byte-for-byte")
	profile = fresh()
	var base_data := {"version": 1, "account_id": "76561198000000001", "unlocked": {"SD_FIRST_PLANT": true}, "confirmed": {"SD_FIRST_PLANT": true}}
	var alternate := {"version": 1, "account_id": "76561198000000001", "unlocked": {"SD_FIRST_BOSS": true}, "confirmed": {}, "_journal": {"version": 1, "parent_sha256": "f".repeat(64)}}
	write_json(profile.store.file_path, base_data)
	write_json(profile.store.file_path + ".pending", alternate)
	var primary_before := FileAccess.get_file_as_string(profile.store.file_path)
	var pending_before := FileAccess.get_file_as_string(profile.store.file_path + ".pending")
	other = Profile.new()
	check(not other.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001").ok and other.get_status().recoverable, "Divergent same-account journal offers explicit merge")
	check(other.recover_conflict(), "Explicit journal merge succeeds")
	check(other.unlocked.size() == 2 and other.confirmed.has("SD_FIRST_PLANT") and other.pending_keys() == ["SD_FIRST_BOSS"], "Merge preserves confirmations and unacknowledged unlock queue")
	archive = other.store.last_archive_path
	check(FileAccess.get_file_as_string(archive.path_join(profile.store.file_path.get_file())) == primary_before and FileAccess.get_file_as_string(archive.path_join(profile.store.file_path.get_file() + ".pending")) == pending_before, "Both divergent originals are archived before publication")
	profile = fresh()
	write_json(profile.store.file_path, base_data)
	alternate.account_id = "76561198000000002"
	write_json(profile.store.file_path + ".pending", alternate)
	other = Profile.new()
	other.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001")
	check(not other.get_status().recoverable and not other.recover_conflict(), "Another account's alternate can never be merged")
	check(FileAccess.get_file_as_string(profile.store.file_path) == JSON.stringify(base_data), "Rejected cross-account merge leaves original intact")
	profile = fresh()
	base_data.version = 2
	write_json(profile.store.file_path, base_data)
	other = Profile.new()
	other.configure(profile.store.file_path, profile.store.staging_path, "76561198000000001")
	check(not other.get_status().recoverable and not other.recover_conflict(), "Explicit recovery cannot bypass future-schema protection")
	print("ACHIEVEMENT_PROFILE_PASS %d checks / %d failures" % [checks, failures])
	quit(1 if failures else 0)
