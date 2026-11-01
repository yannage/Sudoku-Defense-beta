extends SceneTree

const Run = preload("res://scripts/run.gd")
const Loot = preload("res://scripts/loot.gd")
const Rules = preload("res://scripts/achievement_rules.gd")
const Facts = preload("res://scripts/achievement_facts.gd")
var checks: int = 0
var failures: Array[String] = []
var rule_coverage: Dictionary = {}

func _initialize() -> void:
	_catalog()
	_placements()
	_gear_and_spending()
	_wave_rules()
	_campaign_rules()
	_save_and_exclusions()
	_rule_matrix()
	var evidence := FileAccess.open("user://achievement-rule-coverage.json",FileAccess.WRITE)
	if evidence != null:
		evidence.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"rules":rule_coverage},"\t"))
		evidence.close()
	if failures.is_empty():
		print("ACHIEVEMENT_RULES_PASS: %d achievement checks; 26 positive + 26 negative rule cases, durable evidence, legacy history, isolated IDs, no Steam calls" % checks)
		quit(0)
	else:
		for failure in failures: push_error(failure)
		print("FAIL: %d/%d achievement checks" % [failures.size(),checks])
		quit(1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _game(options: Dictionary = {}) -> RefCounted:
	var run = Run.new()
	var merged: Dictionary = {"achievement_run_id":"isolated-unit-test"}
	merged.merge(options,true)
	run.new_run(875,merged)
	return run

func _has(run: RefCounted, key: String) -> bool:
	return Rules.evaluate(run).has("SD_"+key)

func _blank(run: RefCounted) -> int:
	return run.board.find(0)

func _plant(run: RefCounted) -> int:
	var cell: int = _blank(run)
	run.place(cell,run.solution[cell])
	return cell

func _fill(run: RefCounted, hints: bool = false) -> void:
	run.credits = 100000
	while _blank(run) >= 0:
		var cell: int = _blank(run)
		if hints: run.hint(cell)
		else: run.place(cell,run.solution[cell])

func _battle(run: RefCounted, number: int = -1) -> void:
	if number > 0 and number != run.round_no:
		run.round_no = number
		run._new_board()
	if run.phase == "solve": run.advance_phase()
	if run.phase == "prep": run.advance_phase()

func _settle(run: RefCounted) -> void:
	run.spawned = run.spawn_total
	run.enemies.clear()
	run._finish_wave()

func _enemy(run: RefCounted, kind: String = "boss", leak: bool = false) -> Dictionary:
	var enemy: Dictionary = {"id":9000,"pos":run.route[0],"hp":1.0,"max_hp":1.0,"progress":run.route_length if leak else 0.0,"speed":1.0,"kind":kind,"slow":1.0,"slow_time":0.0,"poison_time":0.0,"poison_dps":0.0}
	return enemy

func _kill_boss(run: RefCounted) -> void:
	var enemy: Dictionary = _enemy(run)
	run._damage(enemy,2.0,Color.WHITE)
	run._damage(enemy,2.0,Color.WHITE)

func _catalog() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/achievements.json"))
	_check(catalog is Array and catalog.size() == 26,"Catalog contains 26 achievements")
	var seen: Array[String] = []
	for entry: Dictionary in catalog:
		_check(Facts.IDS.has(str(entry.id)) and not seen.has(str(entry.id)),"Catalog key known and unique")
		_check(not str(entry.name).is_empty() and not str(entry.description).is_empty() and not str(entry.icon).is_empty(),"Catalog has name, description and icon")
		seen.append(str(entry.id))
	_check(seen.size() == Facts.IDS.size(),"Catalog/rules have identical key counts")

func _placements() -> void:
	var run = _game()
	var cell: int = _blank(run)
	run.place(cell,run.solution[cell]%9+1)
	_check(not _has(run,"FIRST_PLANT") and run.achievement_stats.counters.wrong_answers == 1,"Rejected wrong answer grants no plant")
	run.hint(cell)
	_check(not _has(run,"FIRST_PLANT") and run.achievement_stats.counters.hints == 1,"Hint is durable and not a manual plant")
	_plant(run)
	_check(_has(run,"FIRST_PLANT"),"First successful manual placement")
	_fill(run)
	_check(_has(run,"FIRST_UNIT") and not _has(run,"NO_HINT_GRID"),"Manual unit earns; prior hint disqualifies grid challenge")
	_check(run.achievement_stats.current_round.board_complete and run.achievement_stats.counters.completed_boards == 1,"Full board recorded once")
	var before: Dictionary = run.achievement_stats.duplicate(true)
	run.place(0,run.solution[0])
	run.hint()
	_check(before == run.achievement_stats,"Occupied square and hint on completed board add no counters")
	run = _game({"puzzle_difficulty":"hard"})
	_fill(run,true)
	_check(_has(run,"HARD_GRID") and not _has(run,"NO_HINT_GRID") and not _has(run,"FIRST_UNIT") and not _has(run,"FIRST_PLANT"),"Hint-only hard grid earns only supported completion")
	run = _game({"puzzle_difficulty":"hard"})
	_fill(run)
	_check(_has(run,"HARD_GRID") and _has(run,"NO_HINT_GRID") and run.achievement_stats.maxima.combo > 0,"Manual hard grid and combo evidence")
	for i in range(1000): run._emit("noise")
	run.drain_events()
	_check(_has(run,"FIRST_PLANT") and _has(run,"NO_HINT_GRID"),"Awards survive capped and drained presentation events")

func _gear_and_spending() -> void:
	var run = _game()
	var cell: int = _plant(run)
	run.credits = 100000
	var number: int = run.towers[cell].number
	for i in range(4): run.upgrade_family(number)
	_check(_has(run,"FIRST_FAMILY") and _has(run,"FAMILY_FIVE"),"Family upgrade and family level5")
	_check(not _has(run,"TOWER_FIVE"),"Family levels do not impersonate individual tower level")
	for i in range(4): run.upgrade_tower(cell)
	_check(_has(run,"FIRST_UPGRADE") and _has(run,"TOWER_FIVE"),"Individual upgrades and level5")
	for i in range(5):
		var kind: String = ["rapid","rapid","frost","electric","power"][i]
		run.items.append(Loot.make_item(run.rng,"common",1,100+i,kind))
		run.equip_item(cell,100+i)
		if i == 0: _check(_has(run,"FIRST_MODULE"),"First module")
		if i == 1: _check(_has(run,"STACK_MODULES") and not _has(run,"THREE_EFFECTS"),"Duplicate-kind stack only")
		if i == 3: _check(_has(run,"THREE_EFFECTS"),"Three distinct kinds on one tower")
	_check(_has(run,"FIVE_SOCKETS"),"Five occupied sockets")
	var before: int = run.achievement_stats.counters.module_equips
	run.equip_item(cell,run.items[0].id)
	_check(run.achievement_stats.counters.module_equips == before,"Failed full-slot equip not counted")
	var chest: Dictionary = run._add_chest("common")
	run.fragments = 0
	run.open_chest(chest.id)
	_check(not _has(run,"FIRST_CHEST"),"Unpaid chest does not earn")
	run.fragments = 100
	run.open_chest(chest.id)
	run.open_chest(chest.id)
	_check(_has(run,"FIRST_CHEST") and run.achievement_stats.counters.chests_opened == 1,"Atomic chest open grants once")
	var boost_id: int = -1
	for item: Dictionary in run.items:
		if str(item.kind) == "overclock": boost_id = item.id
	run.use_item(boost_id)
	_check(not _has(run,"FIRST_BOOST"),"Rejected boost during solve does not earn")
	run.items.append(Loot.make_item(run.rng,"common",1,700,"repair"))
	run.health -= 1.0
	run.use_item(700)
	_check(not _has(run,"FIRST_BOOST"),"Repair is not a combat boost")
	_battle(run)
	run.use_item(boost_id)
	_check(_has(run,"FIRST_BOOST"),"Successful combat boost")
	before = run.achievement_stats.counters.consumables_used
	run.use_item(boost_id)
	_check(run.achievement_stats.counters.consumables_used == before,"Already used boost cannot duplicate evidence")

func _wave_rules() -> void:
	var run = _game()
	# Every family and all three priorities must exist on legal planted towers.
	var found: Array[int] = []
	for cell in range(81):
		if run.board[cell] == 0 and not found.has(run.solution[cell]):
			run.place(cell,run.solution[cell])
			found.append(run.solution[cell])
			run.set_target_priority(cell,["first","strongest","nearest"][found.size()%3])
	_battle(run)
	_settle(run)
	_check(_has(run,"FIRST_CLEAR") and _has(run,"NINE_FAMILIES") and _has(run,"TARGET_LINEUP"),"Actual wave end observes nine legal families and priorities")
	_check(_has(run,"UNFINISHED_CLEAR"),"Incomplete board is allowed and recorded after clear")
	run._finish_wave()
	_check(run.achievement_stats.waves.size() == 1,"Repeated settlement cannot duplicate durable wave record")
	run = _game()
	_battle(run,5)
	_kill_boss(run)
	_check(_has(run,"FIRST_BOSS") and run.achievement_stats.counters.boss_kills == 1,"Actual boss kill, duplicate damage guarded")
	_settle(run)
	_check(_has(run,"BOSS_WAVE_CLEAN"),"Boss wave with observed kill and zero leaks")
	run = _game()
	_battle(run,5)
	run.spawned = run.spawn_total
	run.enemies.append(_enemy(run,"boss",true))
	run.update(0.05)
	_check(run.phase == "loot" and not _has(run,"FIRST_BOSS") and not _has(run,"BOSS_WAVE_CLEAN"),"Leaked boss can clear wave but grants neither boss award")
	_check(run.achievement_stats.counters.boss_leaks == 1 and run.achievement_stats.counters.core_damage == 6,"Boss leak facts retain damage")
	run = _game()
	_battle(run,5)
	_kill_boss(run)
	run.spawned = run.spawn_total
	run.enemies.append(_enemy(run,"grunt",true))
	run.update(0.05)
	_check(run.health == run.max_health and not _has(run,"BOSS_WAVE_CLEAN"),"Wave healing cannot hide a leak for clean-boss award")
	run = _game()
	_battle(run)
	for i in range(3):
		var cell: int = _blank(run)
		var number: int = run.solution[cell]%9+1
		run.inventory[number] = 1
		run.place(cell,number)
	_settle(run)
	_check(_has(run,"CORRUPT_CLEAR") and _has(run,"UNFINISHED_CLEAR"),"Three actual illegal seeds and board after their cleanup")
	_check(run.towers.is_empty() and run.achievement_stats.counters.illegal_placements == 3,"Removed emergency towers do not erase cumulative evidence")
	run.next_round()
	_check(run.corruption == 0 and run.achievement_stats.counters.illegal_placements == 3 and run.achievement_stats.current_round.counters.illegal_placements == 0,"New board resets round evidence only")

func _campaign_rules() -> void:
	var run = _game({"mode":"freeplay"})
	_battle(run)
	_settle(run)
	_check(run.phase == "won" and not _has(run,"CAMPAIGN_CLEAR") and not _has(run,"LOCKED_CLEAR"),"Free Play won is not campaign completion")
	run = _game({"mode":"locked"})
	for number in range(1,51):
		_battle(run)
		_settle(run)
		if number == 10: _check(_has(run,"ROUND_10") and not _has(run,"ROUND_25"),"Round10 milestone")
		if number == 25: _check(_has(run,"ROUND_25") and not _has(run,"CAMPAIGN_CLEAR"),"Round25 milestone")
		if number < 50: run.next_round()
	_check(_has(run,"CAMPAIGN_CLEAR") and _has(run,"LOCKED_CLEAR") and _has(run,"CLEAN_CAMPAIGN"),"All50 actual settlements in Locked In with complete clean history")
	_check(run.achievement_stats.waves.size() == 50 and run.achievement_stats.counters.waves_cleared == 50,"Bounded50 wave records")
	run = _game()
	for number in range(1,51):
		_battle(run)
		if number == 1:
			var cell: int = _blank(run)
			run.place(cell,run.solution[cell]%9+1)
		_settle(run)
		if number < 50: run.next_round()
	_check(_has(run,"CAMPAIGN_CLEAR") and not _has(run,"CLEAN_CAMPAIGN") and not _has(run,"LOCKED_CLEAR"),"Early illegal placement remains disqualifying49 boards later")

func _save_and_exclusions() -> void:
	var run = _game()
	_plant(run)
	var data: Dictionary = JSON.parse_string(JSON.stringify(run.save_data()))
	var loaded = Run.new()
	_check(loaded.load_data(data) and _has(loaded,"FIRST_PLANT"),"Durable earned evidence survives JSON roundtrip")
	_check(loaded.achievement_stats.run_id == "isolated-unit-test","Run identity survives save/load")
	var snapshot: Dictionary = loaded.achievement_snapshot()
	snapshot.earned.clear()
	_check(_has(loaded,"FIRST_PLANT"),"Public snapshot is isolated from live facts")
	data.state.erase("achievement_stats")
	_check(loaded.load_data(data) and not loaded.achievement_stats.complete_history and Rules.evaluate(loaded).is_empty(),"Legacy run loads without invented evidence")
	_check(loaded.enable_achievement_tracking("legacy-unit-test"),"Application can attach legacy identity for future actions")
	_fill(loaded)
	_check(_has(loaded,"FIRST_PLANT") and not _has(loaded,"NO_HINT_GRID"),"Legacy future actions count; unknown hints do not become zero")
	_battle(loaded)
	_settle(loaded)
	loaded.next_round()
	_fill(loaded)
	_check(_has(loaded,"NO_HINT_GRID") and not loaded.achievement_stats.complete_history,"Newly observed legacy round can earn grid challenge; run history remains incomplete")
	for key in ["run_id","counters","current_round","earned","waves","seen","version"]:
		var broken: Dictionary = run.save_data()
		broken.state.achievement_stats[key] = "bad value!"
		_check(loaded.load_data(broken) and Rules.evaluate(loaded).is_empty() and not loaded.achievement_stats.complete_history,"Malformed optional metadata disables evidence without breaking run: "+key)
	var negative: Dictionary = run.save_data()
	negative.state.achievement_stats.counters.hints = -1
	_check(loaded.load_data(negative) and Rules.evaluate(loaded).is_empty(),"Negative counters cannot manufacture clean history")
	var fractional: Dictionary = run.save_data()
	fractional.state.achievement_stats.maxima.combo = 1.5
	_check(loaded.load_data(fractional) and Rules.evaluate(loaded).is_empty(),"Fractional counters discarded")
	var untracked = _game({"achievement_run_id":""})
	_fill(untracked)
	_check(not untracked.achievement_stats.earned.is_empty() and Rules.evaluate(untracked).is_empty(),"Default test/practice empty identity cannot publish any achievements")
	_check(not untracked.enable_achievement_tracking("bad id\n") and Rules.evaluate(untracked).is_empty(),"Invalid identity cannot enable delivery")
	var custom = Run.new()
	custom.new_run(987654321,{"achievement_run_id":"custom-seed-player-run"})
	var empty: int = _blank(custom)
	custom.place(empty,custom.solution[empty]%9+1)
	custom.hint(empty)
	var resumed = Run.new()
	_check(resumed.load_data(JSON.parse_string(JSON.stringify(custom.save_data()))),"Custom seed resumes after wrong answer and hint")
	_check(resumed.seed_value == 987654321 and resumed.achievement_stats.run_id == "custom-seed-player-run" and resumed.achievement_stats.counters.hints == 1 and resumed.achievement_stats.counters.wrong_answers == 1,"Custom seed, identity, wrong-answer and hint facts survive together")
	_fill(resumed)
	_check(_has(resumed,"FIRST_PLANT") and not _has(resumed,"NO_HINT_GRID"),"Custom seeds remain eligible while a pre-save hint remains disqualifying")
	var late = _game()
	_battle(late,50)
	var old_campaign: Dictionary = late.save_data()
	old_campaign.state.erase("achievement_stats")
	_check(resumed.load_data(old_campaign) and resumed.enable_achievement_tracking("legacy-final-round"),"Legacy final campaign round can resume tracking")
	_settle(resumed)
	_check(_has(resumed,"CAMPAIGN_CLEAR") and not _has(resumed,"CLEAN_CAMPAIGN"),"Observed legacy campaign finish earns completion but cannot prove clean whole-run history")

func _case(key: String, positive: bool, negative: bool, positive_evidence: String, negative_evidence: String) -> void:
	_check(positive,"Positive rule case: "+key)
	_check(not negative,"Negative rule case: "+key)
	rule_coverage["SD_"+key] = {"positive_passed":positive,"negative_passed":not negative,"positive_evidence":positive_evidence,"negative_evidence":negative_evidence}

func _rule_matrix() -> void:
	# Each catalog entry has a named positive and a specific near-miss/invalid
	# negative, rather than counting a fresh run as every negative case.
	var run = _game()
	run.hint(_blank(run))
	var negative: bool = _has(run,"FIRST_PLANT")
	_plant(run)
	_case("FIRST_PLANT",_has(run,"FIRST_PLANT"),negative,"Manual legal placement","Successful hint is not a manual placement")
	var hinted = _game()
	_fill(hinted,true)
	var solved = _game()
	_fill(solved)
	_case("FIRST_UNIT",_has(solved,"FIRST_UNIT"),_has(hinted,"FIRST_UNIT"),"Manual placement completes unit","All units completed with hints")
	run = _game()
	var cell: int = _plant(run)
	run.credits = 0
	run.upgrade_tower(cell)
	negative = _has(run,"FIRST_UPGRADE")
	run.credits = 100000
	run.upgrade_tower(cell)
	_case("FIRST_UPGRADE",_has(run,"FIRST_UPGRADE"),negative,"Paid tower upgrade","Insufficient-credit upgrade")
	run.equip_item(cell,-1)
	negative = _has(run,"FIRST_MODULE")
	run.equip_item(cell,run.items[0].id)
	_case("FIRST_MODULE",_has(run,"FIRST_MODULE"),negative,"Owned module equipped","Unavailable item ID")
	var chest: Dictionary = run._add_chest("common")
	run.open_chest(chest.id)
	negative = _has(run,"FIRST_CHEST")
	run.fragments = 100
	run.open_chest(chest.id)
	_case("FIRST_CHEST",_has(run,"FIRST_CHEST"),negative,"Paid atomic chest open","Insufficient fragments")
	run.items.append(Loot.make_item(run.rng,"common",1,999,"repair"))
	run.health -= 1.0
	run.use_item(999)
	negative = _has(run,"FIRST_BOOST")
	_battle(run)
	for item: Dictionary in run.items.duplicate():
		if str(item.kind) == "overclock": run.use_item(item.id)
	_case("FIRST_BOOST",_has(run,"FIRST_BOOST"),negative,"Overclock consumed in battle","Successful core repair")
	var lost = _game()
	_battle(lost)
	lost.phase = "lost"
	_settle(lost)
	_settle(run)
	_case("FIRST_CLEAR",_has(run,"FIRST_CLEAR"),_has(lost,"FIRST_CLEAR"),"Battle settled alive","Lost battle cannot settle as clear")
	var leaked = _game()
	_battle(leaked,5)
	leaked.spawned = leaked.spawn_total
	leaked.enemies.append(_enemy(leaked,"boss",true))
	leaked.update(0.05)
	var clean_boss = _game()
	_battle(clean_boss,5)
	_kill_boss(clean_boss)
	_settle(clean_boss)
	_case("FIRST_BOSS",_has(clean_boss,"FIRST_BOSS"),_has(leaked,"FIRST_BOSS"),"Boss killing damage","Boss leaks and wave clears")
	for milestone in [10,25]:
		var early = _game()
		_battle(early,milestone-1)
		_settle(early)
		var reached = _game()
		_battle(reached,milestone)
		_settle(reached)
		_case("ROUND_%d" % milestone,_has(reached,"ROUND_%d" % milestone),_has(early,"ROUND_%d" % milestone),"Clear exact campaign milestone","Clear immediately preceding round")
	var free = _game({"mode":"freeplay"})
	_battle(free)
	_settle(free)
	var campaign = _game()
	_battle(campaign,50)
	_settle(campaign)
	var locked = _game({"mode":"locked"})
	_battle(locked,50)
	_settle(locked)
	_case("CAMPAIGN_CLEAR",_has(campaign,"CAMPAIGN_CLEAR"),_has(free,"CAMPAIGN_CLEAR"),"Actual round50 campaign settlement","Free Play won state")
	_case("LOCKED_CLEAR",_has(locked,"LOCKED_CLEAR"),_has(campaign,"LOCKED_CLEAR"),"Locked In round50 settlement","Ordinary campaign round50 settlement")
	run = _game()
	cell = _plant(run)
	var number: int = run.towers[cell].number
	run.credits = 0
	run.upgrade_family(number)
	negative = _has(run,"FIRST_FAMILY")
	run.credits = 100000
	run.upgrade_family(number)
	_case("FIRST_FAMILY",_has(run,"FIRST_FAMILY"),negative,"Paid family upgrade","Insufficient-credit family upgrade")
	for i in range(2): run.upgrade_family(number)
	negative = _has(run,"FAMILY_FIVE")
	run.upgrade_family(number)
	_case("FAMILY_FIVE",_has(run,"FAMILY_FIVE"),negative,"Family level5","Family level4")
	negative = _has(run,"TOWER_FIVE")
	for i in range(4): run.upgrade_tower(cell)
	_case("TOWER_FIVE",_has(run,"TOWER_FIVE"),negative,"Individual tower level5","Family level5 with individual level1")
	for i in range(4):
		run.items.append(Loot.make_item(run.rng,"common",1,100+i,"rapid"))
		run.equip_item(cell,100+i)
	negative = _has(run,"FIVE_SOCKETS")
	run.items.append(Loot.make_item(run.rng,"common",1,105,"rapid"))
	run.equip_item(cell,105)
	_case("FIVE_SOCKETS",_has(run,"FIVE_SOCKETS"),negative,"Five occupied sockets","Four occupied sockets")
	var diverse = _game()
	var diverse_cell: int = _plant(diverse)
	for i in range(2):
		diverse.items.append(Loot.make_item(diverse.rng,"common",1,200+i,["frost","electric"][i]))
		diverse.equip_item(diverse_cell,200+i)
	_case("STACK_MODULES",_has(run,"STACK_MODULES"),_has(diverse,"STACK_MODULES"),"Two matching module kinds","Two different module kinds")
	diverse.items.append(Loot.make_item(diverse.rng,"common",1,203,"power"))
	diverse.equip_item(diverse_cell,203)
	_case("THREE_EFFECTS",_has(diverse,"THREE_EFFECTS"),_has(run,"THREE_EFFECTS"),"Three distinct module kinds","Five modules of a single kind")
	var lineup = _game()
	var missing = _game()
	var families: Array[int] = []
	for index in range(81):
		if lineup.board[index] == 0 and not families.has(lineup.solution[index]):
			lineup.place(index,lineup.solution[index])
			families.append(lineup.solution[index])
			lineup.set_target_priority(index,["first","strongest","nearest"][families.size()%3])
			if families.size() < 9:
				missing.place(index,missing.solution[index])
				missing.set_target_priority(index,["first","strongest"][families.size()%2])
	_battle(lineup)
	_settle(lineup)
	_battle(missing)
	# An illegal ninth tower also has the missing target priority. Both must be excluded.
	var missing_cell: int = _blank(missing)
	var illegal_number: int = families.back()
	while missing.solution[missing_cell] == illegal_number:
		missing_cell += 1
		while missing_cell < 81 and missing.board[missing_cell] != 0: missing_cell += 1
	missing.place(missing_cell,illegal_number)
	missing.set_target_priority(missing_cell,"nearest")
	_settle(missing)
	_case("TARGET_LINEUP",_has(lineup,"TARGET_LINEUP"),_has(missing,"TARGET_LINEUP"),"All three priorities on surviving legal towers","Missing priority exists only on illegal tower")
	_case("NINE_FAMILIES",_has(lineup,"NINE_FAMILIES"),_has(missing,"NINE_FAMILIES"),"Nine legal tower families","Ninth family exists only on illegal tower")
	var hard = _game({"puzzle_difficulty":"hard"})
	_fill(hard)
	_case("HARD_GRID",_has(hard,"HARD_GRID"),_has(solved,"HARD_GRID"),"Complete hard grid","Complete easy grid")
	_case("NO_HINT_GRID",_has(solved,"NO_HINT_GRID"),_has(hinted,"NO_HINT_GRID"),"Complete observed grid without hints","Complete grid using hints")
	var healed = _game()
	_battle(healed,5)
	_kill_boss(healed)
	healed.spawned = healed.spawn_total
	healed.enemies.append(_enemy(healed,"grunt",true))
	healed.update(0.05)
	_case("BOSS_WAVE_CLEAN",_has(clean_boss,"BOSS_WAVE_CLEAN"),_has(healed,"BOSS_WAVE_CLEAN"),"Boss killed with zero leaks","Boss killed but grunt leak is hidden by wave healing")
	var corrupted: Array = []
	for count in [2,3]:
		var corrupt = _game()
		_battle(corrupt)
		for i in range(count):
			var index: int = _blank(corrupt)
			var wrong: int = corrupt.solution[index]%9+1
			corrupt.inventory[wrong] = 1
			corrupt.place(index,wrong)
		_settle(corrupt)
		corrupted.append(corrupt)
	_case("CORRUPT_CLEAR",_has(corrupted[1],"CORRUPT_CLEAR"),_has(corrupted[0],"CORRUPT_CLEAR"),"Clear after three illegal placements","Clear after only two illegal placements")
	_battle(solved)
	_settle(solved)
	_case("UNFINISHED_CLEAR",_has(corrupted[1],"UNFINISHED_CLEAR"),_has(solved,"UNFINISHED_CLEAR"),"Grid incomplete after illegal cleanup","Grid fully solved at wave clear")
	var clean = _game()
	for i in range(50):
		_battle(clean)
		_settle(clean)
		if i < 49: clean.next_round()
	var unknown: Dictionary = clean.save_data()
	unknown.state.achievement_stats.complete_history = false
	unknown.state.achievement_stats.earned.erase("SD_CLEAN_CAMPAIGN")
	var legacy = Run.new()
	legacy.load_data(unknown)
	_case("CLEAN_CAMPAIGN",_has(clean,"CLEAN_CAMPAIGN"),_has(legacy,"CLEAN_CAMPAIGN"),"All50 observed rounds with zero illegal placements","Unknown whole-run history even when saved counters are zero")
	_check(rule_coverage.size() == 26,"Every catalog rule has explicit positive and negative evidence")
