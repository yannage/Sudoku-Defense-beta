extends RefCounted
## Permanent unlock evidence is saved before asking Steam to store it.
## Confirmed means the Steam client acknowledged StoreStats, not two-device sync.
signal changed

const Rules = preload("res://scripts/achievement_rules.gd")
const CATALOG_PATH := "res://data/achievements.json"
const RETRY_SECONDS := 15.0
const QUERY_RETRY_SECONDS := 3.0
const STORE_TIMEOUT_SECONDS := 45.0

class ProfileStore:
	extends "res://scripts/journal_store.gd"
	func _valid_data(data: Variant) -> bool:
		if not data is Dictionary or not _number(data.get("version")) or float(data.version) != 1.0: return false
		if not data.get("account_id") is String or data.account_id.length() > 32: return false
		for character in data.account_id:
			if not character in "0123456789": return false
		if not data.get("unlocked") is Dictionary or not data.get("confirmed") is Dictionary: return false
		if data.unlocked.size() > 256 or data.confirmed.size() > 256: return false
		for field in ["unlocked", "confirmed"]:
			for key: Variant in data[field]:
				if not key is String or not key.begins_with("SD_") or key.length() > 80: return false
				for character in key:
					if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_": return false
				if not data[field][key] is bool or not data[field][key]: return false
		for key: String in data.confirmed:
			if not data.unlocked.has(key): return false
		return true

var store = ProfileStore.new()
var unlocked: Dictionary = {}
var confirmed: Dictionary = {}
var last_error: Dictionary = {}
var _catalog: Array[Dictionary] = []
var _known: Dictionary = {}
var _account_id := ""
var _configured := false
var _blocked := false
var _dirty := false
var _platform_ref: WeakRef
var _platform: Object:
	get:
		return _platform_ref.get_ref() if _platform_ref != null else null
	set(value):
		_platform_ref = weakref(value) if value != null else null
var _inflight: Dictionary = {}
var _locally_set: Dictionary = {}
var _inflight_account := ""
var _waiting := 0.0
var _retry := 0.0
var _message := "Achievements are saved locally."

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Array:
		for entry: Variant in parsed:
			if entry is Dictionary and entry.get("id") is String:
				_catalog.append(entry.duplicate(true))
				_known[str(entry.id)] = true

func configure(path: String, staging: String = "", account_id: String = "") -> Dictionary:
	_unbind_platform()
	store = ProfileStore.new()
	store.file_path = path
	store.staging_path = staging
	_account_id = account_id
	unlocked = {}
	confirmed = {}
	last_error = {}
	_blocked = false
	_dirty = false
	_configured = not path.is_empty()
	_locally_set.clear()
	_retry = 0.0
	_message = "Achievements are saved locally."
	if not _configured:
		_block("not_configured", "Achievements could not be opened on this device.")
		return get_status()
	var saved: Dictionary = store.read_data()
	if saved.is_empty():
		if not store.last_error.is_empty(): _block_store_error()
		elif store.has_save(): _block("invalid_save", "Achievement progress could not be read. Existing files have been kept.")
	else:
		var data: Dictionary = saved.data
		var saved_account: String = str(data.account_id)
		# Only an unclaimed local profile may migrate into an account folder.
		if not saved_account.is_empty() and saved_account != _account_id:
			_block("account_mismatch", "This achievement file belongs to another Steam account. It has been kept unchanged.")
		else:
			unlocked = data.unlocked.duplicate(true)
			confirmed = data.confirmed.duplicate(true) if saved_account == _account_id else {}
			_dirty = saved_account != _account_id
			if _dirty: retry_save()
	changed.emit()
	return get_status()

func observe_run(run: RefCounted) -> bool:
	if not _configured or _blocked: return false
	var added := false
	for key: String in Rules.evaluate(run):
		if _known.has(key) and not unlocked.has(key):
			unlocked[key] = true
			added = true
	if added:
		_dirty = true
		changed.emit()
	if _dirty: return retry_save()
	return true

