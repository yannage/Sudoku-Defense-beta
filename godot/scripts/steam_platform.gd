extends Node
## The only production gateway to Steam. Loading the native extension does not
## initialize Steam; editor, tests, direct launches and Web remain local-only.
## AchievementProfile owns durable queues. A true SetAchievement/StoreStats return
## is not an acknowledgement: wait for stats_stored(true).

signal stats_stored(success: bool)
signal availability_changed(status: Dictionary)
signal overlay_changed(active: bool)

const APP_ID: int = 3721150
const STORE_TIMEOUT_SECONDS: float = 30.0
const STORE_RETRY_SECONDS: float = 60.0
const REQUIRED_METHODS: Array[String] = [
	"steamInitEx", "getAppID", "getSteamID", "run_callbacks", "getAchievement",
	"setAchievement", "storeStats", "isCloudEnabledForAccount", "isCloudEnabledForApp", "steamShutdown"
]

var _gateway: Object
var _initialized: bool = false
var _available: bool = false
var _ready: bool = false
var _status: String = "local_only"
var _account_id: String = ""
var _cloud_enabled: bool = false
var _store_pending: bool = false
var _store_age: float = 0.0
var _retry_after: float = 0.0
var _volatile_keys: Dictionary = {}
var _signal_links: Array = []


func initialize(mock_gateway: Object = null, mock_context: Dictionary = {}) -> Dictionary:
	if _initialized or _available:
		return get_status()
	var context: Dictionary = _launch_context()
	if mock_gateway != null:
		# Injection may only replace the native gateway, never bypass its guard.
		if Engine.has_singleton("Steam") and mock_gateway == Engine.get_singleton("Steam"):
			_status = "unsafe_injection_rejected"
			return get_status()
		context = mock_context
	var reason := disabled_reason(context)
	if not reason.is_empty():
		_status = reason
		return get_status()
	_gateway = mock_gateway
	if _gateway == null and Engine.has_singleton("Steam"):
		_gateway = Engine.get_singleton("Steam")
	if _gateway == null:
		_status = "steam_extension_unavailable"
		return get_status()
	for method in REQUIRED_METHODS:
		if not _gateway.has_method(method):
			_status = "steam_extension_incompatible"
			return get_status()
	# App ID 0 preserves Steam's launch context; never set environment variables,
	# ship steam_appid.txt, or restart through Steam (which may launch an older build).
	var result: Variant = _gateway.call("steamInitEx", 0, false)
	if not result is Dictionary or int(result.get("status", -1)) != 0:
		_status = "steam_unavailable"
		return get_status()
	_initialized = true
	if int(_gateway.call("getAppID")) != APP_ID:
		_status = "steam_app_mismatch"
		shutdown()
		return get_status()
	_account_id = str(_gateway.call("getSteamID"))
	if not _account_id.is_valid_int() or int(_account_id) <= 0:
		_status = "steam_account_unavailable"
		shutdown()
		return get_status()
	_available = true
	_ready = true # Steamworks 1.65 loads local stats before launching the game.
	_status = "steam_ready"
	_connect_gateway("user_stats_stored", _on_stats_stored)
	_connect_gateway("user_stats_received", _on_stats_received)
	_connect_gateway("user_stats_unloaded", _on_stats_unloaded)
	_connect_gateway("steam_shutdown", _on_steam_shutdown)
	_connect_gateway("overlay_toggled", _on_overlay_toggled)
	_refresh_cloud_status()
	availability_changed.emit(get_status())
	return get_status()


static func disabled_reason(context: Dictionary) -> String:
	if not bool(context.get("native_export", false)):
		return "local_only"
	if bool(context.get("editor", true)) or bool(context.get("headless", true)):
		return "qa_disabled"
	if bool(context.get("disabled", false)):
		return "explicitly_disabled"
	for argument in context.get("arguments", []):
		var value := str(argument).to_lower()
		if value == "--" or value in ["--safe-graphics", "--canvas-graphics", "--fullscreen", "-f", "--windowed", "-w"]:
			continue
		# Custom/test profiles and unknown startup overrides cannot accidentally
		# connect an isolated process to the owner's Steam account.
		return "qa_disabled"
	if str(context.get("steam_app_id", "")) != str(APP_ID):
		return "not_launched_by_steam"
	var game_id := str(context.get("steam_game_id", ""))
	if not game_id.is_empty() and game_id != str(APP_ID):
		return "steam_app_mismatch"
	return ""


func _launch_context() -> Dictionary:
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	return {
		"native_export": OS.has_feature("template") and not OS.has_feature("web") and OS.get_name() in ["Windows", "Linux"],
		"editor": Engine.is_editor_hint() or OS.has_feature("editor"),
		"headless": DisplayServer.get_name() == "headless",
		"disabled": OS.get_environment("SUDOKU_DISABLE_STEAM") == "1" or not OS.get_environment("SUDOKU_TEST_PROFILE").is_empty(),
		"arguments": args,
		"steam_app_id": OS.get_environment("SteamAppId"),
		"steam_game_id": OS.get_environment("SteamGameId"),
	}


