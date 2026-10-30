extends SceneTree

# Explicit research harness, not a claim that a policy models a human player.
# Uses only in-memory runs and public gameplay actions. No files or user saves.
const Run = preload("res://scripts/run.gd")
const SEEDS: Array[int] = [1023, 2046, 4092]
const POLICIES: Array[String] = ["family_spread", "tower_stack", "power_spread"]
var checks: int = 0
var failures: Array[String] = []
var battle_limit: int = 180
var observations: Array[Dictionary] = []

func _initialize() -> void:
	var requested_case: String = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): requested_case = argument.trim_prefix("--case=")
		if argument.begins_with("--battle-limit="): battle_limit = clampi(int(argument.trim_prefix("--battle-limit=")), 30, 600)
	if not requested_case.is_empty():
		var fields: PackedStringArray = requested_case.split(",")
		if fields.size() != 5:
			push_error("Use --case=seed,combat,policy,placements,puzzle (policy: family_spread/tower_stack/power_spread/starter)")
			quit(2)
			return
		if not fields[0].is_valid_int() or not fields[3].is_valid_int() or int(fields[3]) < 1 or int(fields[3]) > 81 or not ["easy", "medium", "hard"].has(fields[1]) or not ["easy", "medium", "hard"].has(fields[4]) or not (POLICIES.has(fields[2]) or fields[2] == "starter"):
			push_error("Invalid case: use an integer seed, easy/medium/hard difficulties, a known policy and 1–81 placements")
			quit(2)
			return
		_record("CASE", _campaign(int(fields[0]), fields[1], fields[2], int(fields[3]), 1 if fields[2] == "starter" else 50, fields[4]))
		_finish()
		return
	var seeds: Array[int] = []
	seeds.assign([1023] if OS.get_cmdline_user_args().has("--quick") else SEEDS)
	_check_wave_curve()
	for seed_value in seeds:
		for difficulty in ["easy", "medium", "hard"]:
			for policy in POLICIES:
				_record("BALANCE", _campaign(seed_value, difficulty, policy, 18, 50))
			# Eight-tower combat probes keep medium Sudoku fixed like the campaign
			# comparisons. Use a targeted easy-puzzle case for onboarding evidence.
			_record("STARTER", _campaign(seed_value, difficulty, "starter", 8, 1))
		_record("REFERENCE", _campaign(seed_value, "medium", "family_spread", 81, 50))
	var replay_a: Dictionary = _campaign(1023, "easy", "starter", 8, 1)
	var replay_b: Dictionary = _campaign(1023, "easy", "starter", 8, 1)
	_check(JSON.stringify(replay_a) == JSON.stringify(replay_b), "Seeded starter probe repeats exactly")
	_finish()

func _finish() -> void:
	var counts: Dictionary = {"samples": observations.size(), "full_campaign_clears": 0, "starter_clears": 0, "lost": 0, "censored_at_guard": 0, "battle_limit_seconds": battle_limit}
	for result in observations:
		if result.final_phase == "won": counts.full_campaign_clears += 1
		elif result.final_phase == "lost": counts.lost += 1
		elif result.final_phase == "battle": counts.censored_at_guard += 1
		elif result.policy == "starter" and int(result.cleared) == 1: counts.starter_clears += 1
	print("SUMMARY ", JSON.stringify(counts))
	if failures.is_empty():
		print("PASS: %d balance harness integrity checks; outcomes are observations, not human balance certification" % checks)
		quit(0)
	else:
		print("FAIL: %d / %d balance harness checks; inspect pacing guard failures separately from engine errors" % [failures.size(), checks])
		for failure in failures: push_error(failure)
		quit(1)

func _record(label: String, result: Dictionary) -> void:
	observations.append(result)
	print(label, " ", JSON.stringify(result))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _check_wave_curve() -> void:
	for difficulty in ["easy", "medium", "hard"]:
		var run = Run.new()
		run.new_run(1, {"combat_difficulty": difficulty})
		var previous_health: float = 0.0
		var previous_count: int = 0
		for stage in range(1, 51):
			run.round_no = stage
			var stats: Dictionary = run.wave_stats()
			_check(float(stats.health) > previous_health, "Enemy health grows at %s round %d" % [difficulty, stage])
			_check(int(stats.count) >= previous_count, "Enemy count never declines at %s round %d" % [difficulty, stage])
			_check(bool(stats.boss) == (stage % 5 == 0), "Boss cadence at round %d" % stage)
			previous_health = float(stats.health)
			previous_count = int(stats.count)
			if [1, 5, 10, 25, 50].has(stage):
				print("CURVE ", JSON.stringify({"combat": difficulty, "round": stage, "stats": stats}))