func retry_save() -> bool:
	if not _configured or _blocked: return false
	if not _dirty: return true
	var payload := {"version": 1, "account_id": _account_id, "unlocked": unlocked.duplicate(true), "confirmed": confirmed.duplicate(true)}
	if not store.write_data(payload):
		last_error = store.last_error.duplicate(true)
		_message = str(last_error.get("message", "Achievement progress could not be saved. Retry saving before closing."))
		_blocked = str(last_error.get("code", "")) in ["external_change", "sync_conflict", "newer_version", "invalid_save"]
		changed.emit()
		return false
	_dirty = false
	last_error = {}
	_message = "Achievements are saved locally."
	changed.emit()
	return true

func synchronize(platform: Object) -> bool:
	if not _configured or _blocked or platform == null: return false
	if _platform != platform:
		_unbind_platform()
		_platform = platform
		if platform.has_signal("stats_stored"): platform.stats_stored.connect(_on_stats_stored)
	var status: Dictionary = platform.get_status()
	if not _matching_account(status):
		if not _inflight.is_empty(): _finish_failed_batch()
		_message = "Achievements are saved locally. Steam will receive them when this account is available."
		return false
	if not _inflight.is_empty() or _retry > 0.0 or bool(status.get("store_pending", false)): return false
	if _dirty and not retry_save():
		_retry = RETRY_SECONDS
		return false
	# Reconcile the same account. Missing remote acknowledgements requeue the
	# durable evidence; unacknowledged local SetAchievement cache is not proof.
	var all_known := true
	var altered := false
	for entry: Dictionary in _catalog:
		var key: String = str(entry.id)
		var answer: Dictionary = platform.query_achievement(key)
		if not bool(answer.get("known", false)):
			all_known = false
			continue
		if bool(answer.get("achieved", false)) and not _locally_set.has(key):
			if not unlocked.has(key) or not confirmed.has(key): altered = true
			unlocked[key] = true
			confirmed[key] = true
		elif not bool(answer.get("achieved", false)) and confirmed.has(key):
			confirmed.erase(key)
			altered = true
	if altered:
		_dirty = true
		if not retry_save():
			_retry = RETRY_SECONDS
			return false
	if not all_known:
		_message = "Achievement progress is saved. Waiting for Steam achievement data."
		_retry = QUERY_RETRY_SECONDS
		return false
	var pending := pending_keys()
	if pending.is_empty():
		_message = "Earned achievements are recorded by Steam."
		_retry = RETRY_SECONDS
		return true
	if not _matching_account(platform.get_status()): return false
	var batch: Dictionary = {}
	for key: String in pending:
		if not platform.set_achievement(key):
			_message = "Achievement progress is saved. Steam will retry the unlocks."
			_retry = RETRY_SECONDS
			return false
		_locally_set[key] = true
		batch[key] = true
	_inflight = batch
	_inflight_account = _account_id
	_waiting = 0.0
	if not platform.store_achievements():
		_finish_failed_batch()
		return false
	_message = "Achievement progress is saved. Waiting for Steam to record it."
	return true

