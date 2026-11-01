extends RefCounted
## Perfect-information QA player. Mutates the game only through public actions.
const Run = preload("res://scripts/run.gd")
const Sudoku = preload("res://scripts/sudoku.gd")
const Rules = preload("res://scripts/achievement_rules.gd")
var run = Run.new()
var checks := 0
var failures: Array[String] = []
var purchases: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append("round %d: %s" % [run.round_no,message])

func create(seed_value: int, options: Dictionary) -> void:
	run.new_run(seed_value,options)
	check(run.round_no == 1 and run.phase == "solve", "New run begins at round one solve")
	check(run.max_rounds == (1 if run.mode == "freeplay" else 50), "Mode uses intended round count")
	var reference = Run.new()
	reference.new_run(seed_value,options)
	check(JSON.stringify(reference.save_data()) == JSON.stringify(run.save_data()), "Seed/options generate identical initial state and RNG")

func verify_puzzle() -> void:
	check(Sudoku.valid_puzzle({"board":run.board,"solution":run.solution,"givens":run.givens}), "Generated board/givens/solution are valid and uniquely solvable")
	var expected: Dictionary = Sudoku.make_puzzle(run.seed_value + run.round_no * 7919,run.puzzle_difficulty)
	check(run.board == expected.board and run.solution == expected.solution and run.givens == expected.givens, "Round puzzle is deterministic")
	check(run.board.filter(func(value: int) -> bool: return value > 0).size() == Sudoku.CLUE_COUNTS[run.puzzle_difficulty], "Generated clue density matches selected difficulty")

func inventory_ids() -> Array[int]:
	var result: Array[int] = []
	for item: Dictionary in run.items: result.append(int(item.id))
	for tower: Dictionary in run.towers.values():
		for item: Dictionary in tower.attachments: result.append(int(item.id))
	result.sort()
	return result

func verify_economy() -> void:
	check(run.credits >= 0 and run.fragments >= 0, "Currency stays nonnegative")
	var ids := inventory_ids()
	var unique: Dictionary = {}
	for id: int in ids: unique[id] = true
	check(unique.size() == ids.size(), "Items have exactly one bag/tower owner")
	var chest_ids: Dictionary = {}
	for chest: Dictionary in run.chests: chest_ids[int(chest.id)] = true
	check(chest_ids.size() == run.chests.size(), "Unopened chest identities are unique")
	for tower: Dictionary in run.towers.values():
		check(tower.attachments.size() <= 5, "Tower respects five sockets")

func prepare() -> void:
	check(run.phase == "solve", "Prepare starts in solve")
	verify_puzzle()
	var before_givens: Array = run.board.duplicate()
	for cell in range(81):
		if run.board[cell] == 0: check(run.place(cell,run.solution[cell]).ok, "Oracle legal placement succeeds")
	check(run.board == run.solution, "All answers were placed through gameplay")
	for cell in range(81):
		if run.givens[cell]: check(run.board[cell] == before_givens[cell], "Printed clue remains fixed")
	var credit_before: int = run.credits
	var upgrades_before: int = run.achievement_stats.counters.family_upgrades
	var spending := 0
	for purchase in range(100):
		var cheapest := 1
		for family in range(2,10):
			if run.family_upgrade_cost(family) < run.family_upgrade_cost(cheapest): cheapest = family
		var cost: int = run.family_upgrade_cost(cheapest)
		if run.credits < cost: break
		var before: int = run.credits
		var level: int = run.family_levels[cheapest]
		var response: Dictionary = run.upgrade_family(cheapest)
		check(response.ok and int(response.cost) == cost and run.credits == before-cost and run.family_levels[cheapest] == level+1, "Earned-credit family purchase charges once and applies once")
		spending += cost
		purchases.append({"round":run.round_no,"family":cheapest,"cost":cost,"new_level":run.family_levels[cheapest]})
	check(run.credits == credit_before-spending, "Family purchase ledger reconciles")
	check(run.achievement_stats.counters.family_upgrades-upgrades_before == purchases.filter(func(p: Dictionary) -> bool: return p.round == run.round_no).size(), "Successful purchases match durable counter")
	var ids := inventory_ids()
	var cells: Array = run.towers.keys()
	var equipped := true
	while equipped:
		equipped = false
		for cell: int in cells:
			if run.towers[cell].attachments.size() >= 5: continue
			for item: Dictionary in run.items:
				if item.type == "attachment":
					check(run.equip_item(cell,item.id).ok, "Earned module equips through action")
					equipped = true
					break
	check(inventory_ids() == ids, "Equipment transfers conserve every item")
	check(run.advance_phase().ok and run.phase == "prep", "Solve advances once to prep")
	check(run.advance_phase().ok and run.phase == "battle", "Prep launches once to battle")
	# The actual starter overclock is consumed once; no purchased resources.
	if run.round_no == 1:
		for item: Dictionary in run.items.duplicate():
			if item.kind == "overclock":
				var id: int = item.id
				check(run.use_item(id).ok, "Real starter boost activates")
				check(not run.use_item(id).ok, "Used boost cannot be consumed twice")
				break
	verify_economy()

