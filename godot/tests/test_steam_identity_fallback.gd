extends SceneTree
## Real Main admission paths, explicit Steam fake, disposable profile base.
const Platform = preload("res://scripts/steam_platform.gd")
const Run = preload("res://scripts/run.gd")
const Save = preload("res://scripts/run_save.gd")
const Achievements = preload("res://scripts/achievement_profile.gd")
var checks := 0
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var scene

class FakeSteam extends RefCounted:
	signal user_stats_stored(game_id: int, result: int)
	signal user_stats_received(game_id: int, result: int, user_id: int)
	signal user_stats_unloaded(user_id: int)
	signal steam_shutdown
	signal overlay_toggled(active: bool, user_initiated: bool, app_id: int)
	var user_id := 76561198000000001
	var app_id := 3721150
	var init_calls := 0
	var cloud_calls := 0
	var set_calls := 0
	var store_calls := 0
	var shutdown_calls := 0
	func steamInitEx(app: int, embed: bool) -> Dictionary:
		assert(app == 0 and not embed)
		init_calls += 1
		return {"status":0}
	func getAppID() -> int: return app_id
	func getSteamID() -> int: return user_id
	func run_callbacks() -> void: pass
	func getAchievement(_key: String) -> Dictionary: return {"ret":true,"achieved":false}
	func setAchievement(_key: String) -> bool:
		set_calls += 1
		return true
	func storeStats() -> bool:
		store_calls += 1
		return true
	func isCloudEnabledForAccount() -> bool:
		cloud_calls += 1
		return true
	func isCloudEnabledForApp() -> bool:
		cloud_calls += 1
		return true
	func steamShutdown() -> void: shutdown_calls += 1

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func frames(count := 4) -> void:
	for i in range(count): await process_frame

func context() -> Dictionary:
	return {"native_export":true,"editor":false,"headless":false,"disabled":false,"arguments":[],"steam_app_id":"3721150","steam_game_id":"3721150"}

