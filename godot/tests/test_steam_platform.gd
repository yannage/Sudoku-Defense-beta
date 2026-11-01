extends SceneTree

const Platform = preload("res://scripts/steam_platform.gd")
const Profile = preload("res://scripts/achievement_profile.gd")
var checks := 0
var failures: Array[String] = []

class Evidence extends RefCounted:
	var achievement_stats := {"run_id": "synthetic-platform-restart", "earned": {}}

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
	var on_query: Callable
	var achievements := {"FIRST_SEED": false, "FIRST_WAVE": false, "ALREADY_EARNED": true}
	func steamInitEx(app: int, embed: bool) -> Dictionary:
		assert(app == 0 and not embed)
		init_calls += 1
		return {"status": init_status}
	func getAppID() -> int: return app_id
	func getSteamID() -> int: return user_id
	func run_callbacks() -> void: callbacks += 1
	func getAchievement(key: String) -> Dictionary:
		if on_query.is_valid(): on_query.call(key)
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
	_check_read_identity_changes()
	_check_detached_gateway_events()
	_check_profile_timeout_restart()
	if failures.is_empty():
		print("STEAM_PLATFORM_TESTS_OK %d checks; mock-only, no Steam account writes" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)


func _check_read_identity_changes() -> void:
	for identity in ["account", "app"]:
		var gateway := MockSteam.new()
		var platform := Platform.new()
		platform.initialize(gateway, _context())
		gateway.on_query = func(_key: String):
			if identity == "account": gateway.user_id += 1
			else: gateway.app_id = 480
		var answer := platform.query_achievement("ALREADY_EARNED")
		_check(not answer.known and not answer.achieved, "Identity change during achievement read rejects returned evidence: " + identity)
		_check(not platform.get_status().available, "Identity change during read immediately disables gateway: " + identity)
		gateway.on_query = Callable()
		platform.shutdown()
		platform.free()
	# Exercise the real profile/adapter boundary: no real Steam singleton is
	# initialized, and every fixture is inside this process's disposable user://.
	var gateway := MockSteam.new()
	var platform := Platform.new()
	platform.initialize(gateway, _context())
	var profile = Profile.new()
	var path := "user://identity-read-%s-%s.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	_check(profile.configure(path, "", str(gateway.user_id)).ok, "Identity-read fixture opens")
	for entry: Dictionary in profile.entries(): gateway.achievements[str(entry.id)] = false
	gateway.on_query = func(key: String):
		if key == "SD_FIRST_PLANT":
			gateway.user_id += 1
			gateway.achievements[key] = true
	_check(not profile.synchronize(platform), "Account switch during reconciliation cancels sync")
	_check(profile.unlocked.is_empty() and profile.confirmed.is_empty(), "New account's returned unlock cannot pollute previous account in memory")
	_check(not FileAccess.file_exists(path), "New account's returned unlock cannot create previous account's durable evidence")
	_check(gateway.set_calls == 0 and gateway.store_calls == 0, "Interrupted identity read never submits achievements")
	gateway.on_query = Callable()
	profile.close()
	platform.shutdown()
	platform.free()


func _check_detached_gateway_events() -> void:
	var gateway := MockSteam.new()
	var platform := Platform.new()
	var acknowledgements: Array = []
	platform.stats_stored.connect(func(ok: bool): acknowledgements.append(ok))
	platform.initialize(gateway, _context())
	platform.set_achievement("FIRST_SEED")
	platform.store_achievements()
	gateway.user_stats_received.emit(480, 2, gateway.user_id)
	gateway.user_stats_received.emit(3721150, 2, gateway.user_id + 1)
	gateway.user_stats_unloaded.emit(gateway.user_id + 1)
	_check(platform.get_status().ready and platform.get_status().store_pending, "Foreign app/user stats events leave the active batch untouched")
	platform.shutdown()
	var replacement := MockSteam.new()
	platform.initialize(replacement, _context())
	platform.set_achievement("FIRST_WAVE")
	platform.store_achievements()
	gateway.user_stats_stored.emit(3721150, 1)
	gateway.user_stats_received.emit(3721150, 2, gateway.user_id)
	gateway.user_stats_unloaded.emit(gateway.user_id)
	gateway.steam_shutdown.emit()
	_check(platform.get_status().ready and platform.get_status().store_pending and acknowledgements.is_empty(), "Detached same-account gateway cannot confirm or disable the replacement session")
	replacement.user_stats_stored.emit(3721150, 1)
	replacement.user_stats_stored.emit(3721150, 2)
	_check(acknowledgements == [true], "Active gateway acknowledges once; out-of-order failure with no batch is ignored")
	platform.shutdown()
	platform.free()


func _check_profile_timeout_restart() -> void:
	var profile = Profile.new()
	var path := "user://timeout-restart-%s-%s.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var gateway := MockSteam.new()
	for entry: Dictionary in profile.entries(): gateway.achievements[str(entry.id)] = false
	var platform := Platform.new()
	platform.initialize(gateway, _context())
	_check(profile.configure(path, "", str(gateway.user_id)).ok, "Timeout restart fixture opens")
	var evidence := Evidence.new()
	evidence.achievement_stats.earned["SD_FIRST_PLANT"] = true
	_check(profile.observe_run(evidence) and profile.synchronize(platform), "Timeout fixture queues durable first achievement")
	platform.pump(31.0)
	evidence.achievement_stats.earned["SD_FIRST_MODULE"] = true
	_check(profile.observe_run(evidence), "Later achievement remains durable during frozen Steam session")
	gateway.user_stats_stored.emit(3721150, 1)
	gateway.user_stats_received.emit(3721150, 1, gateway.user_id)
	gateway.user_stats_stored.emit(3721150, 2)
	platform.pump(90.0)
	profile.pump(90.0)
	_check(gateway.store_calls == 1 and not platform.get_status().ready, "Timeout plus late/out-of-order callbacks cannot start another ambiguous batch")
	_check(profile.pending_keys().size() == 2 and profile.confirmed.is_empty(), "Timeout callbacks cannot confirm first or later evidence")
	profile.close()
	platform.shutdown()
	platform.free()
	# A fresh launch can distinguish remotely recorded evidence from the lost
	# prior session's volatile cache. Simulate the first request reaching Steam.
	var restarted = Profile.new()
	_check(restarted.configure(path, "", str(gateway.user_id)).ok and restarted.pending_keys().size() == 2, "Both offline keys survive timeout and process-profile restart")
	var replacement := MockSteam.new()
	for entry: Dictionary in restarted.entries(): replacement.achievements[str(entry.id)] = false
	replacement.achievements["SD_FIRST_PLANT"] = true
	platform = Platform.new()
	platform.initialize(replacement, _context())
	_check(restarted.synchronize(platform), "New session reconciles recorded first key and submits later key")
	_check(replacement.set_calls == 1 and replacement.store_calls == 1 and restarted.pending_keys() == ["SD_FIRST_MODULE"], "Restart submits only unconfirmed evidence; known remote key is not duplicated")
	replacement.user_stats_stored.emit(3721150, 1)
	_check(restarted.pending_keys().is_empty(), "Restart callback confirms the remaining batch")
	var durable = Profile.new()
	_check(durable.configure(path, "", str(replacement.user_id)).ok and durable.confirmed.size() == 2, "Restart acknowledgement is durable for both keys")
	restarted.close()
	platform.shutdown()
	platform.free()
