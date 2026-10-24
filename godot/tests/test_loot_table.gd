extends SceneTree
const Run = preload("res://scripts/run.gd")
const Table = preload("res://scripts/loot_table.gd")
var checks := 0
var failures := 0
var table
var game
var signals_seen := 0
var gear_signals := 0
var earned_items: Array = []

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
	var image: Image = root.get_texture().get_image()
	var path := "res://build/render-checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	image.save_png(path.path_join(name+".png"))

func exercise() -> void:
	root.size = Vector2i(1100,650)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if "--canvas-graphics" in OS.get_cmdline_user_args(): root.disable_3d = true
	game = Run.new()
	game.new_run(54321)
	game.phase = "loot"
	game.fragments = 100
	game.credits = 100
	for rarity in ["common","uncommon","rare","epic","legendary","rare","common"]: game._add_chest(rarity)
	table = Table.new()
	root.add_child(table)
	table.position = Vector2(20,20)
	table.size = Vector2(1060,610)
	table.setup(game,true)
	table.changed.connect(func(_result): signals_seen += 1; table.refresh())
	table.gear_requested.connect(func(items): gear_signals += 1; earned_items = items)
	await frames(5)
	check(table._cards.size()==6,"Loot table pages its chest previews rather than rendering an unbounded inventory")
	check(table._next != null and not table._next.disabled,"More than six chests expose a next-page control")
	check(table.preferred_focus()!=null,"Controller can reach an available chest")
	await screenshot("loot-table-deck")
	var legendary: Dictionary = game.chests[4].duplicate()
	var before: int = game.items.size()
	var fragments: int = game.fragments
	table.open_chest(legendary.id)
	check(table.opening,"Opening starts an animation before the reward view")
	check(game.fragments==fragments-int(legendary.cost),"Opening spends the advertised fragments once")
	check(game.items.size()==before+3,"Legendary chest grants all three items atomically")
	check(table.reward.rewards.size()==3,"Persistent reveal remembers every granted reward")
	for i in range(5): table.open_chest(legendary.id)
	check(signals_seen==1 and game.items.size()==before+3,"Repeated chest taps during animation do not emit or grant again")
	table.hide()
	table.refresh()
	await create_timer(0.22).timeout
	check(not table.opening and table._reward_cards.size()==3,"Closing or refreshing cannot discard an opening's rewards")
	table.show()
	await frames()
	check(table._hero._opened,"Completed reward view shows the hinged-open chest pose")
	check(table.preferred_focus()==table._equip,"Reward view has a deliberate controller focus target")
	for card in table._reward_cards:
		check(Rect2(Vector2.ZERO,table.size).encloses(card.get_rect()),"Every reward card fits inside the reveal screen")
	await screenshot("loot-reveal-deck")
	root.size = Vector2i(680,1050)
	table.size = Vector2(640,1010)
	await frames(5)
	for card in table._reward_cards:
		check(Rect2(Vector2.ZERO,table.size).encloses(card.get_rect()),"Every reward is visible in the portrait reveal")
	await screenshot("loot-reveal-portrait")
	root.size = Vector2i(1100,400)
	table.size = Vector2(1060,352)
	await frames(5)
	for card in table._reward_cards:
		check(card.get_rect().end.y <= table._footer.position.y,"All rewards fit above the actions in a short landscape window")
	await screenshot("loot-reveal-short")
	table.open_chest(game.chests[0].id)
	check(game.items.size()==before+3,"Unacknowledged rewards block opening another chest")
	var earned_ids: Array = table.reward.rewards.map(func(item): return item.id)
	table._equip.pressed.emit()
	check(gear_signals==1 and earned_items.map(func(item): return item.id)==earned_ids,"Equip new gear hands every earned item identity to the inventory")
	check(table.reward.is_empty(),"Equip new gear acknowledges the completed reveal")
	table._request_new_gear()
	check(gear_signals==1,"Repeated equipment handoff cannot reopen stale loot")
	await frames(5)
	check(table._cards.size()==3,"Short landscape uses three generous chest previews per page")
	for card in table._cards:
		check(card.get_rect().end.y <= table._previous.position.y,"Short landscape previews do not overlap paging controls")
	await screenshot("loot-table-short")
	root.size = Vector2i(680,1050)
	table.size = Vector2(640,1010)
	await frames(5)
	check(table.reward.is_empty() and table._cards.size()==6,"Acknowledging rewards returns to the remaining chest table")
	check(game.items.size()==before+3,"Acknowledging does not grant items a second time")
	game.fragments = 0
	table.refresh()
	var remaining: int = game.chests.size()
	var locked: int = game.chests[0].id
	table.open_chest(locked)
	check(game.chests.size()==remaining and game.fragments==0,"Insufficient fragments leave chest and balance unchanged")
	check(not table.opening and table.reward.is_empty(),"Failed opening cannot leave a reveal locked")
	check(table._cards[0].disabled,"Unaffordable chest is visibly locked")
	game.fragments = 100
	game.phase = "battle"
	table.refresh()
	table.open_chest(locked)
	check(game.chests.size()==remaining,"Battle phase cannot open a chest through the presentation")
	game.phase = "prep"
	table.set_reduced_motion(false)
	table.refresh()
	table.open_chest(locked)
	table.reset_for_run()
	await create_timer(0.85).timeout
	check(not table.opening and table.reward.is_empty(),"Reset invalidates an in-flight reveal callback")
	check(not is_instance_valid(table._equip),"Old run's reveal never reappears after reset")
	table.queue_free()
	await frames()
	print("LOOT_TABLE_CHECKS: %d assertions, %d failures" % [checks,failures])
	print("LOOT_TABLE_PASS" if failures==0 else "LOOT_TABLE_FAIL")
	quit(1 if failures else 0)