func fight() -> Dictionary:
	check(run.phase == "battle", "Fight starts in battle")
	var before: Dictionary = run.achievement_stats.counters.duplicate()
	var expected_spawn: int = run.wave_forecast().count
	var credits_before: int = run.credits
	var fragments_before: int = run.fragments
	var start_msec: int = Time.get_ticks_msec()
	var ticks := 0
	while run.phase == "battle" and ticks < 2400:
		run.update(0.1)
		run.drain_events()
		ticks += 1
	check(run.phase in ["loot","won","lost"], "Actual combat settles before 240-second cap")
	var counters: Dictionary = run.achievement_stats.counters
	var kills: int = int(counters.kills)-int(before.kills)
	var leaks: int = int(counters.leaks)-int(before.leaks)
	var cleared: bool = run.phase in ["loot","won"]
	if cleared:
		check(run.spawned == expected_spawn and run.enemies.is_empty(), "Cleared wave spawned every forecast enemy and retained none")
		check(kills+leaks == expected_spawn, "Every cleared-wave enemy was killed or leaked exactly once")
		check(int(counters.waves_cleared)-int(before.waves_cleared) == 1, "Successful wave contributes one durable clear")
		check(run.achievement_stats.waves.size() == run.round_no, "Observed wave history has exactly one record per cleared round")
	else:
		check(int(counters.waves_cleared) == int(before.waves_cleared), "Lost wave awards no clear")
	var stable := JSON.stringify(run.save_data())
	for repeat in range(5): run.update(10.0)
	check(JSON.stringify(run.save_data()) == stable, "Repeated terminal updates grant no second reward or state progression")
	verify_economy()
	return {"round":run.round_no,"phase":run.phase,"puzzle":run.puzzle_difficulty,"combat":run.combat_difficulty,"spawned":run.spawned,"forecast":expected_spawn,"kills":kills,"leaks":leaks,"boss_kills":int(counters.boss_kills)-int(before.boss_kills),"boss_leaks":int(counters.boss_leaks)-int(before.boss_leaks),"health":run.health,"credits":run.credits,"credit_gain":run.credits-credits_before,"fragments":run.fragments,"fragment_gain":run.fragments-fragments_before,"wave_bonus":run.last_wave_bonus,"simulated_seconds":snappedf(run.battle_time,0.01),"wall_ms":Time.get_ticks_msec()-start_msec,"earned":Rules.evaluate(run),"family_levels":run.family_levels.slice(1),"items_total":inventory_ids().size(),"chests":run.chests.size()}

func collect_loot() -> void:
	check(run.phase in ["loot","won"], "Loot collection follows actual victory")
	for chest: Dictionary in run.chests.duplicate():
		if run.fragments < int(chest.cost): continue
		var before_ids := inventory_ids()
		var before_fragments: int = run.fragments
		var before_chests: int = run.chests.size()
		var before_count: int = run.achievement_stats.counters.chests_opened
		var response: Dictionary = run.open_chest(chest.id)
		check(response.ok and run.fragments == before_fragments-int(chest.cost) and run.chests.size() == before_chests-1, "Earned chest pays its displayed fragment cost once")
		check(inventory_ids().size() == before_ids.size()+response.rewards.size(), "Opened chest adds exactly its awarded items")
		check(run.achievement_stats.counters.chests_opened == before_count+1, "One opened chest increments its counter once")
		var snapshot := JSON.stringify(run.save_data())
		check(not run.open_chest(chest.id).ok and JSON.stringify(run.save_data()) == snapshot, "Repeated chest-open action cannot duplicate rewards")
	verify_economy()

func next_round(options: Dictionary = {}) -> bool:
	var ids := inventory_ids()
	var before_round: int = run.round_no
	var before_credits: int = run.credits
	var before_families: Array = run.family_levels.duplicate()
	var before_count: int = run.achievement_stats.counters.waves_cleared
	if run.mode == "locked":
		var saved := JSON.stringify(run.save_data())
		var wrong := "hard" if run.puzzle_difficulty != "hard" else "easy"
		check(not run.next_round({"puzzle_difficulty":wrong}).ok and JSON.stringify(run.save_data()) == saved, "Locked In rejects difficulty changes without modifying progress")
	var response: Dictionary = run.next_round(options)
	check(response.ok and run.round_no == before_round+1 and run.phase == "solve", "One continuation advances exactly one round")
	check(inventory_ids() == ids and run.towers.is_empty(), "All modules return to bag once between rounds")
	check(run.credits == before_credits and run.family_levels == before_families, "Credits and permanent family levels persist between boards")
	check(run.achievement_stats.counters.waves_cleared == before_count, "Next round cannot add a second settlement")
	return response.ok