func get_status() -> Dictionary:
	return {"available": _available, "ready": _ready, "status": _status,
		"account_id": _account_id, "app_id": APP_ID if _available else 0,
		"cloud_enabled": _cloud_enabled, "store_pending": _store_pending,
		"retry_after_seconds": _retry_after}


func pump(delta: float) -> void:
	_retry_after = maxf(0.0, _retry_after - maxf(0.0, delta))
	if not _check_identity():
		return
	_gateway.call("run_callbacks")
	if not _check_identity():
		return
	_refresh_cloud_status()
	if _store_pending:
		_store_age += maxf(0.0, delta)
		if _store_age >= STORE_TIMEOUT_SECONDS:
			_store_pending = false
			_retry_after = STORE_RETRY_SECONDS
			# The callback has no request ID. Reusing the session after an unknown
			# timeout could let a late acknowledgement clear a newer batch.
			_ready = false
			_status = "steam_sync_timeout"
			stats_stored.emit(false)
			availability_changed.emit(get_status())


func query_achievement(api_key: String) -> Dictionary:
	if not _valid_key(api_key) or not _check_identity() or not _ready:
		return {"known": false, "achieved": false, "pending": false}
	var response: Variant = _gateway.call("getAchievement", api_key)
	if not response is Dictionary:
		return {"known": false, "achieved": false, "pending": false}
	var pending := _volatile_keys.has(api_key)
	# GetAchievement includes in-memory SetAchievement writes. Do not let those
	# masquerade as an acknowledged remote unlock after StoreStats fails.
	return {"known": bool(response.get("ret", false)),
		"achieved": bool(response.get("ret", false)) and bool(response.get("achieved", false)) and not pending,
		"pending": pending}


func set_achievement(api_key: String) -> bool:
	if not _valid_key(api_key) or not _check_identity() or not _ready or _store_pending:
		return false
	var existing := query_achievement(api_key)
	if not bool(existing.known):
		return false
	if bool(existing.achieved):
		return true
	if bool(_gateway.call("setAchievement", api_key)):
		_volatile_keys[api_key] = true
		return true
	return false


func store_achievements() -> bool:
	if not _check_identity() or not _ready or _store_pending or _retry_after > 0.0 or _volatile_keys.is_empty():
		return false
	# Set pending first so a synchronous mock callback has the same semantics.
	_store_pending = true
	_store_age = 0.0
	if not bool(_gateway.call("storeStats")):
		_store_pending = false
		_retry_after = STORE_RETRY_SECONDS
		return false
	return true


func _check_identity() -> bool:
	if not _available or not _initialized or not is_instance_valid(_gateway):
		return false
	if int(_gateway.call("getAppID")) != APP_ID or str(_gateway.call("getSteamID")) != _account_id:
		_disable("steam_account_changed")
		return false
	return true


func _refresh_cloud_status() -> void:
	_cloud_enabled = bool(_gateway.call("isCloudEnabledForAccount")) and bool(_gateway.call("isCloudEnabledForApp"))


func _valid_key(api_key: String) -> bool:
	if api_key.is_empty() or api_key.length() > 128:
		return false
	for character in api_key:
		if not (character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"):
			return false
	return true


func _connect_gateway(signal_name: StringName, callback: Callable) -> void:
	if _gateway.has_signal(signal_name):
		_gateway.connect(signal_name, callback)
		_signal_links.append([signal_name, callback])


func _on_stats_stored(game_id: int, result: int) -> void:
	if game_id != APP_ID or not _store_pending or not _check_identity():
		return
	_store_pending = false
	if result == 1: # k_EResultOK
		_volatile_keys.clear()
		_retry_after = 0.0
	else:
		_retry_after = STORE_RETRY_SECONDS
	stats_stored.emit(result == 1)


func _on_stats_received(game_id: int, result: int, user_id: int) -> void:
	if _status != "steam_sync_timeout" and game_id == APP_ID and str(user_id) == _account_id and _check_identity():
		_ready = result == 1
		availability_changed.emit(get_status())


func _on_stats_unloaded(user_id: int) -> void:
	if str(user_id) == _account_id:
		_disable("steam_stats_unloaded")


func _on_steam_shutdown() -> void:
	_disable("steam_disconnected")


func _on_overlay_toggled(active: bool, _user_initiated: bool, app_id: int) -> void:
	if app_id == APP_ID and _check_identity():
		overlay_changed.emit(active)


func _disable(reason: String) -> void:
	var pending := _store_pending
	_available = false
	_ready = false
	_cloud_enabled = false
	_store_pending = false
	_status = reason
	if pending:
		stats_stored.emit(false)
	availability_changed.emit(get_status())


func shutdown() -> void:
	var was_initialized := _initialized
	_initialized = false
	_available = false
	_ready = false
	_cloud_enabled = false
	_store_pending = false
	if is_instance_valid(_gateway):
		for link in _signal_links:
			if _gateway.is_connected(link[0], link[1]):
				_gateway.disconnect(link[0], link[1])
		if was_initialized:
			_gateway.call("steamShutdown")
	_signal_links.clear()
	_gateway = null
	_volatile_keys.clear()


func _exit_tree() -> void:
	shutdown()