func _campaign(seed_value: int, difficulty: String, policy: String, placements: int, rounds: int, puzzle: String = "medium") -> Dictionary:
	var run = Run.new()
	# Fix puzzle difficulty to isolate combat difficulty and allocation policy.
	# The bot knows the answers and places instantly; this deliberately omits
	# human solve time, mistakes, fatigue, and management overhead.
	run.new_run(seed_value, {"mode": "locked", "puzzle_difficulty": puzzle, "combat_difficulty": difficulty})
	var cleared: int = 0
	var first_leak: int = 0
	var leaks: int = 0
	var battles: Array[float] = []
	var snapshots: Array[Dictionary] = []
	for stage in range(1, rounds + 1):
		_plant(run, placements)
		var cells: Array[int] = _rank_towers(run)
		_equip(run, cells, policy)
		_spend(run, cells, policy)
		_repair(run)
		_check(run.advance_phase().ok and run.advance_phase().ok, "Solve/prep transitions for %s round %d" % [policy, stage])
		if stage == 44 and OS.get_cmdline_user_args().has("--control-probe"):
			_control_probe(run)
		run.drain_events()
		var wave_leaks: int = 0
		var used: Array[String] = []
		for tick in range(battle_limit * 10):
			if run.phase != "battle": break
			if float(run.battle_time) >= 5.0 and policy != "starter": _use_boosts(run, used)
			run.update(0.1)
			for event: Dictionary in run.drain_events():
				if str(event.type) == "leak": wave_leaks += 1
		_check(run.phase != "battle", "Wave settles within %d simulated seconds: %s/%s/%d/%d" % [battle_limit, policy, difficulty, seed_value, stage])
		_check(run.credits >= 0 and run.fragments >= 0, "No overspending")
		_check_ownership(run)
		leaks += wave_leaks
		if wave_leaks > 0 and first_leak == 0: first_leak = stage
		battles.append(float(run.battle_time))
		if [1, 5, 10, 25, 50].has(stage) or run.phase == "lost":
			snapshots.append({"round": stage, "health": run.health, "leaks": wave_leaks, "seconds": snappedf(run.battle_time, 0.1), "credits": run.credits, "families": run.family_levels.slice(1), "power": run.passives.power})
		if run.phase == "lost" or run.phase == "battle": break
		cleared += 1
		_open_earned_chests(run)
		if policy == "power_spread" and run.phase == "loot":
			for purchase in range(200):
				if run.credits < run.passive_cost("power"): break
				var result: Dictionary = run.buy_passive("power")
				_check(result.ok, "Earned credits buy global power")
				if not result.ok: break
		if stage < rounds:
			_check(run.next_round().ok, "Campaign advances without resetting progress")
	var total_time: float = 0.0
	var peak_time: float = 0.0
	for seconds in battles:
		total_time += seconds
		peak_time = maxf(peak_time, seconds)
	var remaining: Array[Dictionary] = []
	if run.phase == "battle":
		for enemy: Dictionary in run.enemies:
			remaining.append({"kind": enemy.kind, "hp": enemy.hp, "max_hp": enemy.max_hp, "progress": enemy.progress, "route_length": run.route_length, "speed": enemy.speed})
	return {"seed": seed_value, "puzzle": puzzle, "combat": difficulty, "policy": policy, "placement_budget": placements, "cleared": cleared, "attempted": battles.size(), "final_phase": run.phase, "core": run.health, "first_leak": first_leak, "leaks": leaks, "battle_minutes": snappedf(total_time / 60.0, 0.01), "longest_battle_seconds": snappedf(peak_time, 0.1), "snapshots": snapshots, "remaining_enemies": remaining}

func _plant(run: RefCounted, count: int) -> void:
	# A fixed coprime traversal distributes answers over rows and bands without
	# choosing a different board or secretly optimizing the route per policy.
	for offset in range(81):
		if count <= 0: break
		var cell: int = (offset * 37) % 81
		if int(run.board[cell]) == 0:
			_check(run.place(cell, run.solution[cell]).ok, "Bot uses legal Sudoku answer")
			count -= 1

func _rank_towers(run: RefCounted) -> Array[int]:
	var cells: Array[int] = []
	var coverage: Dictionary = {}
	for cell: int in run.towers:
		cells.append(cell)
		coverage[cell] = 0
		# All policies use the visible route and base range; no enemy foresight.
		for sample in range(101):
			if run.cell_position(cell).distance_to(run.position_on_route(run.route_length * sample / 100.0)) <= 2.4:
				coverage[cell] += 1
	cells.sort_custom(func(a: int, b: int) -> bool: return int(coverage[a]) > int(coverage[b]) if coverage[a] != coverage[b] else a < b)
	return cells

