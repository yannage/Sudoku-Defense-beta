extends SceneTree
## Exercise real ownership, balances and presentation across repeated input.
const Run = preload("res://scripts/run.gd")
const Loot = preload("res://scripts/loot.gd")
const Table = preload("res://scripts/loot_table.gd")
const Preferences = preload("res://scripts/preferences.gd")
var checks := 0
var failures := 0
var signals_seen := 0
var handed_off: Array = []

func _initialize() -> void:
	call_deferred("exercise")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 3) -> void:
	for i in range(count): await process_frame

func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := "res://build/loot-batch-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	root.get_texture().get_image().save_png(path.path_join(name+".png"))

func make_run():
	var game = Run.new()
	game.new_run(54321,{"achievement_run_id":"isolated-loot-batch-test"})
	for cell in range(81):
		if game.board[cell] == 0:
			game.place(cell,game.solution[cell])
			break
	return game

func test_batch_equipment() -> void:
	var game = make_run()
	var cell: int = int(game.towers.keys()[0])
	var first: int = game.items[0].id
	var second: int = game.items[1].id
	var before: Dictionary = game.save_data()
	check(not game.equip_items(cell,[]).ok,"Empty selections are rejected")
	check(not game.equip_items(cell,[first,str(first)]).ok,"The same item cannot occupy two sockets through mixed ID types")
	check(not game.equip_items(cell,[first,-999]).ok,"A stale selected item rejects the whole batch")
	check(not game.equip_items(cell,[first,game.items[3].id]).ok,"Consumables cannot be installed as modules")
	check(game.save_data() == before,"Rejected batches leave inventory, sockets and RNG unchanged")
	game.phase = "lost"
	check(not game.equip_items(cell,[first]).ok,"Finished loss cannot move gear")
	game.phase = "solve"
	var result: Dictionary = game.equip_items(cell,[str(first),second])
	check(result.ok and result.items.size() == 2 and int(result.cell) == cell,"Batch result describes the selected tower and modules")
	check(game.towers[cell].attachments.map(func(item): return item.id) == [first,second],"Successful batch preserves selection order in empty sockets")
	check(game.items.size() == 2,"Every installed module leaves the inventory once")
	check(game.achievement_stats.counters.module_equips == 2 and game.achievement_stats.earned.has("SD_FIRST_MODULE"),"Batch installation records each module and earns the first module achievement")
	before = game.save_data()
	check(not game.equip_items(cell,[first,second]).ok and game.save_data() == before,"Repeated install cannot duplicate modules or mutate ownership")
	var extra_ids: Array = []
	for i in range(4):
		var id: int = game._id()
		extra_ids.append(id)
		game.items.append(Loot.make_item(game.rng,"rare",1,id,"power"))
	before = game.save_data()
	check(not game.equip_items(cell,extra_ids).ok and game.save_data() == before,"An oversized batch does not partially fill the tower")
	check(game.equip_items(cell,extra_ids.slice(0,3)).ok and game.towers[cell].attachments.size() == 5,"A batch fills exactly the remaining slots")
	check(game.achievement_stats.counters.module_equips == 5 and game.achievement_stats.earned.has("SD_FIVE_SOCKETS") and game.achievement_stats.earned.has("SD_STACK_MODULES") and game.achievement_stats.earned.has("SD_THREE_EFFECTS"),"Batch installation preserves full-socket, stacking and effect achievements")
	before = game.save_data()
	check(not game.equip_items(cell,[extra_ids[3]]).ok and game.save_data() == before,"Full towers never overwrite an installed module")
	var restored = Run.new()
	check(restored.load_data(game.save_data()),"Batch-equipped run reloads through the normal save format")
	check(restored.towers[cell].attachments == game.towers[cell].attachments and restored.items == game.items,"Reload preserves unique module ownership")
	check(restored.achievement_stats == game.achievement_stats,"Batch equipment achievements survive run recovery")

func test_chest_economy() -> void:
	var game = make_run()
	game.phase = "loot"
	game.fragments = 12
	var expensive: Dictionary = game._add_chest("legendary")
	game._add_chest("common")
	game._add_chest("uncommon")
	var plan: Dictionary = game.chest_open_plan()
	check(int(plan.count) == 2 and int(plan.cost) == 12 and int(plan.remaining_count) == 1,"Open All previews exactly what the balance can afford")
	var before_count: int = game.items.size()
	var result: Dictionary = game.open_all_chests()
	check(result.ok and int(result.opened_count) == 2 and int(result.spent_fragments) == 12,"Open All spends exactly the advertised fragment cost")
	check(game.fragments == 0 and game.chests.size() == 1 and game.chests[0].id == expensive.id,"Unaffordable chests remain available and do not block affordable ones")
	check(game.items.size() == before_count + 2 and result.rewards.size() == 2,"All batch rewards are added to inventory once")
	check(game.achievement_stats.counters.chests_opened == 2 and game.achievement_stats.earned.has("SD_FIRST_CHEST"),"Open All retains per-chest achievement accounting")
	var before: Dictionary = game.save_data()
	check(not game.open_all_chests().ok and game.save_data() == before,"Repeated Open All with no affordable chests cannot grant or spend again")
	game.fragments = 20
	game.phase = "battle"
	before = game.save_data()
	check(game.chest_open_plan().count == 0,"Battle never advertises available openings")
	check(not game.open_all_chests().ok and game.save_data() == before,"Battle rejects the entire opening without RNG or currency changes")
	game.phase = "won"
	result = game.open_all_chests()
	check(result.ok and result.rewards.size() == 3 and result.rarity == "legendary","Victory rewards can be opened and retain rarity-specific reward counts")
	var restored = Run.new()
	check(restored.load_data(game.save_data()) and restored.chests.is_empty() and restored.items == game.items,"A save immediately after opening preserves every reward and consumed chest")
	check(game.achievement_stats.counters.chests_opened == 3 and restored.achievement_stats == game.achievement_stats,"Chest accounting survives repeated input and run recovery")

