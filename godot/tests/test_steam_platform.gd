extends SceneTree

const Platform = preload("res://scripts/steam_platform.gd")
var checks := 0
var failures: Array[String] = []

class MockSteam extends RefCounted:
	signal user_stats_stored(game_id: int, result: int)
	signal user_stats_received(game_id: int, result: int, user_id: int)
	signal user_stats_unloaded(user_id: int)
	signal steam_shutdown
	signal overlay_toggled(active: bool, user_initiated: bool, app_id: int)
	var app_id := 3721150
	var user_id := 76561198000000001
	var init_status := 0
	var init_calls := 0
	var set_calls := 0
	var store_calls := 0
	var callbacks := 0
	var shutdown_calls := 0
	var cloud_account := true
	var cloud_app := true
	var store_result := true
	var set_result := true
	var achievements := {"FIRST_SEED": false, "FIRST_WAVE": false, "ALREADY_EARNED": true}
	func steamInitEx(app: int, embed: bool) -> Dictionary:
		assert(app == 0 and not embed)
		init_calls += 1
		return {"status": init_status}
	func getAppID() -> int: return app_id
	func getSteamID() -> int: return user_id
	func run_callbacks() -> void: callbacks += 1
	func getAchievement(key: String) -> Dictionary:
		return {"ret": achievements.has(key), "achieved": achievements.get(key, false)}
	func setAchievement(key: String) -> bool:
		set_calls += 1
		if set_result: achievements[key] = true
		return set_result
	func storeStats() -> bool:
		store_calls += 1
		return store_result
	func isCloudEnabledForAccount() -> bool: return cloud_account
	func isCloudEnabledForApp() -> bool: return cloud_app
	func steamShutdown() -> void: shutdown_calls += 1


func _initialize() -> void:
	call_deferred("_run")


func _context() -> Dictionary:
	return {"native_export": true, "editor": false, "headless": false,
		"disabled": false, "arguments": [], "steam_app_id": "3721150", "steam_game_id": "3721150"}


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message)