func create_scene(label: String, seed_value: int) -> Dictionary:
	var folder := "user://identity-fallback-" + label
	check(DirAccess.make_dir_recursive_absolute(folder) == OK,label + " isolated fixture folder")
	var run = Run.new()
	run.new_run(seed_value,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy","achievement_run_id":"synthetic-identity-"+label})
	var cell: int = run.board.find(0)
	check(run.place(cell,run.solution[cell]).ok,label + " fixture legal placement")
	var store = Save.new()
	store.file_path = folder.path_join("sudoku-defense-run.json")
	check(store.write_run(run.save_data()),label + " fixture save written")
	var original := FileAccess.get_file_as_string(store.file_path)
	scene = load("res://scenes/main.tscn").instantiate()
	# Keep RunSave's default path until Main configures it, avoiding the older
	# injected-run-path test shortcut and exercising ordinary profile selection.
	scene._profile_base = folder
	scene.preferences.file_path = folder.path_join("settings.json")
	root.add_child(scene)
	scene.set_process(false)
	await frames()
	check(scene.cloud_profile_status.ok and not scene.cloud_profile_status.scoped,label + " headless fixture starts local")
	return {"folder":folder,"path":store.file_path,"original":original,"seed":seed_value}

func install_fake(fake: FakeSteam) -> Dictionary:
	# Main's real startup ran under --no-steam and never initialized a native
	# singleton. Replace that disabled node with this explicit fake adapter.
	scene.steam_platform.free()
	var adapter := Platform.new()
	scene.steam_platform = adapter
	scene.add_child(adapter)
	return adapter.initialize(fake,context())

func missing_identity(value: int) -> void:
	var before := failures.size()
	var label := "zero" if value == 0 else "negative"
	var fixture: Dictionary = await create_scene(label,8100 if value == 0 else 8101)
	var fake := FakeSteam.new()
	fake.user_id = value
	var status: Dictionary = install_fake(fake)
	check(not status.available and not status.ready and status.status == "steam_account_unavailable",label + " invalid startup account unavailable")
	check(str(status.account_id).is_empty(),label + " unverified startup account is not published")
	check(fake.init_calls == 1 and fake.shutdown_calls == 1,label + " initialized native fake shut down once")
	scene._configure_profiles(status)
	var configured: Dictionary = scene.cloud_profile_status.duplicate(true)
	check(configured.get("ok",false) and not configured.get("scoped",false),label + " Main keeps ordinary local profile usable")
	check(scene.run_save.file_path == fixture.path,label + " Main keeps existing local run path")
	var loaded: bool = scene._load()
	check(loaded and scene.has_active_run and scene.run.seed_value == fixture.seed,label + " actual Main load continues existing local run")
	var can_start: bool = scene._can_replace_saved_run()
	check(can_start,label + " actual Main New Run admission succeeds")
	check(FileAccess.get_file_as_string(fixture.path) == fixture.original,label + " load/admission preserves original bytes")
	var intended_seed := 8200 if value == 0 else 8201
	if is_instance_valid(scene.seed_input): scene.seed_input.text = str(intended_seed)
	scene._start_run()
	await frames()
	check(scene.has_active_run and scene.run.seed_value == intended_seed,label + " actual New Run action works locally")
	var reread = Save.new()
	reread.file_path = fixture.path
	var saved: Dictionary = reread.read_run()
	check(not saved.is_empty() and int(saved.data.state.seed_value) == intended_seed,label + " new local run persists")
	check(FileAccess.file_exists(fixture.path + ".bak") and FileAccess.get_file_as_string(fixture.path + ".bak") == fixture.original,label + " previous local run remains exact recovery backup")
	check(fake.cloud_calls == 0 and fake.set_calls == 0 and fake.store_calls == 0,label + " invalid startup never queries Cloud or awards")
	cases.append({"name":label,"returned_status":status,"configured_profile":configured,"load_result":loaded,"can_start":can_start,"final_seed":scene.run.seed_value,"failures":failures.size()-before})
	scene.queue_free()
	await frames()
	check(fake.shutdown_calls == 1,label + " Main exit does not shutdown fake twice")

func verified_disconnect() -> void:
	var before := failures.size()
	var fixture: Dictionary = await create_scene("verified",8300)
	var fake := FakeSteam.new()
	var status: Dictionary = install_fake(fake)
	check(status.available and status.account_id == str(fake.user_id),"verified account publishes identity")
	scene._configure_profiles(status)
	check(scene.cloud_profile_status.ok and scene.cloud_profile_status.scoped,"verified account chooses scoped profile")
	var scoped_path: String = scene.run_save.file_path
	check(scoped_path.contains("/steam/" + str(fake.user_id) + "/cloud/run.json"),"verified account scope uses its own ID")
	scene.run.new_run(8301,{"mode":"campaign","puzzle_difficulty":"easy","combat_difficulty":"easy","achievement_run_id":"synthetic-identity-verified-offline"})
	scene.has_active_run = true
	check(scene._save(),"verified scoped run saves")
	var original_scoped := FileAccess.get_file_as_string(scoped_path)
	fake.steam_shutdown.emit()
	var offline: Dictionary = scene.steam_platform.get_status()
	check(not offline.available and offline.account_id == str(fake.user_id),"later disconnect retains already-verified account")
	scene._configure_profiles(offline)
	check(scene.cloud_profile_status.ok and scene.cloud_profile_status.scoped and scene.run_save.file_path == scoped_path,"reconfiguration after disconnect keeps scoped path")
	check(scene._load() and scene.run.seed_value == 8301,"offline verified account continues its own saved run")
	check(scene._can_replace_saved_run(),"offline verified account can start another run")
	check(FileAccess.get_file_as_string(scoped_path) == original_scoped,"offline admission preserves scoped save")
	var cell: int = scene.run.board.find(0)
	check(scene.run.place(cell,scene.run.solution[cell]).ok and scene._save(),"offline verified account records new gameplay evidence")
	check(scene.achievements.pending_keys() == ["SD_FIRST_PLANT"] and scene.achievements.confirmed.is_empty(),"offline evidence remains pending for its verified account")
	var reloaded = Achievements.new()
	check(reloaded.configure(str(scene.cloud_profile_status.achievement_path),"",str(fake.user_id)).ok and reloaded.pending_keys() == ["SD_FIRST_PLANT"],"offline verified queue survives fresh profile")
	check(fake.set_calls == 0 and fake.store_calls == 0,"offline verified account submits no awards")
	check(FileAccess.get_file_as_string(fixture.path) == fixture.original,"scoped operations preserve ordinary local original")
	reloaded.close()
	cases.append({"name":"verified-disconnect","returned_status":offline,"scoped_path":scoped_path,"failures":failures.size()-before})
	scene.queue_free()
	await frames()
	check(fake.shutdown_calls == 1,"verified session shuts down once on exit")

func exercise() -> void:
	await missing_identity(0)
	await verified_disconnect()
	var result := {"checks":checks,"failures":failures,"cases":cases,"fake_only":true}
	var file := FileAccess.open("user://identity-fallback-results.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result,"  ",true,true))
		file.close()
	else: failures.append("Cannot retain identity result")
	for failure in failures: print("FAIL: " + failure)
	print("STEAM_IDENTITY_FALLBACK: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
