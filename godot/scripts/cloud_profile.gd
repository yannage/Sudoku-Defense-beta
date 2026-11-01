extends RefCounted
## Account-scoped Auto-Cloud files; never infer a previous Steam account.

const RunSave = preload("res://scripts/run_save.gd")
const Journal = preload("res://scripts/journal_store.gd")
const Achievements = preload("res://scripts/achievement_profile.gd")
const LEGACY_RUN := "sudoku-defense-run.json"
const LOCAL_ACHIEVEMENTS := "sudoku-defense-achievements.json"
const MIGRATION_CLAIM := "sudoku-defense-steam-migration.json"

func configure(steam_id: String, base_path: String = "user://") -> Dictionary:
	if steam_id.is_empty():
		return {"ok": true, "scoped": false, "migrated": false,
			"run_path": base_path.path_join(LEGACY_RUN),
			"achievement_path": base_path.path_join(LOCAL_ACHIEVEMENTS), "staging_root": ""}
	if not _valid_steam_id(steam_id):
		return _error("invalid_identity", "Steam could not identify this save profile. Restart Steam before continuing.")
	var account_root := base_path.path_join("steam").path_join(steam_id)
	var cloud_root := account_root.path_join("cloud")
	var staging_root := account_root.path_join("local/staging")
	for folder in [cloud_root, staging_root.path_join("run"), staging_root.path_join("achievements")]:
		if DirAccess.make_dir_recursive_absolute(folder) != OK:
			return _error("io_error", "The Steam save folder could not be created. Earlier saved files have been kept.")
	var result := {"ok": true, "scoped": true, "migrated": false,
		"run_path": cloud_root.path_join("run.json"),
		"achievement_path": cloud_root.path_join("achievements.json"), "staging_root": staging_root}
	var claim = Journal.new()
	claim.file_path = base_path.path_join(MIGRATION_CLAIM)
	for kind: String in ["run", "achievements"]:
		var destination = RunSave.new() if kind == "run" else Achievements.ProfileStore.new()
		destination.file_path = result.run_path if kind == "run" else result.achievement_path
		destination.staging_path = staging_root.path_join(kind)
		var legacy = RunSave.new() if kind == "run" else Achievements.ProfileStore.new()
		legacy.file_path = base_path.path_join(LEGACY_RUN if kind == "run" else LOCAL_ACHIEVEMENTS)
		var migration := _migrate_file(kind, legacy, destination, claim, steam_id)
		if not migration.ok: return _error_from(migration.error, result)
		result.migrated = result.migrated or migration.migrated
	return result

func _migrate_file(kind: String, legacy, destination, claim, steam_id: String) -> Dictionary:
	var unchanged := {"ok": true, "migrated": false}
	var target: Dictionary = destination.read_data()
	if not destination.last_error.is_empty(): return _error_from(destination.last_error, unchanged)
	if destination.has_save() and target.is_empty():
		return _error("invalid_save", "The Steam save could not be read. Its files have been kept for recovery.")
	var claimed: Dictionary = claim.read_data()
	if not claim.last_error.is_empty(): return _error_from(claim.last_error, unchanged)
	if claim.has_save() and (claimed.is_empty() or not _valid_claim(claimed.data)):
		return _error("invalid_migration", "The local save migration record could not be read. Existing saves have been kept.")
	if not claimed.is_empty() and str(claimed.data.owner) != steam_id: return unchanged
	var sources: Dictionary = {} if claimed.is_empty() else claimed.data.sources.duplicate()
	# A crash after committing the copy but before recording the local claim
	# is finished from the verified copy, without importing the old file again.
	if not target.is_empty():
		var migration: Variant = target.data.get("_steam_migration")
		if not sources.has(kind) and migration is Dictionary and str(migration.get("owner", "")) == steam_id and str(migration.get("kind", "")) == kind:
			sources[kind] = str(migration.get("source_sha256", ""))
			if not _write_claim(claim, steam_id, sources): return _error_from(claim.last_error, unchanged)
		return unchanged
	if sources.has(kind): return unchanged
	var original: Dictionary = legacy.read_data()
	if not legacy.last_error.is_empty(): return _error_from(legacy.last_error, unchanged)
	if original.is_empty():
		if legacy.has_save(): return _error("invalid_save", "Earlier local progress could not be read. Its files have been kept for recovery.")
		return unchanged
	# An explicitly owned profile cannot transfer its unlocks to another user.
	if kind == "achievements" and str(original.data.account_id) not in ["", steam_id]: return unchanged
	var source_hash := str(original.text).sha256_text()
	var migrated: Dictionary = original.data.duplicate(true)
	migrated["_steam_migration"] = {"owner": steam_id, "kind": kind, "source_sha256": source_hash}
	if kind == "achievements":
		migrated.account_id = steam_id
		migrated.confirmed = {} # Query/store against this account before acknowledging.
	if not destination.write_data(migrated): return _error_from(destination.last_error, unchanged)
	var copied: Dictionary = destination.read_data()
	if copied.is_empty() or copied.data.get("_steam_migration") != migrated._steam_migration:
		return _error("migration_verify", "The Steam save copy could not be verified. Your earlier local progress has been kept.")
	sources[kind] = source_hash
	if not _write_claim(claim, steam_id, sources): return _error_from(claim.last_error, unchanged)
	return {"ok": true, "migrated": true}

func _write_claim(claim, steam_id: String, sources: Dictionary) -> bool:
	var data := {"version": 1, "owner": steam_id, "sources": sources}
	if not _valid_claim(data):
		claim.last_error = {"code": "invalid_migration", "message": "The save migration record could not be verified. Existing saves have been kept."}
		return false
	if not claim.write_data(data): return false
	var saved: Dictionary = claim.read_data()
	return not saved.is_empty() and _valid_claim(saved.data) and str(saved.data.owner) == steam_id and saved.data.sources == sources

func _valid_claim(data: Dictionary) -> bool:
	if not _valid_steam_id(str(data.get("owner", ""))) or not data.get("sources") is Dictionary: return false
	if data.sources.is_empty() or data.sources.size() > 2: return false
	for kind: Variant in data.sources:
		if kind not in ["run", "achievements"] or not _valid_hash(str(data.sources[kind])): return false
	return true

func _valid_steam_id(value: String) -> bool:
	if value.length() < 16 or value.length() > 19 or not value.is_valid_int() or int(value) <= 0: return false
	for character in value:
		if not character in "0123456789": return false
	return str(int(value)) == value

func _valid_hash(value: String) -> bool:
	if value.length() != 64: return false
	for character in value:
		if not character in "0123456789abcdef": return false
	return true

func _error_from(reason: Dictionary, result: Dictionary) -> Dictionary:
	return _error(str(reason.get("code", "io_error")), str(reason.get("message", "Saved files have been kept; restart and retry.")), result)

func _error(code: String, message: String, result: Dictionary = {}) -> Dictionary:
	var failed := result.duplicate(true)
	failed["ok"] = false
	failed["error"] = {"code": code, "message": message}
	return failed