func _run() -> void:
	if OS.get_name() in ["Windows", "Linux"] and not OS.has_feature("web"):
		_check(Engine.has_singleton("Steam"), "Pinned native extension loads without Steam initialization")
		if Engine.has_singleton("Steam"):
			_check(Engine.get_singleton("Steam").has_method("steamInitEx"), "Loaded extension exposes expected interface")
	var disabled_cases: Array = [
		{"native_export": false}, {"editor": true}, {"headless": true}, {"disabled": true},
		{"steam_app_id": ""}, {"steam_app_id": "480"}, {"steam_game_id": "480"},
		{"arguments": ["--headless"]}, {"arguments": ["--quit-after", "2"]},
		{"arguments": ["--script", "res://tests/test_run.gd"]},
		{"arguments": ["--user-data-dir", "test"]}, {"arguments": ["--test"]},
		{"arguments": ["--smoke"]}, {"arguments": ["--steam-disable"]},
		{"arguments": ["--unrecognized-startup-override"]}
	]
	for overrides in disabled_cases:
		var context := _context()
		context.merge(overrides, true)
		var gateway := MockSteam.new()
		var platform := Platform.new()
		var status := platform.initialize(gateway, context)
		_check(not status.available and gateway.init_calls == 0, "Unsafe launch rejected: %s" % overrides)
		platform.pump(100)
		_check(not platform.set_achievement("FIRST_SEED") and not platform.store_achievements(), "Disabled gateway never writes")
		_check(gateway.callbacks == 0 and gateway.set_calls == 0 and gateway.store_calls == 0, "Disabled gateway never pumps native calls")
		platform.free()
	var direct := Platform.new()
	_check(not direct.initialize().available, "Actual headless editor context is safe without calling SteamInit")
	direct.free()
	_check(Platform.disabled_reason(_context()).is_empty(), "Steam native exported context allowed")
	var supported := _context()
	supported.arguments = ["--", "--safe-graphics", "--canvas-graphics", "--fullscreen"]
	_check(Platform.disabled_reason(supported).is_empty(), "Existing graphics modes remain compatible")

	var gateway := MockSteam.new()
	var platform := Platform.new()
	var acknowledgements: Array = []
	var overlays: Array = []
	platform.stats_stored.connect(func(ok: bool): acknowledgements.append(ok))
	platform.overlay_changed.connect(func(active: bool): overlays.append(active))
	var status := platform.initialize(gateway, _context())
	_check(status.available and status.ready and status.account_id == str(gateway.user_id), "Verified identity exposed as string")
	_check(status.cloud_enabled and gateway.init_calls == 1, "Cloud flags queried after initialization")
	platform.initialize(gateway, _context())
	_check(gateway.init_calls == 1, "Initialization is idempotent")
	_check(platform.query_achievement("ALREADY_EARNED").achieved, "Published earned achievement readable")
	_check(not platform.query_achievement("UNKNOWN_KEY").known, "Unpublished key is unknown")
	_check(not platform.set_achievement("UNKNOWN_KEY") and not platform.set_achievement("bad/key"), "Unknown or malformed keys never sent")
	_check(gateway.set_calls == 0, "Invalid achievement writes blocked")
	_check(platform.set_achievement("FIRST_SEED"), "Local unlock accepted")
	_check(platform.query_achievement("FIRST_SEED").pending and not platform.query_achievement("FIRST_SEED").achieved, "Unstored in-memory unlock is not remote acknowledgement")
	_check(platform.store_achievements() and platform.get_status().store_pending, "Store waits for callback")
	_check(acknowledgements.is_empty(), "Store true is not acknowledgement")
	_check(not platform.store_achievements() and not platform.set_achievement("FIRST_WAVE"), "Concurrent batch writes blocked")
	gateway.user_stats_stored.emit(480, 1)
	_check(platform.get_status().store_pending and acknowledgements.is_empty(), "Wrong app callback ignored")
	gateway.user_stats_stored.emit(3721150, 1)
	_check(acknowledgements == [true] and platform.query_achievement("FIRST_SEED").achieved, "Success callback acknowledges batch")
	gateway.user_stats_stored.emit(3721150, 1)
	_check(acknowledgements.size() == 1, "Duplicate callback ignored")
	gateway.overlay_toggled.emit(true, true, 3721150)
	gateway.overlay_toggled.emit(false, true, 480)
	_check(overlays == [true], "Overlay routes only matching app")
	gateway.cloud_app = false
	platform.pump(1.0)
	_check(not platform.get_status().cloud_enabled and gateway.callbacks == 1, "Cloud toggle refresh and manual callbacks")
	gateway.cloud_app = true
	gateway.cloud_account = false
	platform.pump(1.0)
	_check(not platform.get_status().cloud_enabled, "Account Cloud disabled respected")

	_check(platform.set_achievement("FIRST_WAVE"), "Second batch staged")
	gateway.store_result = false
	_check(not platform.store_achievements(), "Immediate storage failure returned")
	var failed_calls := gateway.store_calls
	_check(not platform.store_achievements() and gateway.store_calls == failed_calls, "Failed store uses backoff")
	_check(not platform.query_achievement("FIRST_WAVE").achieved, "Failed store remains pending")
	platform.pump(61)
	gateway.store_result = true
	_check(platform.store_achievements(), "Known failed request can retry after backoff")
	gateway.user_stats_stored.emit(3721150, 2)
	_check(acknowledgements == [true, false] and not platform.get_status().store_pending, "Callback failure keeps queue unacknowledged")
	platform.pump(61)
	_check(platform.store_achievements(), "Explicit callback failure may retry")
	platform.pump(31)
	_check(acknowledgements == [true, false, false] and not platform.get_status().ready, "Unknown timeout freezes session for safe next-launch retry")
	gateway.user_stats_stored.emit(3721150, 1)
	gateway.user_stats_received.emit(3721150, 1, gateway.user_id)
	_check(not platform.get_status().ready and not platform.set_achievement("FIRST_SEED"), "Late timeout callback cannot acknowledge new batch")
	platform.shutdown()
	_check(gateway.shutdown_calls == 1, "Native resources closed once")
	platform.shutdown()
	_check(gateway.shutdown_calls == 1, "Shutdown idempotent")
	platform.free()

	for failure_mode in ["init", "wrong_app", "no_user", "switch_user", "switch_app", "unload", "disconnect"]:
		gateway = MockSteam.new()
		platform = Platform.new()
		if failure_mode == "init": gateway.init_status = 2
		if failure_mode == "wrong_app": gateway.app_id = 480
		if failure_mode == "no_user": gateway.user_id = 0
		status = platform.initialize(gateway, _context())
		if failure_mode in ["init", "wrong_app", "no_user"]:
			_check(not status.available and gateway.set_calls == 0, "Initialization failure remains local: " + failure_mode)
		else:
			platform.set_achievement("FIRST_SEED")
			platform.store_achievements()
			var before := gateway.set_calls
			if failure_mode == "switch_user": gateway.user_id += 1
			if failure_mode == "switch_app": gateway.app_id = 480
			if failure_mode == "unload": gateway.user_stats_unloaded.emit(gateway.user_id)
			if failure_mode == "disconnect": gateway.steam_shutdown.emit()
			_check(not platform.set_achievement("FIRST_WAVE") and gateway.set_calls == before, "No wrong-account writes: " + failure_mode)
			_check(not platform.get_status().available, "Identity loss disables gateway: " + failure_mode)
		platform.shutdown()
		platform.free()
	if failures.is_empty():
		print("STEAM_PLATFORM_TESTS_OK %d checks; mock-only, no Steam account writes" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