func _equip(run: RefCounted, cells: Array[int], policy: String) -> void:
	if policy == "starter": return
	for item: Dictionary in run.items.duplicate():
		if str(item.type) != "attachment": continue
		var selected: int = -1
		var minimum: int = 6
		for cell in cells:
			var slots: int = run.towers[cell].attachments.size()
			if slots >= 5: continue
			if policy == "tower_stack":
				selected = cell
				break
			if slots < minimum:
				minimum = slots
				selected = cell
		if selected >= 0: _check(run.equip_item(selected, item.id).ok, "Earned module equips once")

func _spend(run: RefCounted, cells: Array[int], policy: String) -> void:
	if policy == "starter" or policy == "power_spread": return
	for purchase in range(200):
		if policy == "family_spread":
			var family: int = 1
			for candidate in range(2, 10):
				if run.family_upgrade_cost(candidate) < run.family_upgrade_cost(family): family = candidate
			if run.credits < run.family_upgrade_cost(family): break
			_check(run.upgrade_family(family).ok, "Earned credits upgrade family")
		else:
			var selected: int = cells[0]
			for candidate in cells.slice(0, mini(3, cells.size())):
				if run.upgrade_cost(candidate) < run.upgrade_cost(selected): selected = candidate
			if run.credits < run.upgrade_cost(selected): break
			_check(run.upgrade_tower(selected).ok, "Earned credits upgrade concentrated towers")

func _repair(run: RefCounted) -> void:
	for item: Dictionary in run.items.duplicate():
		if str(item.kind) == "repair" and run.max_health - run.health >= 10.0:
			_check(run.use_item(item.id).ok, "Repair item uses earned inventory")

func _use_boosts(run: RefCounted, used: Array[String]) -> void:
	_repair(run)
	for item: Dictionary in run.items.duplicate():
		var kind: String = str(item.kind)
		if ["overclock", "overcharge", "freeze"].has(kind) and not used.has(kind):
			_check(run.use_item(item.id).ok, "One available boost of each kind per wave")
			used.append(kind)

func _open_earned_chests(run: RefCounted) -> void:
	for chest: Dictionary in run.chests.duplicate():
		if run.fragments >= int(chest.cost): _check(run.open_chest(chest.id).ok, "Earned fragments open earned chest")

func _check_ownership(run: RefCounted) -> void:
	var ids: Dictionary = {}
	for item: Dictionary in run.items:
		_check(not ids.has(item.id), "No duplicated bag item")
		ids[item.id] = true
	for tower: Dictionary in run.towers.values():
		_check(tower.attachments.size() <= 5, "Five-slot equipment limit")
		for item: Dictionary in tower.attachments:
			_check(not ids.has(item.id), "Equipped item has one owner")
			ids[item.id] = true

func _control_probe(source: RefCounted) -> void:
	# Replay the exact pre-wave snapshot so board, route, money, loot, RNG and
	# enemy composition remain identical. Only the named control modules leave
	# the towers; they return to the bag through the real equipment action.
	var snapshot: Dictionary = source.save_data()
	for treatment in ["unchanged", "no_gravity", "no_gravity_or_frost", "strongest_after_60s"]:
		var run = Run.new()
		_check(run.load_data(snapshot), "Control probe restores exact round snapshot")
		if ["no_gravity", "no_gravity_or_frost"].has(treatment):
			for cell: int in run.towers:
				for slot in range(run.towers[cell].attachments.size() - 1, -1, -1):
					var kind: String = str(run.towers[cell].attachments[slot].kind)
					if kind == "gravity" or (treatment == "no_gravity_or_frost" and kind == "frost"):
						_check(run.unequip_item(cell, slot).ok, "Counterfactual returns control module to bag")
		var leaks: int = 0
		var used: Array[String] = []
		var retargeted: bool = false
		for tick in range(6000):
			if run.phase != "battle": break
			if treatment == "strongest_after_60s" and run.battle_time >= 60.0 and not retargeted:
				for cell: int in run.towers: _check(run.set_target_priority(cell, "strongest").ok, "Use existing strongest targeting after a long wave")
				retargeted = true
			if run.battle_time >= 5.0: _use_boosts(run, used)
			run.update(0.1)
			for event: Dictionary in run.drain_events():
				if str(event.type) == "leak": leaks += 1
		print("CONTROL_PROBE ", JSON.stringify({"seed": run.seed_value, "round": run.round_no, "treatment": treatment, "phase": run.phase, "seconds": snappedf(run.battle_time, 0.1), "leaks": leaks, "core": run.health}))