func pump(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_retry = maxf(0.0, _retry - delta)
	if not _inflight.is_empty():
		_waiting += delta
		if _waiting >= STORE_TIMEOUT_SECONDS: _finish_failed_batch()
	if is_instance_valid(_platform) and _inflight.is_empty() and _retry <= 0.0:
		synchronize(_platform)

func pending_keys() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in _catalog:
		var key: String = str(entry.id)
		if unlocked.has(key) and not confirmed.has(key): result.append(key)
	return result

func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in _catalog:
		var entry: Dictionary = source.duplicate(true)
		entry["unlocked"] = unlocked.has(str(entry.id))
		entry["pending"] = bool(entry.unlocked) and not confirmed.has(str(entry.id))
		result.append(entry)
	return result

func get_status() -> Dictionary:
	var count := 0
	for entry: Dictionary in _catalog:
		if unlocked.has(str(entry.id)): count += 1
	return {"ok": _configured and not _blocked and not _dirty, "configured": _configured,
		"blocked": _blocked, "save_failed": _dirty or _blocked, "message": _message,
		"unlocked_count": count, "total_count": _catalog.size(), "pending_count": pending_keys().size(),
		"store_pending": not _inflight.is_empty(), "account_id": _account_id,
		"error": last_error.duplicate(true), "recoverable": not _recovery_snapshot().is_empty()}

func recover_conflict() -> bool:
	# Explicit action only. Journal helper archives all originals before commit.
	var snapshot := _recovery_snapshot()
	if snapshot.is_empty(): return false
	var merged_unlocked := unlocked.duplicate(true)
	var merged_confirmed := confirmed.duplicate(true)
	for candidate: Dictionary in snapshot.candidates:
		merged_unlocked.merge(candidate.data.unlocked, true)
		merged_confirmed.merge(candidate.data.confirmed, true)
	var payload := {"version": 1, "account_id": _account_id, "unlocked": merged_unlocked, "confirmed": merged_confirmed}
	if not store.resolve_merged(payload, str(snapshot.token)):
		last_error = store.last_error.duplicate(true)
		_message = str(last_error.get("message", "Achievement recovery could not finish. All original files have been kept."))
		changed.emit()
		return false
	_unbind_platform()
	unlocked = merged_unlocked
	confirmed = merged_confirmed
	_blocked = false
	_dirty = false
	last_error = {}
	_retry = 0.0
	_message = "Achievement progress recovered. Original files were archived on this device."
	changed.emit()
	return true

func _recovery_snapshot() -> Dictionary:
	if not _configured or not _blocked or str(last_error.get("code", "")) not in ["sync_conflict", "external_change", "invalid_save"]: return {}
	if not store.has_method("recovery_snapshot"): return {}
	var snapshot: Dictionary = store.recovery_snapshot()
	if not snapshot.get("error", {}).is_empty() or str(snapshot.get("token", "")).is_empty() or snapshot.get("candidates", []).is_empty(): return {}
	for candidate: Dictionary in snapshot.candidates:
		if str(candidate.data.get("account_id", "")) != _account_id: return {}
	return snapshot

func close() -> void:
	_unbind_platform()

func _matching_account(status: Dictionary) -> bool:
	return not _account_id.is_empty() and bool(status.get("available", false)) and bool(status.get("ready", false)) and int(status.get("app_id", 0)) == 3721150 and str(status.get("account_id", "")) == _account_id

func _on_stats_stored(success: bool) -> void:
	if _inflight.is_empty(): return
	if not success or not is_instance_valid(_platform) or _inflight_account != _account_id or not _matching_account(_platform.get_status()):
		_finish_failed_batch()
		return
	for key: String in _inflight:
		confirmed[key] = true
		_locally_set.erase(key)
	_inflight.clear()
	_inflight_account = ""
	_waiting = 0.0
	_dirty = true
	_retry = QUERY_RETRY_SECONDS
	if retry_save(): _message = "Earned achievements are recorded by Steam."
	changed.emit()

func _finish_failed_batch() -> void:
	_inflight.clear()
	_inflight_account = ""
	_waiting = 0.0
	_retry = RETRY_SECONDS
	_message = "Achievement progress is saved. Steam will retry the unlocks."
	changed.emit()

func _unbind_platform() -> void:
	if is_instance_valid(_platform) and _platform.has_signal("stats_stored") and _platform.stats_stored.is_connected(_on_stats_stored):
		_platform.stats_stored.disconnect(_on_stats_stored)
	_platform = null
	_inflight.clear()
	_inflight_account = ""
	_waiting = 0.0

func _block_store_error() -> void:
	_block(str(store.last_error.get("code", "invalid_save")), str(store.last_error.get("message", "Achievement progress could not be read. Existing files have been kept.")))

func _block(code: String, message: String) -> void:
	_blocked = true
	last_error = {"code": code, "message": message}
	_message = message
