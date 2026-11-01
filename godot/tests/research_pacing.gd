extends "res://tests/test_campaign_balance.gd"

# Opt-in research only. Never imported by the game. All campaigns, exact
# pre-wave snapshots and counterfactuals live in memory; no player file I/O.
class BudgetRun:
	extends "res://scripts/run.gd"
	var budget: float = 8.0
	var starts_after: float = 60.0
	var used_push: Dictionary = {}
	func _fire(tower: Dictionary, target: Dictionary, stats: Dictionary) -> void:
		var positions: Dictionary = {}
		for enemy: Dictionary in enemies: positions[int(enemy.id)] = float(enemy.progress)
		super._fire(tower, target, stats)
		if battle_time < starts_after: return
		for enemy: Dictionary in enemies:
			var id: int = int(enemy.id)
			var before: float = float(positions.get(id, enemy.progress))
			var push: float = maxf(0.0, before - float(enemy.progress))
			var allowed: float = minf(push, maxf(0.0, budget - float(used_push.get(id, 0.0))))
			used_push[id] = float(used_push.get(id, 0.0)) + allowed
			enemy.progress = float(enemy.progress) + push - allowed
			enemy.pos = position_on_route(float(enemy.progress))

var probes: Array[Dictionary] = []
var probe_rounds: Array[int] = [1, 5, 10, 25, 33, 44, 45, 48, 50]

func _initialize() -> void:
	var cases: Array = [
		[2046, "easy", "tower_stack"],
		[1023, "hard", "tower_stack"],
		[4092, "medium", "tower_stack"],
		[4092, "hard", "tower_stack"],
		[1023, "easy", "family_spread"],
		[2046, "medium", "family_spread"],
		[4092, "hard", "family_spread"],
		[1023, "hard", "power_spread"],
		[2046, "easy", "power_spread"]
	]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--research-case="):
			var fields: PackedStringArray = arg.trim_prefix("--research-case=").split(",")
			cases = [[int(fields[0]), fields[1], fields[2]]]
	for spec: Array in cases: _research_campaign(int(spec[0]), str(spec[1]), str(spec[2]))
	print("RESEARCH_SUMMARY ", JSON.stringify({"comparisons": probes.size(), "checks": checks, "failures": failures}))
	if failures.is_empty():
		print("PASS: %d pacing research integrity checks" % checks)
		quit(0)
	else:
		for failure: String in failures: push_error(failure)
		quit(1)

func _research_campaign(seed_value: int, difficulty: String, policy: String) -> void:
	var run = Run.new()
	run.new_run(seed_value, {"mode":"locked", "puzzle_difficulty":"medium", "combat_difficulty":difficulty})
	var campaign_seconds: float = 0.0
	var campaign_leaks: int = 0
	var eligible_seconds: float = 0.0
	var eligible_waves: int = 0
	var longest: float = 0.0
	var longest_round: int = 0
	for stage in range(1, 51):
		_plant(run, 18)
		var cells: Array[int] = _rank_towers(run)
		_equip(run, cells, policy)
		_spend(run, cells, policy)
		_repair(run)
		_check(run.advance_phase().ok and run.advance_phase().ok, "Campaign transitions")
		var snapshot: Dictionary = run.save_data() if probe_rounds.has(stage) else {}
		var baseline: Dictionary = _battle(run, 1)
		campaign_seconds += float(baseline.seconds)
		campaign_leaks += int(baseline.leaks)
		eligible_seconds += float(baseline.fast_forward_seconds)
		if float(baseline.fast_forward_seconds) > 0.0: eligible_waves += 1
		if float(baseline.seconds) > longest:
			longest = float(baseline.seconds)
			longest_round = stage
		_check(run.phase != "battle", "Wave settled before 600s")
		_check_ownership(run)
		if not snapshot.is_empty(): _compare(snapshot, baseline, policy)
		if run.phase == "lost" or run.phase == "battle": break
		_open_earned_chests(run)
		if policy == "power_spread" and run.phase == "loot":
			for purchase in range(200):
				if run.credits < run.passive_cost("power"): break
				_check(run.buy_passive("power").ok, "Earned global upgrade")
		if stage < 50: _check(run.next_round().ok, "Earned next round")
	print("RESEARCH_CAMPAIGN ", JSON.stringify({"seed":seed_value,"combat":difficulty,"policy":policy,"phase":run.phase,"round":run.round_no,"core":run.health,"leaks":campaign_leaks,"seconds":snappedf(campaign_seconds,0.1),"longest_seconds":longest,"longest_round":longest_round,"eligible_waves":eligible_waves,"eligible_seconds":snappedf(eligible_seconds,0.1),"estimated_wall_4x":snappedf(campaign_seconds/4.0,0.1),"estimated_wall_after45_8x":snappedf(campaign_seconds/4.0-eligible_seconds/8.0,0.1)}))

