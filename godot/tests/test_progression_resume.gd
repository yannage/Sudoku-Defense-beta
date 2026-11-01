extends SceneTree
## Actual gameplay before/after journal-backed restart, never injected awards.
const Bot = preload("res://tests/support/progression_bot.gd")
const Run = preload("res://scripts/run.gd")
const Save = preload("res://scripts/run_save.gd")
const Profile = preload("res://scripts/achievement_profile.gd")
const Rules = preload("res://scripts/achievement_rules.gd")
var checks := 0
var failures: Array[String] = []
var checkpoints: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func difference(a: Variant, b: Variant, path: String = "state") -> String:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return path + " dictionary size"
		for key: Variant in a:
			if not b.has(key): return path + "." + str(key) + " missing"
			var mismatch := difference(a[key],b[key],path+"."+str(key))
			if not mismatch.is_empty(): return mismatch
		return ""
	if a is Array and b is Array:
		if a.size() != b.size(): return path + " array size"
		for index in range(a.size()):
			var mismatch := difference(a[index],b[index],path+"["+str(index)+"]")
			if not mismatch.is_empty(): return mismatch
		return ""
	if (a is int or a is float) and (b is int or b is float):
		if a is int or b is int:
			return "" if float(a) == float(b) else path + ": " + str(a) + " vs " + str(b)
		return "" if absf(float(a)-float(b)) <= 0.0000001*maxf(1.0,maxf(absf(float(a)),absf(float(b)))) else path + ": " + str(a) + " vs " + str(b)
	return "" if a == b else path + ": " + str(a) + " vs " + str(b)

func same(control, resumed, label: String) -> void:
	var mismatch := difference(control.save_data(),resumed.save_data())
	check(mismatch.is_empty(),label+" matches uninterrupted state: "+mismatch)
	check(control.rng.state == resumed.rng.state,label+" keeps exact 64-bit RNG")
	check(Rules.evaluate(control) == Rules.evaluate(resumed),label+" keeps exact earned-key set")

func restart(bot, store, control, label: String) -> void:
	check(store.write_run(bot.run.save_data()),label+" writes through actual journal")
	var fresh_store := Save.new()
	fresh_store.file_path = store.file_path
	var saved: Dictionary = fresh_store.read_run()
	check(not saved.is_empty(),label+" fresh store reads committed run")
	if saved.is_empty(): return
	var new_run := Run.new()
	check(new_run.load_data(saved.data),label+" new run instance restores saved state")
	bot.run = new_run
	same(control,bot.run,label)
	checkpoints.append({"case":label,"round":bot.run.round_no,"phase":bot.run.phase,"rng_state":str(bot.run.rng.state),"waves":bot.run.achievement_stats.waves.size(),"earned":Rules.evaluate(bot.run)})

func campaign(seed_value: int, mode: String, puzzle: String, combat: String) -> Dictionary:
	var control := Bot.new()
	var resumed := Bot.new()
	var options := {"mode":mode,"puzzle_difficulty":puzzle,"combat_difficulty":combat,"achievement_run_id":"isolated-resume-%d-%s" % [seed_value,mode]}
	control.create(seed_value,options)
	resumed.create(seed_value,options)
	var store := Save.new()
	store.file_path = "user://resume-%d-%s.json" % [seed_value,mode]
	var rounds: Array[Dictionary] = []
	for number in range(1,control.run.max_rounds+1):
		var label := "%s/%d/%d" % [mode,seed_value,number]
		var selected: bool = number in [1,5,10,25,49,50]
		if selected: restart(resumed,store,control.run,label+" solve")
		control.prepare()
		resumed.prepare()
		same(control.run,resumed.run,label+" launched")
		if selected: restart(resumed,store,control.run,label+" launched")
		var ticks := 0
		var mid_restarted := false
		while control.run.phase == "battle" and ticks < 2400:
			control.run.update(0.1)
			resumed.run.update(0.1)
			ticks += 1
			check(control.run.phase == resumed.run.phase,label+" resumed phase tracks original at tick "+str(ticks))
			if selected and not mid_restarted and ticks == 23 and resumed.run.phase == "battle":
				restart(resumed,store,control.run,label+" mid-wave")
				mid_restarted = true
			control.run.drain_events()
			resumed.run.drain_events()
		check(control.run.phase in ["loot","won"],label+" settles through actual combat")
		check(not selected or mid_restarted,label+" reached an actual mid-wave restart")
		same(control.run,resumed.run,label+" settled")
		check(int(resumed.run.achievement_stats.counters.waves_cleared) == number,label+" settlement count is exactly once per wave")
		if selected: restart(resumed,store,control.run,label+" settled")
		var stable: Dictionary = resumed.run.save_data()
		for repeat in range(3):
			control.run.update(10.0)
			resumed.run.update(10.0)
		check(difference(stable,resumed.run.save_data()).is_empty(),label+" repeated post-restart updates cannot duplicate rewards")
		control.collect_loot()
		resumed.collect_loot()
		same(control.run,resumed.run,label+" chests")
		if selected: restart(resumed,store,control.run,label+" chests")
		rounds.append({"round":number,"phase":resumed.run.phase,"health":resumed.run.health,"credits":resumed.run.credits,"fragments":resumed.run.fragments,"kills":resumed.run.kills,"leaks":resumed.run.achievement_stats.counters.leaks,"rng_state":str(resumed.run.rng.state)})
		if number < control.run.max_rounds:
			control.next_round()
			resumed.next_round()
			same(control.run,resumed.run,label+" next board")
	check(resumed.run.phase == "won" and int(resumed.run.achievement_stats.counters.waves_cleared) == resumed.run.max_rounds,mode+" reaches intended terminal victory after restarts")
	check(control.failures.is_empty() and resumed.failures.is_empty(),mode+" helper action/economy invariants: "+str(control.failures)+str(resumed.failures))
	return {"seed":seed_value,"mode":mode,"puzzle":puzzle,"combat":combat,"rounds":rounds,"earned":Rules.evaluate(resumed.run),"helper_checks":control.checks+resumed.checks}