func test_preferences() -> void:
	var store = Preferences.new()
	store.file_path = "user://batch-loot-preference-test.json"
	DirAccess.remove_absolute(store.file_path)
	check(not store.read_settings().auto_open_chests,"Automatic opening is an opt-in preference")
	var settings: Dictionary = store.read_settings()
	settings.auto_open_chests = true
	check(store.write_settings(settings) and store.read_settings().auto_open_chests,"Automatic opening persists independently of a run")
	settings.auto_open_chests = "true"
	check(store.write_settings(settings) and not store.read_settings().auto_open_chests,"Invalid preference types use the safe default")
	DirAccess.remove_absolute(store.file_path)

func test_reward_screen() -> void:
	root.size = Vector2i(1100,400)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if "--canvas-graphics" in OS.get_cmdline_user_args(): root.disable_3d = true
	var game = make_run()
	game.phase = "loot"
	game.fragments = 1000
	for rarity in ["legendary","rare","common","epic","uncommon"]: game._add_chest(rarity)
	var table = Table.new()
	root.add_child(table)
	table.position = Vector2(20,20)
	table.size = Vector2(1060,352)
	table.setup(game,true)
	table.changed.connect(func(_result): signals_seen += 1; table.refresh())
	table.gear_requested.connect(func(items): handed_off = items)
	await frames(5)
	check(is_instance_valid(table._open_all) and not table._open_all.disabled,"Open All is a reachable action with affordable chests")
	check(Rect2(Vector2.ZERO,table.size).encloses(table._open_all.get_rect()),"Open All fits inside the short landscape view")
	check(not table._open_all.get_rect().intersects(table._buy.get_rect()),"Open All and Buy have separate click targets")
	await screenshot("open-all-short")
	var before_count: int = game.items.size()
	table._open_all.pressed.emit()
	for i in range(5): table.open_all_chests()
	check(signals_seen == 1 and game.chests.is_empty(),"Repeated UI input during batch opening commits only once")
	check(game.items.size() == before_count + 9 and table.reward.rewards.size() == 9,"Combined reveal remembers all rewards from all chests")
	table.hide()
	table.refresh()
	await create_timer(0.22).timeout
	table.show()
	await frames()
	check(not table.opening and table._reward_cards.size() == 3,"Large reward batches use readable pages in one reveal")
	await screenshot("batch-rewards-short")
	var seen: Array = []
	for page in range(3):
		for card in table._reward_cards:
			seen.append(str(card.get_meta("reward_item_id")))
			check(card.get_rect().end.y <= table._footer.position.y,"Reward cards stay above the footer in short landscape")
		check(not table._reward_next.get_rect().intersects(table._equip.get_rect()),"Reward paging never overlaps the equip action")
		if page < 2:
			table._reward_next.pressed.emit()
			await frames()
	check(seen.size() == 9 and seen == table.reward.rewards.map(func(item): return str(item.id)),"Every recovered reward is inspectable without reopening a chest")
	root.size = Vector2i(680,1050)
	table.size = Vector2(640,1010)
	await frames()
	for card in table._reward_cards:
		check(Rect2(Vector2.ZERO,table.size).encloses(card.get_rect()),"Combined rewards fit the portrait layout")
	await screenshot("batch-rewards-portrait")
	var rewarded_ids: Array = table.reward.rewards.map(func(item): return item.id)
	table._equip.pressed.emit()
	check(handed_off.map(func(item): return item.id) == rewarded_ids,"One equip action hands off the entire batch, including other pages")
	check(table.reward.is_empty() and game.items.size() == before_count + 9,"Acknowledging the combined reveal does not grant twice")
	table.queue_free()
	await frames()

func exercise() -> void:
	test_batch_equipment()
	test_chest_economy()
	test_preferences()
	await test_reward_screen()
	print("LOOT_BATCH_PASS: %d checks / %d failures" % [checks,failures])
	quit(1 if failures else 0)
