extends RefCounted
## Verified local journal; only primary, .pending and .bak are committed files.
## Cloud is synchronized by Steam between sessions, never by this class.

const MAX_BYTES := 8 * 1024 * 1024
var file_path := "":
	set(value):
		if file_path != value: _observed = false
		file_path = value
var staging_path := ""
var last_error: Dictionary = {}
var last_archive_path := ""
var _observed := false
var _observed_signature := ""

func has_save() -> bool:
	for suffix in ["", ".pending", ".bak"]:
		if FileAccess.file_exists(file_path + suffix): return true
	return false

func read_data() -> Dictionary:
	last_error = {}
	_observe()
	if not _check_committed(): return {}
	var result := _read_best()
	if result.is_empty() and has_save(): _fail("invalid_save", "Saved files could not be read. They have been kept for recovery.")
	return result

func write_data(data: Dictionary) -> bool:
	last_error = {}
	if not check_current(): return false
	var result := _write_transaction(data)
	# Our own interrupted writes are safe to retry; unrelated changes are not.
	_observe()
	return result

func check_current() -> bool:
	# Inspect without adopting a new baseline. Use this before New Run; a read
	# is reserved for actually loading the returned snapshot into the model.
	last_error = {}
	if not _check_committed(): return false
	if _observed and _signature() != _observed_signature:
		return _fail("external_change", "Saved files changed outside this session. Choose which saved run to keep before continuing; existing files have been kept.")
	if has_save() and _read_best().is_empty(): return _fail("invalid_save", "Saved files could not be read. They have been kept for recovery.")
	return true

func recovery_snapshot() -> Dictionary:
	last_error = {}
	if not _check_committed() and str(last_error.get("code", "")) != "sync_conflict":
		return {"token": "", "candidates": [], "error": last_error.duplicate()}
	var candidates: Array[Dictionary] = []
	for suffix: String in ["", ".pending", ".bak"]:
		var candidate := _read_valid(file_path + suffix)
		if candidate.is_empty(): continue
		candidate["hash"] = str(candidate.text).sha256_text()
		candidate["source"] = file_path + suffix
		candidate["suffix"] = suffix
		candidate["modified_unix"] = FileAccess.get_modified_time(file_path + suffix)
		candidates.append(candidate)
	return {"token": _signature(), "candidates": candidates, "error": {}}