func _battle(run: RefCounted, batch: int) -> Dictionary:
	var used: Array[String] = []
	var leaks: int = 0
	var sim_steps: int = 0
	var before_credits: int = run.credits
	var before_fragments: int = run.fragments
	var before_kills: int = run.kills
	var before_chests: int = run.chests.size()
	var before_damage: float = run.combat_report.core_damage
	var tail_start: float = -1.0
	var tail_count: int = 0
	var cleanup_start: float = -1.0
	var eligible_start: float = -1.0
	var enemies_at45: int = -1
	var enemies_at60: int = -1
	while run.phase == "battle" and sim_steps < 6000:
		for step in range(batch):
			if run.phase != "battle": break
			if run.battle_time >= 5.0: _use_boosts(run, used)
			run.update(0.1)
			sim_steps += 1
			if run.spawned == run.spawn_total and tail_start < 0.0:
				tail_start = run.battle_time
				tail_count = run.enemies.size()
			if cleanup_start < 0.0 and run.spawned == run.spawn_total and run.battle_time >= 45.0 and run.enemies.size() >= 1 and run.enemies.size() <= 3:
				cleanup_start = run.battle_time
			if run.phase == "battle" and enemies_at45 < 0 and run.battle_time >= 45.0: enemies_at45 = run.enemies.size()
			if run.phase == "battle" and enemies_at60 < 0 and run.battle_time >= 60.0: enemies_at60 = run.enemies.size()
			if eligible_start < 0.0 and run.phase == "battle" and run.spawned == run.spawn_total and run.battle_time >= 45.0:
				eligible_start = run.battle_time
			for event: Dictionary in run.drain_events():
				if str(event.type) == "leak": leaks += 1
	return {
		"phase":run.phase,"seconds":snappedf(run.battle_time,0.1),"core":run.health,"leaks":leaks,
		"core_damage":run.combat_report.core_damage-before_damage,"kills":run.kills-before_kills,
		"credits_earned":run.credits-before_credits,"fragments_earned":run.fragments-before_fragments,
		"chests_earned":run.chests.size()-before_chests,"tail_start":snappedf(tail_start,0.1),
		"tail_enemies":tail_count,"tail_seconds":snappedf(run.battle_time-tail_start,0.1),
		"cleanup_start":snappedf(cleanup_start,0.1),"cleanup_seconds":snappedf(run.battle_time-cleanup_start,0.1) if cleanup_start >= 0.0 else 0.0,
		"fast_forward_start":snappedf(eligible_start,0.1),"fast_forward_seconds":snappedf(run.battle_time-eligible_start,0.1) if eligible_start >= 0.0 else 0.0,
		"enemies_at45":enemies_at45,"enemies_at60":enemies_at60,
		"state_hash":JSON.stringify(run.save_data()).sha256_text()
	}

func _compare(snapshot: Dictionary, baseline: Dictionary, policy: String) -> void:
	var row: Dictionary = {"seed":int(snapshot.state.seed_value),"round":snapshot.state.round_no,"combat":snapshot.state.combat_difficulty,"policy":policy,"baseline":baseline}
	var fast = Run.new()
	_check(fast.load_data(snapshot), "Exact snapshot restores for grouped fast-forward")
	var fast_result: Dictionary = _battle(fast, 2)
	_check(baseline == fast_result, "Grouped identical update stream preserves full final state and reward accounting")
	row.grouped_fast_forward_exact = baseline == fast_result
	row.estimated_wall_4x = snappedf(float(baseline.seconds) / 4.0, 0.01)
	row.estimated_wall_tail8x = snappedf((float(baseline.seconds) - float(baseline.cleanup_seconds)) / 4.0 + float(baseline.cleanup_seconds) / 8.0, 0.01)
	row.estimated_wall_after45_8x = snappedf((float(baseline.seconds) - float(baseline.fast_forward_seconds)) / 4.0 + float(baseline.fast_forward_seconds) / 8.0, 0.01)
	for budget_value: float in [8.0, 24.0]:
		var limited = BudgetRun.new()
		limited.budget = budget_value
		_check(limited.load_data(snapshot), "Exact snapshot restores for budget counterfactual")
		row["push_budget_%d_after60" % int(budget_value)] = _battle(limited, 1)
	probes.append(row)
	print("PACING_PROBE ", JSON.stringify(row))