func partial_solve_and_prep() -> void:
	var control := Bot.new()
	var resumed := Bot.new()
	var options := {"mode":"freeplay","puzzle_difficulty":"hard","combat_difficulty":"medium","achievement_run_id":"partial-solve-resume"}
	control.create(9137,options)
	resumed.create(9137,options)
	var store := Save.new()
	store.file_path = "user://partial-solve.json"
	var planted := 0
	for cell in range(81):
		if control.run.board[cell] != 0: continue
		check(control.run.place(cell,control.run.solution[cell]).ok and resumed.run.place(cell,resumed.run.solution[cell]).ok,"Partial solve uses valid public placements")
		planted += 1
		if planted == 9: restart(resumed,store,control.run,"partial solve nine placements")
	check(control.run.advance_phase().ok and resumed.run.advance_phase().ok,"Both partially resumed solves reach prep")
	restart(resumed,store,control.run,"prep before gear")
	var target: int = control.run.towers.keys()[0]
	check(control.run.equip_item(target,control.run.items[0].id).ok and resumed.run.equip_item(target,resumed.run.items[0].id).ok,"Actual starter module equips after prep restart")
	restart(resumed,store,control.run,"prep after gear")
	check(control.run.advance_phase().ok and resumed.run.advance_phase().ok,"Resumed prep launches")
	control.fight()
	resumed.fight()
	same(control.run,resumed.run,"partial solve/prep final")
	check(control.failures.is_empty() and resumed.failures.is_empty(),"Partial solve/prep combat invariants")

func no_test_evidence_leak() -> void:
	var untracked := Bot.new()
	untracked.create(875,{"mode":"freeplay"})
	untracked.prepare()
	untracked.fight()
	untracked.collect_loot()
	check(untracked.run.achievement_stats.counters.waves_cleared == 1 and untracked.run.achievement_stats.counters.kills > 0,"Untracked practice-style run performed real combat")
	check(Rules.evaluate(untracked.run).is_empty(),"Empty-ID practice/test run exposes no eligible awards")
	var profile := Profile.new()
	var path := "user://normal-after-untracked.json"
	check(profile.configure(path,"","").ok,"Synthetic normal profile starts empty")
	check(profile.observe_run(untracked.run) and not FileAccess.file_exists(path),"Untracked completed run cannot create achievement progress")
	untracked.run.new_run(9137,{"achievement_run_id":"new-normal-run"})
	check(Rules.evaluate(untracked.run).is_empty() and untracked.run.achievement_stats.counters.waves_cleared == 0,"New tracked run inherits no prior test awards or counters")
	check(profile.observe_run(untracked.run) and not FileAccess.file_exists(path),"Empty normal start cannot import old test evidence")
	var cell: int = untracked.run.board.find(0)
	check(untracked.run.place(cell,untracked.run.solution[cell]).ok,"Normal synthetic run performs its own first placement")
	check(profile.observe_run(untracked.run) and profile.unlocked.keys() == ["SD_FIRST_PLANT"],"Only newly earned normal progress enters its isolated journal")

func _initialize() -> void:
	var cases: Array[Dictionary] = []
	partial_solve_and_prep()
	cases.append(campaign(4093,"campaign","medium","medium"))
	cases.append(campaign(9137,"locked","hard","hard"))
	cases.append(campaign(4093,"freeplay","medium","medium"))
	no_test_evidence_leak()
	var output := {"checks":checks,"failures":failures,"cases":cases,"checkpoints":checkpoints,"method":"Perfect-information public actions and real combat; resumed branch reloads actual journal snapshots into a fresh Run at selected solve/launch/mid-wave/settled/chest boundaries. No award flags or gameplay resources are injected.","limits":"Finite seed sample; simulation correctness only, not human balance/fun or physical devices."}
	var file := FileAccess.open("user://resume-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	for failure in failures: push_error(failure)
	print("PROGRESSION_RESUME_%s %d checks / %d failures; %d actual restart checkpoints" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size(),checkpoints.size()])
	quit(0 if failures.is_empty() else 1)