func resolve_merged(data: Dictionary, expected_signature: String) -> bool:
	## Explicit recovery only. The caller validates domain/account semantics
	## and obtains the token together with its choices from recovery_snapshot.
	last_error = {}
	last_archive_path = ""
	if expected_signature.is_empty() or _signature() != expected_signature:
		return _fail("external_change", "Saved files changed while choosing. Reopen the save choices before continuing; all versions have been kept.")
	if not _check_committed() and str(last_error.get("code", "")) != "sync_conflict": return false
	if not _valid_data(data): return _fail("invalid_choice", "The selected progress could not be validated. All versions have been kept.")
	var archive_root := file_path.get_base_dir().path_join("local-conflicts") if staging_path.is_empty() else staging_path.get_base_dir().get_base_dir().path_join("conflicts")
	var archive := archive_root.path_join("%s-%s-%s" % [file_path.get_file(), int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(archive) != OK: return _io_failure()
	for suffix: String in ["", ".pending", ".bak"]:
		var original := file_path + suffix
		if not FileAccess.file_exists(original): continue
		var preserved := archive.path_join(file_path.get_file() + suffix)
		if DirAccess.copy_absolute(original, preserved) != OK or FileAccess.get_sha256(original) != FileAccess.get_sha256(preserved): return _io_failure()
	last_archive_path = archive
	if _signature() != expected_signature:
		return _fail("external_change", "Saved files changed while preserving copies. Reopen the choices; the originals have been kept.")
	var payload := data.duplicate(true)
	var previous := _read_valid(file_path)
	if previous.is_empty(): previous = _read_valid(file_path + ".bak")
	payload["_journal"] = {"version": 1, "parent_sha256": str(previous.text).sha256_text() if not previous.is_empty() else ""}
	var temporary := file_path + ".tmp" if staging_path.is_empty() else staging_path.path_join("snapshot.tmp")
	if not _write_verified(temporary, JSON.stringify(payload)): return _io_failure()
	if not _replace(temporary, file_path + ".pending"):
		_observe()
		return _io_failure()
	if not _replace(file_path + ".pending", file_path):
		_observe()
		return _io_failure()
	_observe()
	last_error = {}
	return true

func _write_transaction(data: Dictionary) -> bool:
	if not _check_committed(): return false
	var payload := data.duplicate(true)
	payload.erase("_journal")
	if not _valid_data(payload): return _fail("invalid_data", "Progress could not be validated. Earlier saved progress has been kept.")
	var previous := _read_best()
	if previous.is_empty() and has_save():
		return _fail("invalid_save", "Saved files could not be read. They have been kept for recovery.")
	var pending := _read_valid(file_path + ".pending")
	if not pending.is_empty():
		if not _replace(file_path + ".pending", file_path): return _io_failure()
	elif FileAccess.file_exists(file_path + ".pending"):
		if DirAccess.remove_absolute(file_path + ".pending") != OK: return _io_failure()
	previous = _read_best()
	var parent := str(previous.get("text", "")).sha256_text() if not previous.is_empty() else ""
	payload["_journal"] = {"version": 1, "parent_sha256": parent}
	var text := JSON.stringify(payload)
	if text.to_utf8_buffer().size() > MAX_BYTES: return _fail("too_large", "Progress exceeds the supported save size. Earlier saved progress has been kept.")
	var temporary := file_path + ".tmp" if staging_path.is_empty() else staging_path.path_join("snapshot.tmp")
	var backup_temporary := file_path + ".bak.tmp" if staging_path.is_empty() else staging_path.path_join("backup.tmp")
	if not _write_verified(temporary, text): return _io_failure()
	if not previous.is_empty() and str(previous.source) != file_path + ".bak":
		if not _write_verified(backup_temporary, str(previous.text)): return _io_failure()
		if not _replace(backup_temporary, file_path + ".bak"): return _io_failure()
	if not _replace(temporary, file_path + ".pending"): return _io_failure()
	if not _replace(file_path + ".pending", file_path): return _io_failure()
	return true

func _check_committed() -> bool:
	for suffix in ["", ".pending", ".bak"]:
		var issue := _committed_file_issue(file_path + suffix)
		if not issue.is_empty(): return _fail(str(issue.code), str(issue.message))
		var raw := _read_json(file_path + suffix)
		if raw.is_empty(): continue
		var value: Variant = raw.data
		if value is Dictionary:
			if _number(value.get("version")) and float(value.version) > 1:
				return _fail("newer_version", "This save was made by a newer game version. Update the game before continuing; all files have been kept.")
			var metadata: Variant = value.get("_journal")
			if metadata is Dictionary and _number(metadata.get("version")) and float(metadata.version) > 1:
				return _fail("newer_version", "This save needs a newer game version. Update before continuing; all files have been kept.")
	var pending := _read_valid(file_path + ".pending")
	var primary := _read_valid(file_path)
	if pending.is_empty(): return true
	# A downloaded backup can be newer than a stale local journal too. When
	# the primary is damaged, do not let the journal roll that backup back.
	var previous := primary if not primary.is_empty() else _read_valid(file_path + ".bak")
	if previous.is_empty() or str(pending.text) == str(previous.text): return true
	var pending_meta: Variant = pending.data.get("_journal")
	var primary_meta: Variant = previous.data.get("_journal")
	# Legacy journals predate cloud support and retain their established order.
	if pending_meta == null and primary_meta == null: return true
	if pending_meta is Dictionary and str(pending_meta.parent_sha256) == str(previous.text).sha256_text(): return true
	return _fail("sync_conflict", "Different saved progress was found after syncing. Choose a saved run in Saves & Steam; existing versions have been kept.")

func _committed_file_issue(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"code": "unreadable_save", "message": "A saved file cannot be opened. Restore access before continuing; every version has been kept."}
	var size := file.get_length()
	file.close()
	if size > MAX_BYTES:
		return {"code": "oversized_save", "message": "A saved file exceeds this version's supported size. Update the game or restore a supported save; every version has been kept."}
	return {}

func _read_best() -> Dictionary:
	for suffix in [".pending", "", ".bak"]:
		var candidate := _read_valid(file_path + suffix)
		if not candidate.is_empty():
			candidate["recovered"] = suffix != ""
			candidate["source"] = file_path + suffix
			return candidate
	return {}

func _replace(source: String, destination: String) -> bool:
	return DirAccess.rename_absolute(source, destination) == OK

func _write_verified(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var status := file.get_error()
	file.close()
	if status != OK: return false
	var verified := _read_valid(path)
	return not verified.is_empty() and str(verified.text) == text

func _read_valid(path: String) -> Dictionary:
	var candidate := _read_json(path)
	if candidate.is_empty() or not _valid_data(candidate.data) or not _valid_metadata(candidate.data): return {}
	return candidate

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	if file.get_length() <= 0 or file.get_length() > MAX_BYTES:
		file.close()
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK: return {}
	return {"data": parser.data, "text": text}

func _valid_data(data: Variant) -> bool:
	return data is Dictionary and _number(data.get("version")) and float(data.version) == 1

func _valid_metadata(data: Dictionary) -> bool:
	if not data.has("_journal"): return true
	var metadata: Variant = data._journal
	if not metadata is Dictionary or metadata.get("version") != 1 or not metadata.get("parent_sha256") is String: return false
	var parent: String = metadata.parent_sha256
	if parent.is_empty(): return true
	if parent.length() != 64: return false
	for character in parent:
		if not character in "0123456789abcdef": return false
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _signature() -> String:
	var parts: Array[String] = [file_path]
	for suffix in ["", ".pending", ".bak"]:
		var path: String = file_path + suffix
		if not FileAccess.file_exists(path):
			parts.append(suffix + ":missing")
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			parts.append(suffix + ":unreadable")
			continue
		var size := file.get_length()
		var fingerprint := file.get_buffer(size).hex_encode().sha256_text() if size <= MAX_BYTES else "oversize:" + str(size) + ":" + str(FileAccess.get_modified_time(path))
		file.close()
		parts.append(suffix + ":" + fingerprint)
	return "|".join(parts)

func _observe() -> void:
	_observed = true
	_observed_signature = _signature()

func _fail(code: String, message: String) -> bool:
	last_error = {"code": code, "message": message}
	return false

func _io_failure() -> bool:
	return _fail("io_error", "Progress could not be saved. Earlier committed progress has been kept; retry saving.")
