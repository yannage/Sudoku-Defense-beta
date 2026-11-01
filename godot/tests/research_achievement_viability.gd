extends SceneTree

# Actual deterministic simulation, no synthetic kills, purchased resources,
# Steam calls, or real player profile. This is a narrow feasibility check, not
# proof of human fun or difficulty balance across all campaigns.
const Run = preload("res://scripts/run.gd")
const Rules = preload("res://scripts/achievement_rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var scenarios: Array[Dictionary] = []
	for seed_value in [875,1023,2046]:
		var baseline: Dictionary = _scenario(seed_value,false)
		var corruption: Dictionary = _scenario(seed_value,true)
		scenarios.append({"seed":seed_value,"round":1,"puzzle":"easy","combat":"easy","baseline":baseline,"three_illegal":corruption})
		if baseline.phase != "loot" or corruption.phase != "loot": failures.append("Scenario failed to clear: %d" % seed_value)
		if not corruption.controlled_chaos_earned or baseline.controlled_chaos_earned: failures.append("Wrong corruption achievement outcome: %d" % seed_value)
	var result: Dictionary = {"passed":failures.is_empty(),"scenarios":scenarios,"method":"Place all but three answers manually on Easy round1. No upgrades, bought gear, extra credits, hints or combat boosts. Compare leaving the three empty with planting three illegal reserve seeds. Run ordinary 0.05-second updates to completion.","caveat":"Early-round feasibility only; no claim of equal rewards, all-round balance, human fun, Deck performance or physical controller acceptance."}
	var file := FileAccess.open("user://achievement-viability.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	print(JSON.stringify(result))
	if failures.is_empty():
		print("ACHIEVEMENT_VIABILITY_PASS: 3 paired actual-combat scenarios; three illegal placements can clear without added resources")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _scenario(seed_value: int, corrupt: bool) -> Dictionary:
	var run = Run.new()
	run.new_run(seed_value,{"achievement_run_id":"isolated-viability-%d-%s" % [seed_value,str(corrupt)]})
	var empty: Array[int] = []
	for cell in range(81):
		if run.board[cell] == 0: empty.append(cell)
	for i in range(empty.size()-3): run.place(empty[i],run.solution[empty[i]])
	var legal_towers: int = run.towers.size()
	run.advance_phase()
	run.advance_phase()
	if corrupt:
		for i in range(empty.size()-3,empty.size()):
			var cell: int = empty[i]
			for number in range(1,10):
				if number != run.solution[cell] and run.inventory[number] > 0:
					run.place(cell,number)
					break
	var starting_credits: int = run.credits
	var iterations: int = 0
	while run.phase == "battle" and iterations < 12000:
		run.update(0.05)
		iterations += 1
	return {"phase":run.phase,"legal_towers":legal_towers,"illegal_placements":run.achievement_stats.counters.illegal_placements,"simulated_seconds":snappedf(run.battle_time,0.01),"kills":run.kills,"leaks":run.achievement_stats.counters.leaks,"health":run.health,"wave_credit_gain":run.credits-starting_credits,"fragments":run.fragments,"chests":run.chests.size(),"controlled_chaos_earned":Rules.evaluate(run).has("SD_CORRUPT_CLEAR")}
